import 'dart:typed_data';

import 'package:discord_native/features/voice/data/soloud_discord_voice_playback.dart';
import 'package:discord_native/features/voice/domain/discord_audio_device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoloudDiscordVoicePlayback', () {
    test('사용자별 PCM stream을 만들고 s16le byte를 연속 공급한다', () async {
      final backend = _FakeSoloudPlaybackBackend();
      final playback = SoloudDiscordVoicePlayback(backend: backend);
      await playback.initialize();

      await playback.addPcm('7', Int16List.fromList([0x1234, -2]));
      await playback.addPcm('7', Int16List.fromList([1, 2]));

      expect(backend.initialized, isTrue);
      expect(backend.created, hasLength(1));
      expect(backend.created.single.initialPcm, [0x34, 0x12, 0xFE, 0xFF]);
      expect(backend.created.single.volume, 1);
      expect(backend.added.single, [1, 0, 2, 0]);

      await playback.dispose();
    });

    test('stream 생성 전후 사용자별 0~200% volume을 적용한다', () async {
      final backend = _FakeSoloudPlaybackBackend();
      final playback = SoloudDiscordVoicePlayback(backend: backend);
      await playback.initialize();

      playback.setUserVolume('8', 1.5);
      await playback.addPcm('8', Int16List.fromList([0]));
      playback.setUserVolume('8', 0.25);

      expect(backend.created.single.volume, 1.5);
      expect(backend.volumes, [0.25]);
      expect(() => playback.setUserVolume('8', 2.1), throwsFormatException);

      await playback.dispose();
    });

    test('사용자 제거와 dispose가 native stream을 명시적으로 정리한다', () async {
      final backend = _FakeSoloudPlaybackBackend();
      final playback = SoloudDiscordVoicePlayback(backend: backend);
      await playback.initialize();
      await playback.addPcm('7', Int16List.fromList([0]));
      await playback.addPcm('8', Int16List.fromList([0]));

      await playback.removeUser('7');
      await playback.dispose();

      expect(backend.disposedStreamIds, [1, 2]);
      expect(backend.disposed, isTrue);
    });

    test('초기화할 때 저장한 출력 장치를 선택한다', () async {
      final backend = _FakeSoloudPlaybackBackend();
      final playback = SoloudDiscordVoicePlayback(
        backend: backend,
        outputDeviceId: '8',
      );

      await playback.initialize();

      expect(backend.selectedDeviceId, '8');
      await playback.dispose();
    });
  });
}

final class _FakePlaybackStream implements SoloudPlaybackStream {
  const _FakePlaybackStream(this.id);

  final int id;
}

final class _CreatedStream {
  const _CreatedStream({required this.initialPcm, required this.volume});

  final Uint8List initialPcm;
  final double volume;
}

final class _FakeSoloudPlaybackBackend implements SoloudPlaybackBackend {
  bool initialized = false;
  bool disposed = false;
  List<_CreatedStream> created = const [];
  List<Uint8List> added = const [];
  List<double> volumes = const [];
  List<int> disposedStreamIds = const [];
  String? selectedDeviceId;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  List<DiscordAudioDevice> listPlaybackDevices() => const [
    DiscordAudioDevice(id: '7', label: '기본 스피커', isDefault: true),
    DiscordAudioDevice(id: '8', label: 'USB 헤드셋'),
  ];

  @override
  void selectPlaybackDevice(String deviceId) {
    selectedDeviceId = deviceId;
  }

  @override
  Future<SoloudPlaybackStream> createStream({
    required Uint8List initialPcm,
    required double volume,
  }) async {
    created = List.unmodifiable([
      ...created,
      _CreatedStream(
        initialPcm: Uint8List.fromList(initialPcm),
        volume: volume,
      ),
    ]);
    return _FakePlaybackStream(created.length);
  }

  @override
  void addPcm(SoloudPlaybackStream stream, Uint8List pcm) {
    added = List.unmodifiable([...added, Uint8List.fromList(pcm)]);
  }

  @override
  void setVolume(SoloudPlaybackStream stream, double volume) {
    volumes = List.unmodifiable([...volumes, volume]);
  }

  @override
  Future<void> disposeStream(SoloudPlaybackStream stream) async {
    disposedStreamIds = List.unmodifiable([
      ...disposedStreamIds,
      (stream as _FakePlaybackStream).id,
    ]);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
