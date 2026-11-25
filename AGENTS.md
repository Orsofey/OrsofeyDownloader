# Orsofey Downloader — agent guide

## Product

Local Flutter downloader for YouTube, TikTok and VK Video on Windows and Android. No backend, analytics, ads or accounts. Russian UI, light minimal design with indigo/lavender accents and restrained 180–300 ms motion.

## Required conventions

- Keep downloads and metadata on the user's device. Do not add remote logging or telemetry.
- Never print, commit or transmit cookies, passwords, `android/key.properties`, `android/signing/`, tokens or signing secrets.
- Accept only HTTP(S) links from explicitly supported hosts in `lib/core/utils/url_parser.dart`.
- Start native processes with argument lists, never by concatenating a user-provided shell command.
- Preserve partial downloads so pause/resume and retry can use `--continue`.
- Keep Flutter UI platform-neutral; platform-specific download behavior belongs behind `DownloadEngine`.
- Use GPL-3.0 and retain third-party notices when changing native runtime dependencies.

## Structure

- `lib/core/models`: serializable settings/tasks and media metadata.
- `lib/core/services/app_controller.dart`: queue and application state.
- `lib/core/services/cookie_store.dart` + `dpapi_cookie_file.dart`: secure cookies (Android Keystore AES-GCM / Windows DPAPI).
- `lib/core/services/yt_dlp_engine.dart`: Windows process engine.
- `lib/core/services/android_download_engine.dart`: Dart side of Android channels.
- `android/.../DownloaderBridge.kt`: Android yt-dlp runtime, channels and file actions.
- `lib/features`: four main screens.
- `lib/shared/widgets/ui.dart`: design-system components.
- `tool`: icon generation, dependency preparation, signing and packaging.

## Verification

Run after relevant changes:

```powershell
$env:PUB_CACHE = "$PWD\.pub-cache"
dart format lib test
flutter analyze
flutter test
```

Android:

```powershell
$env:GRADLE_USER_HOME = "$PWD\.gradle"
flutter build apk --debug --target-platform android-arm64
```

Windows requires a complete Visual Studio 2022 C++ workload. Packaging additionally requires Inno Setup 6 or 7.

## Native runtime pins

- `youtubedl-android:library:0.18.1` and `common:0.18.1` (Python 3.12 + QuickJS).
- `io.github.deniscerri:ytdlnis_packages.ffmpeg:9.0.2` for 16 KB page-size compatibility; do not combine with `youtubedl-android:ffmpeg`.
- Windows engine is downloaded by `tool/prepare_windows_engine.ps1` and SHA256-verified.

Do not combine `youtubedl-android` with `ytdlnis_packages.python`: native libraries conflict. If Deno/Node is added on Android, implement explicit runtime initialization and environment setup rather than only adding an AAR.

## Builds

- `tool/prepare_android_engine.ps1` (downloads and verifies the current yt-dlp zipimport asset into `res/raw/ytdlp`)
- `tool/build_android.ps1 -Configuration debug|release`
- `tool/prepare_windows_engine.ps1`
- `tool/build_windows.ps1 [-SkipInstaller]`
- `tool/generate_icons.ps1`

Release signing files are generated once locally and must be backed up by the user. Do not replace an existing keystore.
