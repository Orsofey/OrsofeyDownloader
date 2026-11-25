import 'package:flutter_test/flutter_test.dart';
import 'package:orsofey_downloader/core/models/media_info.dart';
import 'package:orsofey_downloader/core/utils/url_parser.dart';

void main() {
  group('parseSupportedLink', () {
    test('распознаёт поддерживаемые площадки', () {
      final cases = {
        'https://youtu.be/dQw4w9WgXcQ': MediaSource.youtube,
        'https://www.youtube.com/shorts/abc': MediaSource.youtube,
        'https://vm.tiktok.com/abc/': MediaSource.tiktok,
        'https://www.tiktok.com/@user/video/123': MediaSource.tiktok,
        'https://vk.com/video-123_456': MediaSource.vk,
        'https://vkvideo.ru/video-123_456': MediaSource.vk,
      };
      for (final entry in cases.entries) {
        expect(parseSupportedLink(entry.key)?.source, entry.value);
      }
    });

    test('отклоняет другие протоколы и неподдерживаемые домены', () {
      expect(parseSupportedLink('javascript:alert(1)'), isNull);
      expect(parseSupportedLink('file:///C:/video.mp4'), isNull);
      expect(parseSupportedLink('https://example.com/video'), isNull);
      expect(parseSupportedLink('не ссылка'), isNull);
    });

    test('не принимает похожие поддомены злоумышленника', () {
      expect(
        parseSupportedLink('https://youtube.com.evil.example/watch'),
        isNull,
      );
      expect(parseSupportedLink('https://notyoutube.com/watch'), isNull);
    });
  });

  test('MediaInfo собирает качества и расширения из yt-dlp JSON', () {
    final info = MediaInfo.fromYtDlpJson({
      'id': 'abc',
      'title': 'Video',
      'webpage_url': 'https://youtu.be/abc',
      'formats': [
        {'format_id': '1', 'height': 720, 'ext': 'mp4'},
        {'format_id': '2', 'height': 1080, 'ext': 'webm'},
        {'format_id': '3', 'height': 1080, 'ext': 'mp4'},
      ],
    }, MediaSource.youtube);

    expect(info.availableHeights, [1080, 720]);
    expect(info.availableVideoExtensions, ['mp4', 'webm']);
  });

  test('MediaInfo оценивает размер видео и звуковой дорожки', () {
    final info = MediaInfo.fromYtDlpJson({
      'id': 'abc',
      'title': 'Video',
      'webpage_url': 'https://youtu.be/abc',
      'formats': [
        {
          'format_id': 'video',
          'height': 1080,
          'ext': 'mp4',
          'vcodec': 'avc1',
          'acodec': 'none',
          'filesize': 1000,
        },
        {
          'format_id': 'audio',
          'ext': 'm4a',
          'vcodec': 'none',
          'acodec': 'mp4a',
          'filesize': 200,
        },
      ],
    }, MediaSource.youtube);

    expect(info.estimatedSize(1080, 'mp4'), 1200);
  });
}
