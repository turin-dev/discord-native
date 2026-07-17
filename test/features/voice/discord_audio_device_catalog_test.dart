import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_audio_device_catalog.dart';
import 'package:discord_native/features/voice/data/record_discord_microphone_capture.dart';
import 'package:discord_native/features/voice/data/soloud_discord_voice_playback.dart';
import 'package:discord_native/features/voice/domain/discord_audio_device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  test('입력과 출력 장치 목록을 하나의 catalog로 불러온다', () async {
    final input = _InputBackend();
    final output = _OutputBackend();

    final catalog = await loadDiscordAudioDeviceCatalog(
      inputBackend: input,
      outputBackend: output,
    );

    expect(catalog.inputDevices.single.label, 'USB 마이크');
    expect(catalog.outputDevices.single.label, 'USB 헤드셋');
    expect(input.disposed, isTrue);
    expect(output.initialized, isTrue);
  });
}

final class _InputBackend implements RecordAudioBackend {
  bool disposed = false;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<List<DiscordAudioDevice>> listInputDevices() async => const [
    DiscordAudioDevice(id: 'mic-1', label: 'USB 마이크'),
  ];

  @override
  Future<Stream<Uint8List>> startStream(
    RecordConfig config, {
    String? deviceId,
  }) async => const Stream.empty();

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

final class _OutputBackend implements SoloudPlaybackBackend {
  bool initialized = false;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  List<DiscordAudioDevice> listPlaybackDevices() => const [
    DiscordAudioDevice(id: '7', label: 'USB 헤드셋'),
  ];

  @override
  void selectPlaybackDevice(String deviceId) {}

  @override
  Future<SoloudPlaybackStream> createStream({
    required Uint8List initialPcm,
    required double volume,
  }) {
    throw UnimplementedError();
  }

  @override
  void addPcm(SoloudPlaybackStream stream, Uint8List pcm) {}

  @override
  void setVolume(SoloudPlaybackStream stream, double volume) {}

  @override
  Future<void> disposeStream(SoloudPlaybackStream stream) async {}

  @override
  Future<void> dispose() async {}
}
