import 'dart:typed_data';

import 'package:discord_native/features/voice/domain/discord_audio_device.dart';
import 'package:record/record.dart';

abstract interface class DiscordMicrophoneCapture {
  bool get isCapturing;

  Future<Stream<Uint8List>> start();

  Future<void> stop();

  Future<void> dispose();
}

abstract interface class RecordAudioBackend {
  Future<bool> hasPermission();

  Future<List<DiscordAudioDevice>> listInputDevices();

  Future<Stream<Uint8List>> startStream(
    RecordConfig config, {
    String? deviceId,
  });

  Future<void> stop();

  Future<void> dispose();
}

final class AudioRecorderBackend implements RecordAudioBackend {
  AudioRecorderBackend({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<List<DiscordAudioDevice>> listInputDevices() async {
    final devices = await _recorder.listInputDevices();
    return List.unmodifiable([
      for (final device in devices)
        DiscordAudioDevice(id: device.id, label: device.label),
    ]);
  }

  @override
  Future<Stream<Uint8List>> startStream(
    RecordConfig config, {
    String? deviceId,
  }) async {
    final device = await _findDevice(deviceId);
    return _recorder.startStream(_withDevice(config, device));
  }

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();

  Future<InputDevice?> _findDevice(String? deviceId) async {
    if (deviceId == null || deviceId.isEmpty) {
      return null;
    }
    final devices = await _recorder.listInputDevices();
    for (final device in devices) {
      if (device.id == deviceId) {
        return device;
      }
    }
    return null;
  }
}

RecordConfig _withDevice(RecordConfig config, InputDevice? device) {
  return RecordConfig(
    encoder: config.encoder,
    bitRate: config.bitRate,
    sampleRate: config.sampleRate,
    numChannels: config.numChannels,
    device: device,
    autoGain: config.autoGain,
    echoCancel: config.echoCancel,
    noiseSuppress: config.noiseSuppress,
    androidConfig: config.androidConfig,
    iosConfig: config.iosConfig,
    audioInterruption: config.audioInterruption,
    streamBufferSize: config.streamBufferSize,
  );
}

final class RecordDiscordMicrophoneCapture implements DiscordMicrophoneCapture {
  RecordDiscordMicrophoneCapture({
    RecordAudioBackend? backend,
    this.inputDeviceId = '',
  }) : _backend = backend ?? AudioRecorderBackend();

  static const RecordConfig config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 48000,
    numChannels: 2,
    echoCancel: true,
    noiseSuppress: true,
  );

  final RecordAudioBackend _backend;
  final String inputDeviceId;
  bool _capturing = false;
  bool _disposed = false;

  @override
  bool get isCapturing => _capturing;

  @override
  Future<Stream<Uint8List>> start() async {
    _ensureActive();
    if (_capturing) {
      throw StateError('마이크 capture가 이미 실행 중입니다.');
    }
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      throw StateError('마이크 권한이 필요합니다. Windows 설정에서 허용해 주세요.');
    }
    try {
      final stream = await _backend.startStream(
        config,
        deviceId: inputDeviceId.isEmpty ? null : inputDeviceId,
      );
      _capturing = true;
      return stream;
    } on Object catch (error) {
      throw StateError('마이크 capture를 시작하지 못했습니다: $error');
    }
  }

  @override
  Future<void> stop() async {
    _ensureActive();
    if (!_capturing) {
      return;
    }
    try {
      await _backend.stop();
    } on Object catch (error) {
      throw StateError('마이크 capture를 중지하지 못했습니다: $error');
    } finally {
      _capturing = false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    if (_capturing) {
      await stop();
    }
    try {
      await _backend.dispose();
    } on Object catch (error) {
      throw StateError('마이크 resource를 정리하지 못했습니다: $error');
    } finally {
      _disposed = true;
    }
  }

  Future<bool> _checkPermission() async {
    try {
      return await _backend.hasPermission();
    } on Object catch (error) {
      throw StateError('마이크 권한을 확인하지 못했습니다: $error');
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('이미 종료된 마이크 capture입니다.');
    }
  }
}
