package com.orsofey.orsofey_downloader

import android.app.DownloadManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_common.utils.ZipUtils
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.net.URLConnection
import java.util.Collections
import java.util.UUID

class DownloaderBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val engineChannel = MethodChannel(messenger, ENGINE_CHANNEL)
    private val actionsChannel = MethodChannel(messenger, ACTIONS_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENTS_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val initMutex = Mutex()
    private val activeJobs = Collections.synchronizedSet(mutableSetOf<String>())
    private val secureCookies = SecureCookieStore(context)
    private var eventSink: EventChannel.EventSink? = null

    @Volatile
    private var initialized = false

    fun attach() {
        engineChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> launchResult(result) {
                    ensureInitialized()
                    mapOf(
                        "available" to true,
                        "version" to (YoutubeDL.versionName(context)
                            ?: YoutubeDL.version(context)
                            ?: "bundled"),
                        "description" to "yt-dlp · FFmpeg · QuickJS",
                    )
                }
                "getDownloadDirectory" -> launchResult(result) {
                    defaultDownloadDirectory().absolutePath
                }
                "inspect" -> launchResult(result) {
                    ensureInitialized()
                    inspect(call)
                }
                "download" -> download(call, result)
                "stop" -> {
                    val taskId = call.argument<String>("taskId").orEmpty()
                    val stopped = YoutubeDL.getInstance().destroyProcessById(taskId)
                    result.success(stopped)
                }
                "updateEngine" -> launchResult(result) {
                    ensureInitialized()
                    YoutubeDL.getInstance().updateYoutubeDL(
                        context,
                        YoutubeDL.UpdateChannel.STABLE,
                    )
                    null
                }
                else -> result.notImplemented()
            }
        }

        actionsChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "saveCookies" -> {
                        secureCookies.save(call.argument<String>("content").orEmpty())
                        result.success(null)
                    }
                    "readCookies" -> result.success(secureCookies.read())
                    "clearCookies" -> {
                        secureCookies.clear()
                        result.success(null)
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path").orEmpty()
                        openFile(path)
                        result.success(null)
                    }
                    "openFolder" -> {
                        openDownloads(call.argument<String>("path").orEmpty())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("OPEN_ERROR", error.message, null)
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    fun dispose() {
        engineChannel.setMethodCallHandler(null)
        actionsChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        scope.cancel()
        activeJobs.forEach { YoutubeDL.getInstance().destroyProcessById(it) }
        activeJobs.clear()
    }

    private suspend fun ensureInitialized() {
        if (initialized) return
        initMutex.withLock {
            if (initialized) return
            withContext(Dispatchers.IO) {
                initializeFfmpegPackage()
                YoutubeDL.getInstance().init(context)
            }
            initialized = true
        }
    }

    private fun initializeFfmpegPackage() {
        val zip = File(context.applicationInfo.nativeLibraryDir, "libffmpeg.zip.so")
        val baseDir = File(context.noBackupFilesDir, YoutubeDL.baseName)
        val ffmpegDir = File(File(baseDir, "packages"), "ffmpeg")
        val version = zip.length().toString()
        val preferences = context.getSharedPreferences("orsofey_engine", Context.MODE_PRIVATE)
        if (!ffmpegDir.exists() || preferences.getString("ffmpegLibVersion", null) != version) {
            ffmpegDir.deleteRecursively()
            ffmpegDir.mkdirs()
            ZipUtils.unzip(zip, ffmpegDir)
            preferences.edit().putString("ffmpegLibVersion", version).apply()
        }
    }

    private fun inspect(call: MethodCall): String {
        val url = call.argument<String>("url").orEmpty()
        val request = baseRequest(url)
            .addOption("--dump-single-json")
            .addOption("--flat-playlist")
            .addOption("--skip-download")
        addCookies(request, call.argument<String>("cookiesFile"))
        val response = YoutubeDL.getInstance().execute(
            request = request,
            processId = "inspect_${UUID.randomUUID()}",
            redirectErrorStream = false,
            callback = null,
        )
        return response.out.trim()
    }

    private fun download(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId").orEmpty()
        if (taskId.isEmpty()) {
            result.error("ERROR", "Не указан идентификатор загрузки", null)
            return
        }
        activeJobs.add(taskId)
        startForegroundService()
        scope.launch {
            try {
                ensureInitialized()
                val output = withContext(Dispatchers.IO) { executeDownload(call, taskId) }
                result.success(output)
            } catch (_: YoutubeDL.CanceledException) {
                result.error("STOPPED", "Загрузка остановлена", null)
            } catch (error: Exception) {
                result.error("ERROR", error.message ?: "Ошибка загрузки", null)
            } finally {
                activeJobs.remove(taskId)
                if (activeJobs.isEmpty()) stopForegroundService()
            }
        }
    }

    private fun executeDownload(call: MethodCall, taskId: String): String {
        val url = call.argument<String>("url").orEmpty()
        val directoryPath = call.argument<String>("directory").orEmpty()
        val useSaf = directoryPath.startsWith("content://")
        val directory = if (useSaf) {
            File(context.cacheDir, "orsofey_downloads/$taskId").apply { mkdirs() }
        } else {
            resolveDownloadDirectory(directoryPath)
        }
        val kind = call.argument<String>("kind") ?: "video"
        val quality = call.argument<Int>("quality") ?: 1080
        val container = call.argument<String>("container") ?: "mp4"
        val audioBitrate = call.argument<Int>("audioBitrate") ?: 192
        val thumbnailMode = call.argument<String>("thumbnailMode") ?: "separate"
        val writeSubtitles = call.argument<Boolean>("writeSubtitles") == true
        val autoSubtitles = call.argument<Boolean>("autoSubtitles") == true
        val embedSubtitles = call.argument<Boolean>("embedSubtitles") == true
        val subtitleLanguages = call.argument<String>("subtitleLanguages").orEmpty()
        val playlistItems = call.argument<String>("playlistItems").orEmpty()

        val request = baseRequest(url)
            .addOption("--newline")
            .addOption("--progress")
            .addOption("--continue")
            .addOption("--trim-filenames", 220)
            .addOption(
                "--output",
                File(directory, "%(title).160B [%(id)s].%(ext)s").absolutePath,
            )
            .addOption(
                "--progress-template",
                "download:ORSOFEY|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s",
            )
            .addOption("--print", "after_move:ORSOFEY_FILE|%(filepath)s")

        if (playlistItems.isNotBlank()) {
            request.addOption("--playlist-items", playlistItems)
        }

        if (kind == "audio") {
            request
                .addOption("--extract-audio")
                .addOption("--audio-format", "mp3")
                .addOption("--audio-quality", "${audioBitrate}K")
        } else {
            request
                .addOption("--format", formatSelector(quality, container))
                .addOption("--merge-output-format", container)
        }

        if (writeSubtitles || embedSubtitles) request.addOption("--write-subs")
        if (autoSubtitles) request.addOption("--write-auto-subs")
        if ((writeSubtitles || embedSubtitles) && subtitleLanguages.isNotBlank()) {
            request
                .addOption("--sub-langs", subtitleLanguages)
                .addOption("--sub-format", "best/srt/vtt")
        }
        if (embedSubtitles) request.addOption("--embed-subs")
        when (thumbnailMode) {
            "separate" -> request.addOption("--write-thumbnail")
            "embed" -> request.addOption("--embed-thumbnail")
        }
        addCookies(request, call.argument<String>("cookiesFile"))

        val response = YoutubeDL.getInstance().execute(
            request = request,
            processId = taskId,
            redirectErrorStream = false,
            callback = { progress, eta, line ->
                emitProgress(taskId, progress, eta, line)
            },
        )
        val output = response.out.lineSequence()
            .lastOrNull { it.startsWith("ORSOFEY_FILE|") }
            ?.substringAfter("ORSOFEY_FILE|")
            ?.trim()
            .orEmpty()
        if (output.isBlank()) {
            throw IllegalStateException("Не удалось определить итоговый файл после загрузки")
        }
        mainHandler.post {
            eventSink?.success(mapOf("taskId" to taskId, "stage" to "processing"))
        }
        val finalOutput = ensureMergedOutput(output, directory)
        if (!useSaf && !File(finalOutput).exists()) {
            throw IllegalStateException("Итоговый файл не найден: $finalOutput")
        }
        return if (useSaf) {
            exportToSaf(directoryPath, directory, finalOutput)
        } else {
            finalOutput
        }
    }

    private fun baseRequest(url: String): YoutubeDLRequest {
        return YoutubeDLRequest(url)
            .addOption("--ignore-config")
            .addOption("--no-config-locations")
            .addOption("--no-update")
            .addOption("--no-warnings")
            .addOption("--socket-timeout", 30)
            .addOption("--retries", 3)
            .addOption("--extractor-retries", 3)
    }

    private fun addCookies(request: YoutubeDLRequest, path: String?) {
        if (!path.isNullOrBlank()) request.addOption("--cookies", path)
    }

    private fun formatSelector(quality: Int, container: String): String {
        val extension = if (container == "webm") "webm" else "mp4"
        val height = if (quality > 0) "[height<=$quality]" else ""
        return "bestvideo$height[ext=$extension]+bestaudio[ext=webm]/bestaudio/" +
            "best$height[ext=$extension]/" +
            "bestvideo$height+bestaudio/best$height"
    }

    private fun emitProgress(taskId: String, percent: Float, eta: Long, line: String) {
        val event = mutableMapOf<String, Any>("taskId" to taskId)
        if (line.startsWith("ORSOFEY|")) {
            val values = line.removePrefix("ORSOFEY|").split("|")
            if (values.size >= 5) {
                val downloaded = values[0].toDoubleOrNull()
                val total = values[1].toDoubleOrNull() ?: values[2].toDoubleOrNull()
                val speed = values[3].toDoubleOrNull()
                val etaSeconds = values[4].toDoubleOrNull()?.toInt()
                if (downloaded != null) event["downloadedBytes"] = downloaded.toLong()
                if (total != null && total > 0) {
                    event["totalBytes"] = total.toLong()
                    if (downloaded != null) event["fraction"] = (downloaded / total).coerceIn(0.0, 1.0)
                }
                if (speed != null) event["speed"] = speed
                if (etaSeconds != null) event["etaSeconds"] = etaSeconds
            }
        } else if (percent >= 0) {
            event["fraction"] = (percent / 100.0).coerceIn(0.0, 1.0)
            if (eta >= 0) event["etaSeconds"] = eta.toInt()
        }
        event["stage"] = if (isPostProcessing(line)) "processing" else "downloading"
        mainHandler.post { eventSink?.success(event) }
    }

    private fun isPostProcessing(line: String): Boolean {
        return listOf(
            "[Merger]",
            "[ExtractAudio]",
            "[VideoConvertor]",
            "[VideoRemuxer]",
            "[FFmpegMetadata]",
            "[EmbedSubtitle]",
            "[ThumbnailsConvertor]",
        ).any(line::contains)
    }

    private fun defaultDownloadDirectory(): File {
        val publicDownloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        val preferred = File(publicDownloads, "Orsofey Downloader")
        if (preferred.exists() || preferred.mkdirs()) return preferred
        val fallback = File(
            context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                ?: context.filesDir,
            "Orsofey Downloader",
        )
        fallback.mkdirs()
        return fallback
    }

    private fun resolveDownloadDirectory(path: String): File {
        if (path.isBlank() || path.startsWith("content://")) {
            return defaultDownloadDirectory()
        }
        val directory = File(path)
        if (!directory.exists()) directory.mkdirs()
        return directory
    }

    private fun ensureMergedOutput(output: String, directory: File): String {
        if (output.isBlank()) return output
        val outputFile = File(output)
        val baseName = outputFile.nameWithoutExtension.substringBefore(".fdash_sep-")
        val video = if (output.contains(".fdash_sep-")) {
            outputFile
        } else {
            directory.listFiles()?.firstOrNull { candidate ->
                candidate.isFile &&
                    candidate.nameWithoutExtension.startsWith("$baseName.fdash_sep-") &&
                    candidate.extension.lowercase() in VIDEO_EXTENSIONS
            }
        }
        if (video == null) {
            if (!outputFile.exists()) {
                throw IllegalStateException("Итоговый файл не найден: $output")
            }
            return output
        }
        val audio = directory.listFiles()?.firstOrNull { candidate ->
            candidate.isFile &&
                candidate.name.startsWith("$baseName.fdash_sep-") &&
                candidate.extension.lowercase() in AUDIO_EXTENSIONS
        } ?: throw IllegalStateException("Не найдена звуковая дорожка для объединения")
        val merged = File(directory, "$baseName.${video.extension}")
        if (merged.exists()) return merged.absolutePath
        val ffmpeg = File(context.applicationInfo.nativeLibraryDir, "libffmpeg.so")
        val packages = File(
            File(context.noBackupFilesDir, YoutubeDL.baseName),
            "packages",
        )
        val ldLibraryPath = listOf(
            context.applicationInfo.nativeLibraryDir,
            File(packages, "python/usr/lib").absolutePath,
            File(packages, "ffmpeg/usr/lib").absolutePath,
        ).joinToString(":")
        val process = ProcessBuilder(
            ffmpeg.absolutePath,
            "-n",
            "-i",
            video.absolutePath,
            "-i",
            audio.absolutePath,
            "-c",
            "copy",
            merged.absolutePath,
        )
            .redirectErrorStream(true)
            .apply { environment()["LD_LIBRARY_PATH"] = ldLibraryPath }
            .start()
        val log = process.inputStream.bufferedReader().readText()
        val exitCode = process.waitFor()
        if (exitCode != 0) {
            throw IllegalStateException("FFmpeg merge failed: $log")
        }
        video.delete()
        audio.delete()
        return merged.absolutePath
    }

    private fun exportToSaf(treeValue: String, staging: File, output: String): String {
        val treeUri = Uri.parse(treeValue)
        try {
            context.contentResolver.takePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // Some pickers grant access only for the current session.
        }
        val tree = DocumentFile.fromTreeUri(context, treeUri)
            ?: throw IllegalStateException("Не удалось открыть выбранную папку")
        var primaryUri = ""
        staging.listFiles()?.forEach { source ->
            if (!source.isFile) return@forEach
            val mime = URLConnection.guessContentTypeFromName(source.name)
                ?: "application/octet-stream"
            val target = tree.createFile(mime, source.name)
                ?: throw IllegalStateException("Не удалось создать файл ${source.name}")
            context.contentResolver.openOutputStream(target.uri, "w")?.use { destination ->
                source.inputStream().use { input -> input.copyTo(destination) }
            } ?: throw IllegalStateException("Не удалось записать файл ${source.name}")
            if (source.absolutePath == File(output).absolutePath ||
                (primaryUri.isEmpty() && source.extension.lowercase() in MEDIA_EXTENSIONS)
            ) {
                primaryUri = target.uri.toString()
            }
        }
        staging.deleteRecursively()
        return primaryUri
    }

    private fun openFile(path: String) {
        val uri = if (path.startsWith("content://")) {
            Uri.parse(path)
        } else {
            FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                File(path),
            )
        }
        val mimeType = URLConnection.guessContentTypeFromName(path) ?: "video/*"
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    private fun openDownloads(path: String) {
        if (path.startsWith("content://")) {
            context.startActivity(
                Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse(path)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
            return
        }
        try {
            context.startActivity(
                Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        } catch (_: ActivityNotFoundException) {
            defaultDownloadDirectory()
        }
    }

    private fun startForegroundService() {
        val intent = Intent(context, DownloadForegroundService::class.java).apply {
            action = DownloadForegroundService.ACTION_START
        }
        context.startForegroundService(intent)
    }

    private fun stopForegroundService() {
        context.stopService(Intent(context, DownloadForegroundService::class.java))
    }

    private fun launchResult(
        result: MethodChannel.Result,
        block: suspend () -> Any?,
    ) {
        scope.launch {
            try {
                result.success(block())
            } catch (error: Exception) {
                result.error("ERROR", error.message ?: "Ошибка движка", null)
            }
        }
    }

    companion object {
        private const val ENGINE_CHANNEL = "com.orsofey.downloader/engine"
        private const val ACTIONS_CHANNEL = "com.orsofey.downloader/actions"
        private const val EVENTS_CHANNEL = "com.orsofey.downloader/events"
        private val MEDIA_EXTENSIONS = setOf("mp4", "webm", "mkv", "mp3", "m4a")
        private val AUDIO_EXTENSIONS = setOf("m4a", "webm", "aac", "ogg", "opus")
        private val VIDEO_EXTENSIONS = setOf("mp4", "webm", "mkv")
    }
}
