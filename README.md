# Orsofey Downloader

Светлое локальное приложение для скачивания видео и аудио по ссылкам **YouTube, TikTok и VK Видео** на Windows и Android. Без собственного сервера, аккаунтов, рекламы и телеметрии.

## Возможности

- одиночные видео и плейлисты с выбором элементов;
- предпросмотр обложки, названия, автора и длительности;
- выбор качества и контейнера MP4/WebM, если они доступны у источника;
- извлечение MP3 с битрейтом 128–320 кбит/с;
- субтитры и обложки отдельно или встроенные в медиа;
- очередь, одновременные загрузки, пауза/продолжение через частичные файлы, отмена и повтор;
- локальная история, поиск, открытие файла и папки;
- публичные и доступные пользователю приватные видео через cookies;
- фоновые загрузки Android с системным уведомлением;
- обновление yt-dlp из настроек.

Приложение не обходит DRM и платные ограничения. Скачивайте только материалы, которые имеете право сохранять.

## Архитектура

- **Flutter/Dart:** общий UI, состояние, очередь, модели и локальная история.
- **Windows:** `yt-dlp.exe`, FFmpeg и Deno запускаются как локальные дочерние процессы.
- **Android:** Kotlin bridge через MethodChannel/EventChannel, `youtubedl-android`, FFmpeg и QuickJS.
- **Хранение:** JSON-состояние в application support; cookies — собственная реализация Windows DPAPI / Android Keystore (AES-GCM).

Основные директории:

```text
lib/
  core/models       # настройки, медиа, задания
  core/services     # движки, очередь, cookies, файловые действия
  core/theme        # цвета и типографика
  core/utils        # ссылки и форматирование
  features          # главная, очередь, история, настройки
  shared            # AppScope и переиспользуемые виджеты
android/app/src/main/kotlin/...  # Android runtime и foreground service
packaging/windows/               # Inno Setup
assets/                           # Manrope и фирменные иконки
licenses/                         # лицензии ресурсов
tool/                             # воспроизводимые скрипты сборки
```

## Требования для разработки

- Flutter 3.47+ / Dart 3.13+;
- Android SDK 36 и JDK 17+;
- Windows 10/11 и Visual Studio 2022 с рабочей нагрузкой **Desktop development with C++**;
- Inno Setup 6 или 7 — только для создания `Setup.exe`.

Зависимости Dart и Gradle в командах ниже помещаются в локальные `.pub-cache` и `.gradle` проекта.

## Проверка

```powershell
$env:PUB_CACHE = "$PWD\.pub-cache"
flutter pub get
dart format lib test
flutter analyze
flutter test
```

## Сборка Android

```powershell
# При необходимости обновить встроенный yt-dlp и проверить SHA256
powershell -ExecutionPolicy Bypass -File tool\prepare_android_engine.ps1 -Force

# Debug
powershell -ExecutionPolicy Bypass -File tool\build_android.ps1 -Configuration debug

# Release: при первом запуске создаётся локальный ключ подписи
powershell -ExecutionPolicy Bypass -File tool\build_android.ps1 -Configuration release
```

Результат: `dist\OrsofeyDownloader-arm64-v8a-release.apk` и `.sha256`.

**Важно:** `android/key.properties` и `android/signing/` исключены из Git. Сохраните их в безопасном резервном месте: без того же ключа нельзя будет выпускать обновления поверх установленного APK.

## Сборка Windows

```powershell
# Скачивает и проверяет SHA256 yt-dlp, FFmpeg и Deno в engine/windows
powershell -ExecutionPolicy Bypass -File tool\prepare_windows_engine.ps1

# Release без установщика
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -SkipInstaller

# Release + Setup.exe (нужен Inno Setup 6 или 7)
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
```

Результат установщика: `dist\OrsofeyDownloader-Setup.exe` и `.sha256`.

## Cookies и приватные видео

- На Windows можно выбрать текущую сессию поддерживаемого браузера или импортировать Netscape `cookies.txt`.
- На Android импортируется `cookies.txt`.
- Пароли в приложение вводить не нужно.
- Временный файл cookies удаляется после анализа/загрузки; основная копия хранится в зашифрованном системном хранилище.

## Ограничения площадок

Платформы периодически меняют выдачу и требования к клиентам, поэтому конкретный формат или ссылка могут временно не работать. Для части форматов YouTube дополнительно может потребоваться PO Token. На Android используется `ytdlnis_packages.ffmpeg:9.0.2` с совместимостью 16 KB page size; его нельзя смешивать с модулем `youtubedl-android:ffmpeg`.

## Лицензия

Исходный код приложения распространяется под **GPL-3.0**. См. `LICENSE` и `THIRD_PARTY_NOTICES.md`. Шрифт Manrope — SIL Open Font License, см. `licenses/Manrope-OFL.txt`.
