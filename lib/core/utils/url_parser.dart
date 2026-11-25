import '../models/media_info.dart';

class ParsedLink {
  const ParsedLink({required this.uri, required this.source});

  final Uri uri;
  final MediaSource source;
}

ParsedLink? parseSupportedLink(String input) {
  final value = input.trim().replaceAll(RegExp(r'''^["']|["']$'''), '');
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;

  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final source = switch (host) {
    'youtu.be' ||
    'youtube.com' ||
    'm.youtube.com' ||
    'music.youtube.com' ||
    'youtube-nocookie.com' => MediaSource.youtube,
    'tiktok.com' ||
    'm.tiktok.com' ||
    'vm.tiktok.com' ||
    'vt.tiktok.com' => MediaSource.tiktok,
    'vk.com' ||
    'm.vk.com' ||
    'vk.ru' ||
    'vkvideo.ru' ||
    'm.vkvideo.ru' => MediaSource.vk,
    _ => MediaSource.unknown,
  };

  if (source == MediaSource.unknown) return null;
  return ParsedLink(uri: uri, source: source);
}

bool isSupportedLink(String input) => parseSupportedLink(input) != null;

String normalizedLink(String input) {
  final parsed = parseSupportedLink(input);
  return parsed?.uri.toString() ?? input.trim();
}
