import 'dart:io';

import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

typedef PlatformFilesPicker = Future<FilePickerResult?> Function();

abstract interface class AttachmentPicker {
  Future<List<DiscordUploadFile>> pick();
}

final class FilePickerAttachmentPicker implements AttachmentPicker {
  const FilePickerAttachmentPicker([this._pickFiles = _pickFilesFromPlatform]);

  final PlatformFilesPicker _pickFiles;

  @override
  Future<List<DiscordUploadFile>> pick() async {
    final result = await _pickFiles();
    if (result == null) {
      return const [];
    }
    final files = <DiscordUploadFile>[];
    for (final picked in result.files.take(10)) {
      final bytes = picked.bytes ?? await _readPath(picked.path);
      if (bytes == null) {
        continue;
      }
      files.add(
        DiscordUploadFile(
          filename: picked.name,
          bytes: List.unmodifiable(bytes),
          contentType:
              lookupMimeType(picked.name, headerBytes: bytes) ??
              'application/octet-stream',
        ),
      );
    }
    return List.unmodifiable(files);
  }
}

Future<FilePickerResult?> _pickFilesFromPlatform() {
  return FilePicker.pickFiles(
    allowMultiple: true,
    withData: true,
    type: FileType.any,
  );
}

Future<List<int>?> _readPath(String? path) async {
  if (path == null) {
    return null;
  }
  return File(path).readAsBytes();
}
