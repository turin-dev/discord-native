import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

abstract interface class DiscordVoicePlayback {
  Future<void> initialize();

  Future<void> addPcm(String remoteUserId, Int16List pcm);

  void setUserVolume(String remoteUserId, double volume);

  Future<void> removeUser(String remoteUserId);

  Future<void> dispose();
}

abstract interface class SoloudPlaybackStream {}

abstract interface class SoloudPlaybackBackend {
  Future<void> initialize();

  Future<SoloudPlaybackStream> createStream({
    required Uint8List initialPcm,
    required double volume,
  });

  void addPcm(SoloudPlaybackStream stream, Uint8List pcm);

  void setVolume(SoloudPlaybackStream stream, double volume);

  Future<void> disposeStream(SoloudPlaybackStream stream);

  Future<void> dispose();
}

final class NativeSoloudPlaybackStream implements SoloudPlaybackStream {
  const NativeSoloudPlaybackStream({
    required this.source,
    required this.handle,
  });

  final AudioSource source;
  final SoundHandle handle;
}

final class NativeSoloudPlaybackBackend implements SoloudPlaybackBackend {
  NativeSoloudPlaybackBackend({SoLoud? player})
    : _player = player ?? SoLoud.instance;

  final SoLoud _player;

  @override
  Future<void> initialize() async {
    if (_player.isInitialized) {
      return;
    }
    await _player.init(
      sampleRate: 48000,
      bufferSize: 960,
      channels: Channels.stereo,
      lowLatency: true,
    );
  }

  @override
  Future<SoloudPlaybackStream> createStream({
    required Uint8List initialPcm,
    required double volume,
  }) async {
    final source = _player.setBufferStream(
      maxBufferSizeDuration: const Duration(minutes: 5),
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0.04,
      sampleRate: 48000,
      channels: Channels.stereo,
      format: BufferType.s16le,
    );
    try {
      _player.addAudioDataStream(source, initialPcm);
      final handle = _player.play(source, volume: volume);
      return NativeSoloudPlaybackStream(source: source, handle: handle);
    } on Object {
      await _player.disposeSource(source);
      rethrow;
    }
  }

  @override
  void addPcm(SoloudPlaybackStream stream, Uint8List pcm) {
    final nativeStream = _readNativeStream(stream);
    _player.addAudioDataStream(nativeStream.source, pcm);
  }

  @override
  void setVolume(SoloudPlaybackStream stream, double volume) {
    final nativeStream = _readNativeStream(stream);
    _player.setVolume(nativeStream.handle, volume);
  }

  @override
  Future<void> disposeStream(SoloudPlaybackStream stream) async {
    final nativeStream = _readNativeStream(stream);
    _player.setDataIsEnded(nativeStream.source);
    try {
      await _player.stop(nativeStream.handle);
    } finally {
      await _player.disposeSource(nativeStream.source);
    }
  }

  @override
  Future<void> dispose() async {
    if (_player.isInitialized) {
      _player.deinit();
    }
  }

  NativeSoloudPlaybackStream _readNativeStream(SoloudPlaybackStream stream) {
    if (stream is! NativeSoloudPlaybackStream) {
      throw StateError('SoLoud playback stream 형식이 올바르지 않습니다.');
    }
    return stream;
  }
}

final class SoloudDiscordVoicePlayback implements DiscordVoicePlayback {
  SoloudDiscordVoicePlayback({SoloudPlaybackBackend? backend})
    : _backend = backend ?? NativeSoloudPlaybackBackend();

  final SoloudPlaybackBackend _backend;
  Map<String, SoloudPlaybackStream> _streams = const {};
  Map<String, double> _volumes = const {};
  bool _initialized = false;
  bool _disposed = false;

  @override
  Future<void> initialize() async {
    _ensureActive();
    if (_initialized) {
      return;
    }
    try {
      await _backend.initialize();
      _initialized = true;
    } on Object catch (error) {
      throw StateError('음성 출력 장치를 초기화하지 못했습니다: $error');
    }
  }

  @override
  Future<void> addPcm(String remoteUserId, Int16List pcm) async {
    _ensureReady();
    _validateUserId(remoteUserId);
    if (pcm.isEmpty) {
      return;
    }
    final bytes = _toLittleEndianBytes(pcm);
    final stream = _streams[remoteUserId];
    try {
      if (stream != null) {
        _backend.addPcm(stream, bytes);
        return;
      }
      final created = await _backend.createStream(
        initialPcm: bytes,
        volume: _volumes[remoteUserId] ?? 1,
      );
      _streams = Map.unmodifiable({..._streams, remoteUserId: created});
    } on Object catch (error) {
      throw StateError('사용자 음성을 재생하지 못했습니다: $error');
    }
  }

  @override
  void setUserVolume(String remoteUserId, double volume) {
    _ensureReady();
    _validateUserId(remoteUserId);
    if (!volume.isFinite || volume < 0 || volume > 2) {
      throw const FormatException('사용자 음량은 0~200% 범위여야 합니다.');
    }
    _volumes = Map.unmodifiable({..._volumes, remoteUserId: volume});
    final stream = _streams[remoteUserId];
    if (stream != null) {
      _backend.setVolume(stream, volume);
    }
  }

  @override
  Future<void> removeUser(String remoteUserId) async {
    _ensureReady();
    _validateUserId(remoteUserId);
    final stream = _streams[remoteUserId];
    if (stream != null) {
      try {
        await _backend.disposeStream(stream);
      } on Object catch (error) {
        throw StateError('사용자 음성 stream을 정리하지 못했습니다: $error');
      }
    }
    _streams = Map.unmodifiable(
      Map<String, SoloudPlaybackStream>.fromEntries(
        _streams.entries.where((entry) => entry.key != remoteUserId),
      ),
    );
    _volumes = Map.unmodifiable(
      Map<String, double>.fromEntries(
        _volumes.entries.where((entry) => entry.key != remoteUserId),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    Object? disposalError;
    for (final stream in _streams.values) {
      try {
        await _backend.disposeStream(stream);
      } on Object catch (error) {
        disposalError ??= error;
      }
    }
    try {
      await _backend.dispose();
    } on Object catch (error) {
      disposalError ??= error;
    }
    _streams = const {};
    _volumes = const {};
    _disposed = true;
    if (disposalError != null) {
      throw StateError('음성 출력 resource를 정리하지 못했습니다: $disposalError');
    }
  }

  Uint8List _toLittleEndianBytes(Int16List pcm) {
    final bytes = Uint8List(pcm.lengthInBytes);
    final data = ByteData.sublistView(bytes);
    for (var index = 0; index < pcm.length; index += 1) {
      data.setInt16(index * 2, pcm[index], Endian.little);
    }
    return bytes;
  }

  void _validateUserId(String remoteUserId) {
    if (remoteUserId.isEmpty || int.tryParse(remoteUserId) == null) {
      throw const FormatException('음성 사용자 ID는 숫자 snowflake여야 합니다.');
    }
  }

  void _ensureReady() {
    _ensureActive();
    if (!_initialized) {
      throw StateError('음성 출력 장치가 초기화되지 않았습니다.');
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('이미 종료된 음성 출력입니다.');
    }
  }
}
