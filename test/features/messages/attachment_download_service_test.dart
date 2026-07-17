import 'package:discord_native/features/messages/data/attachment_download_service.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordAttachmentDownloadService', () {
    test('저장 경로를 선택하고 HTTPS 첨부를 다운로드한다', () async {
      String? chosenFilename;
      Uri? downloadedUri;
      String? downloadedPath;
      final service = DiscordAttachmentDownloadService(
        chooseSavePath: (filename) async {
          chosenFilename = filename;
          return r'C:\Downloads\image.png';
        },
        downloadFile: (uri, path) async {
          downloadedUri = uri;
          downloadedPath = path;
        },
      );

      final path = await service.download(_attachment());

      expect(chosenFilename, 'image.png');
      expect(downloadedUri, Uri.parse('https://cdn.discordapp.com/image.png'));
      expect(downloadedPath, r'C:\Downloads\image.png');
      expect(path, r'C:\Downloads\image.png');
    });

    test('저장 대화상자를 취소하면 다운로드하지 않는다', () async {
      var downloadCount = 0;
      final service = DiscordAttachmentDownloadService(
        chooseSavePath: (_) async => null,
        downloadFile: (_, _) async => downloadCount += 1,
      );

      final path = await service.download(_attachment());

      expect(path, isNull);
      expect(downloadCount, 0);
    });

    test('HTTPS가 아니거나 Discord CDN이 아닌 URL을 거부한다', () {
      final service = DiscordAttachmentDownloadService(
        chooseSavePath: (_) async => r'C:\Downloads\image.png',
        downloadFile: (_, _) async {},
      );

      expect(
        () => service.download(_attachment(url: 'http://example.com/file')),
        throwsA(isA<InvalidAttachmentDownloadException>()),
      );
      expect(
        () => service.download(_attachment(url: 'https://example.com/file')),
        throwsA(isA<InvalidAttachmentDownloadException>()),
      );
    });
  });
}

DiscordAttachment _attachment({
  String url = 'https://cdn.discordapp.com/image.png',
}) {
  return DiscordAttachment(
    id: 'attachment-1',
    filename: 'image.png',
    url: url,
    proxyUrl: url,
    size: 1024,
    contentType: 'image/png',
  );
}
