import 'dart:io';
import 'dart:typed_data';

import 'package:discord_native/features/messages/data/attachment_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilePickerAttachmentPicker', () {
    test('선택을 취소하면 빈 목록을 반환한다', () async {
      final picker = FilePickerAttachmentPicker(() async => null);

      final files = await picker.pick();

      expect(files, isEmpty);
    });

    test('메모리 바이트와 확장자로 업로드 파일을 만든다', () async {
      final picker = FilePickerAttachmentPicker(
        () async => FilePickerResult([
          PlatformFile(
            name: 'image.png',
            size: 3,
            bytes: Uint8List.fromList(const [1, 2, 3]),
          ),
        ]),
      );

      final files = await picker.pick();

      expect(files.single.filename, 'image.png');
      expect(files.single.bytes, const [1, 2, 3]);
      expect(files.single.contentType, 'image/png');
    });

    test('바이트가 없으면 파일 경로를 읽고 최대 10개로 제한한다', () async {
      final directory = await Directory.systemTemp.createTemp(
        'discord-native-picker-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}note.txt');
      await file.writeAsBytes(const [104, 105]);
      final picked = [
        for (var index = 0; index < 11; index += 1)
          PlatformFile(name: 'note-$index.txt', size: 2, path: file.path),
      ];
      final picker = FilePickerAttachmentPicker(
        () async => FilePickerResult(picked),
      );

      final files = await picker.pick();

      expect(files, hasLength(10));
      expect(files.first.bytes, const [104, 105]);
      expect(files.first.contentType, 'text/plain');
    });
  });
}
