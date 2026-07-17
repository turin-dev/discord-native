import 'package:dio/dio.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:file_picker/file_picker.dart';

typedef ChooseAttachmentSavePath = Future<String?> Function(String filename);
typedef DownloadAttachmentFile =
    Future<void> Function(Uri source, String destination);

abstract interface class AttachmentDownloadService {
  Future<String?> download(DiscordAttachment attachment);
}

final class InvalidAttachmentDownloadException implements Exception {
  const InvalidAttachmentDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DiscordAttachmentDownloadService
    implements AttachmentDownloadService {
  const DiscordAttachmentDownloadService({
    required ChooseAttachmentSavePath chooseSavePath,
    required DownloadAttachmentFile downloadFile,
  }) : _chooseSavePath = chooseSavePath,
       _downloadFile = downloadFile;

  factory DiscordAttachmentDownloadService.platformDefault() {
    return DiscordAttachmentDownloadService(
      chooseSavePath: _platformChooseSavePath,
      downloadFile: _platformDownloadFile,
    );
  }

  final ChooseAttachmentSavePath _chooseSavePath;
  final DownloadAttachmentFile _downloadFile;

  @override
  Future<String?> download(DiscordAttachment attachment) async {
    final source = _validatedAttachmentUri(attachment.url);
    final path = await _chooseSavePath(_safeFilename(attachment.filename));
    if (path == null) {
      return null;
    }
    await _downloadFile(source, path);
    return path;
  }
}

Future<String?> _platformChooseSavePath(String filename) {
  return FilePicker.saveFile(
    dialogTitle: '첨부 파일 저장',
    fileName: filename,
    lockParentWindow: true,
  );
}

Future<void> _platformDownloadFile(Uri source, String destination) async {
  await Dio().downloadUri(source, destination, deleteOnError: true);
}

Uri _validatedAttachmentUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      !const {
        'cdn.discordapp.com',
        'media.discordapp.net',
      }.contains(uri.host)) {
    throw const InvalidAttachmentDownloadException(
      'Discord CDN의 HTTPS 첨부만 저장할 수 있습니다.',
    );
  }
  return uri;
}

String _safeFilename(String value) {
  final normalized = value
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_')
      .trim();
  return normalized.isEmpty ? 'discord-attachment' : normalized;
}
