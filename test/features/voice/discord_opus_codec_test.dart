import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_opus_codec.dart';
import 'package:discord_native/features/voice/data/discord_pcm_frame_assembler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final libraryPath = _flutterSoloudOpusPath();

  test(
    'libopus로 20ms stereo PCM frame을 encode/decode 왕복한다',
    () {
      final codec = NativeDiscordOpusCodec.open(libraryPath: libraryPath);
      addTearDown(codec.close);
      final pcm = Int16List(DiscordPcmFrameAssembler.samplesPerFrame);

      final packet = codec.encode(pcm);
      final decoded = codec.decode(packet, remoteUserId: '7');

      expect(codec.version, startsWith('libopus'));
      expect(packet, isNotEmpty);
      expect(decoded, hasLength(DiscordPcmFrameAssembler.samplesPerFrame));
      expect(decoded, everyElement(0));
    },
    skip: !Platform.isWindows,
  );

  test('20ms가 아닌 PCM frame을 Opus 경계에서 거부한다', () {
    final codec = NativeDiscordOpusCodec.open(libraryPath: libraryPath);
    addTearDown(codec.close);

    expect(() => codec.encode(Int16List(10)), throwsFormatException);
  }, skip: !Platform.isWindows);
}

String _flutterSoloudOpusPath() {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  if (config is! Map<String, Object?> || config['packages'] is! List<Object?>) {
    throw const FormatException('package_config.json 형식이 잘못되었습니다.');
  }
  final package = (config['packages']! as List<Object?>)
      .whereType<Map<String, Object?>>()
      .firstWhere((value) => value['name'] == 'flutter_soloud');
  final root = package['rootUri'];
  if (root is! String) {
    throw const FormatException('flutter_soloud rootUri가 없습니다.');
  }
  return Uri.parse('$root/').resolve('windows/libs/opus.dll').toFilePath();
}
