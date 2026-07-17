import 'dart:io';
import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_dave_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  final libraryPath = path.join(
    Directory.current.path,
    'windows',
    'libdave',
    'libdave.dll',
  );

  test('공식 libdave로 DAVE v1 MLS key package를 생성한다', () {
    final session = NativeDiscordDaveSession.open(libraryPath: libraryPath);
    addTearDown(session.close);

    expect(session.maxSupportedProtocolVersion, 1);

    session.initialize(
      protocolVersion: 1,
      groupId: 123456789012345678,
      selfUserId: '234567890123456789',
    );

    expect(session.protocolVersion, 1);
    expect(session.createKeyPackage(), isNotEmpty);
  }, skip: !Platform.isWindows);

  test('DAVE protocol 0에서 Opus frame을 passthrough로 왕복한다', () {
    final session = NativeDiscordDaveSession.open(libraryPath: libraryPath);
    addTearDown(session.close);
    session.initialize(
      protocolVersion: 0,
      groupId: 123456789012345678,
      selfUserId: '234567890123456789',
    );
    session.assignLocalAudioSsrc(42);
    session.setPassthroughMode(enabled: true, remoteUserIds: const ['7']);
    final opusFrame = Uint8List.fromList([0xF8, 0xFF, 0xFE]);

    final encrypted = session.encryptAudio(opusFrame, ssrc: 42);
    final decrypted = session.decryptAudio(encrypted, remoteUserId: '7');

    expect(encrypted, opusFrame);
    expect(decrypted, opusFrame);
  }, skip: !Platform.isWindows);

  test(
    'DAVE protocol 0에서 H264 video frame을 passthrough로 왕복한다',
    () {
      final session = NativeDiscordDaveSession.open(libraryPath: libraryPath);
      addTearDown(session.close);
      session.initialize(
        protocolVersion: 0,
        groupId: 123456789012345678,
        selfUserId: '234567890123456789',
      );
      session.assignLocalVideoSsrc(43, codec: DiscordDaveVideoCodec.h264);
      session.setPassthroughMode(enabled: true, remoteUserIds: const ['7']);
      final h264Frame = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x01,
        0x65,
        0x88,
        0x84,
      ]);

      final encrypted = session.encryptVideo(h264Frame, ssrc: 43);
      final decrypted = session.decryptVideo(encrypted, remoteUserId: '7');

      expect(encrypted, h264Frame);
      expect(decrypted, h264Frame);
    },
    skip: !Platform.isWindows,
  );
}
