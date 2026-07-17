import 'dart:typed_data';

import 'package:discord_native/features/voice/data/record_discord_microphone_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  group('RecordDiscordMicrophoneCapture', () {
    test('권한 확인 후 Discord PCM16 48kHz stereo stream을 시작한다', () async {
      final backend = _FakeRecordAudioBackend();
      final capture = RecordDiscordMicrophoneCapture(backend: backend);

      final stream = await capture.start();

      expect(stream, same(backend.stream));
      expect(backend.config?.encoder, AudioEncoder.pcm16bits);
      expect(backend.config?.sampleRate, 48000);
      expect(backend.config?.numChannels, 2);
      expect(backend.config?.echoCancel, isTrue);
      expect(backend.config?.noiseSuppress, isTrue);
      expect(capture.isCapturing, isTrue);

      await capture.stop();
      expect(backend.stopCalls, 1);
      expect(capture.isCapturing, isFalse);
      await capture.dispose();
    });

    test('마이크 권한 거부를 사용자 친화적 오류로 반환한다', () async {
      final backend = _FakeRecordAudioBackend()..permissionGranted = false;
      final capture = RecordDiscordMicrophoneCapture(backend: backend);

      expect(capture.start(), throwsA(isA<StateError>()));

      await capture.dispose();
      expect(backend.disposeCalls, 1);
    });

    test('중복 시작을 거부하고 dispose가 활성 capture를 정리한다', () async {
      final backend = _FakeRecordAudioBackend();
      final capture = RecordDiscordMicrophoneCapture(backend: backend);
      await capture.start();

      expect(capture.start(), throwsStateError);

      await capture.dispose();
      expect(backend.stopCalls, 1);
      expect(backend.disposeCalls, 1);
    });
  });
}

final class _FakeRecordAudioBackend implements RecordAudioBackend {
  final Stream<Uint8List> stream = const Stream.empty();
  bool permissionGranted = true;
  RecordConfig? config;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    this.config = config;
    return stream;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }
}
