import 'dart:ffi';
import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_pcm_frame_assembler.dart';
import 'package:opus_dart/opus_dart.dart';

abstract interface class DiscordOpusCodec {
  String get version;

  Uint8List encode(Int16List pcmFrame);

  Int16List decode(Uint8List opusPacket, {required String remoteUserId});

  Int16List decodePacketLoss({
    required String remoteUserId,
    int durationMilliseconds,
  });

  void removeRemoteUser(String remoteUserId);

  void close();
}

final class NativeDiscordOpusCodec implements DiscordOpusCodec {
  NativeDiscordOpusCodec._(this._encoder);

  static bool _libraryInitialized = false;

  final SimpleOpusEncoder _encoder;
  Map<String, SimpleOpusDecoder> _decoders = const {};
  bool _closed = false;

  factory NativeDiscordOpusCodec.open({required String libraryPath}) {
    if (libraryPath.trim().isEmpty) {
      throw const FormatException('libopus library path가 비어 있습니다.');
    }
    if (!_libraryInitialized) {
      try {
        final dynamic opusLibrary = DynamicLibrary.open(libraryPath);
        initOpus(opusLibrary);
        _libraryInitialized = true;
      } on ArgumentError catch (error) {
        throw StateError('libopus를 로드하지 못했습니다: $error');
      }
    }
    return NativeDiscordOpusCodec._(
      SimpleOpusEncoder(
        sampleRate: DiscordPcmFrameAssembler.sampleRate,
        channels: DiscordPcmFrameAssembler.channels,
        application: Application.voip,
      ),
    );
  }

  @override
  String get version {
    _ensureOpen();
    return getOpusVersion();
  }

  @override
  Uint8List encode(Int16List pcmFrame) {
    _ensureOpen();
    if (pcmFrame.length != DiscordPcmFrameAssembler.samplesPerFrame) {
      throw FormatException(
        'Opus PCM frame은 정확히 '
        '${DiscordPcmFrameAssembler.samplesPerFrame} sample이어야 합니다.',
      );
    }
    try {
      return Uint8List.fromList(_encoder.encode(input: pcmFrame));
    } on OpusException catch (error) {
      throw StateError('Opus encode에 실패했습니다: $error');
    }
  }

  @override
  Int16List decode(Uint8List opusPacket, {required String remoteUserId}) {
    _ensureOpen();
    if (opusPacket.isEmpty) {
      throw const FormatException('Opus packet이 비어 있습니다.');
    }
    try {
      return Int16List.fromList(
        _decoderFor(remoteUserId).decode(input: opusPacket),
      );
    } on OpusException catch (error) {
      throw StateError('Opus decode에 실패했습니다: $error');
    }
  }

  @override
  Int16List decodePacketLoss({
    required String remoteUserId,
    int durationMilliseconds = 20,
  }) {
    _ensureOpen();
    if (durationMilliseconds <= 0 || durationMilliseconds > 120) {
      throw const FormatException('Opus packet loss 길이가 올바르지 않습니다.');
    }
    try {
      return Int16List.fromList(
        _decoderFor(remoteUserId).decode(loss: durationMilliseconds),
      );
    } on OpusException catch (error) {
      throw StateError('Opus packet loss concealment에 실패했습니다: $error');
    }
  }

  @override
  void removeRemoteUser(String remoteUserId) {
    _ensureOpen();
    final decoder = _decoders[remoteUserId];
    if (decoder == null) {
      return;
    }
    decoder.destroy();
    _decoders = Map.unmodifiable(
      Map<String, SimpleOpusDecoder>.fromEntries(
        _decoders.entries.where((entry) => entry.key != remoteUserId),
      ),
    );
  }

  @override
  void close() {
    if (_closed) {
      return;
    }
    for (final decoder in _decoders.values) {
      decoder.destroy();
    }
    _decoders = const {};
    _encoder.destroy();
    _closed = true;
  }

  SimpleOpusDecoder _decoderFor(String remoteUserId) {
    if (remoteUserId.isEmpty || int.tryParse(remoteUserId) == null) {
      throw const FormatException('Opus remote user ID는 숫자 snowflake여야 합니다.');
    }
    final existing = _decoders[remoteUserId];
    if (existing != null) {
      return existing;
    }
    final decoder = SimpleOpusDecoder(
      sampleRate: DiscordPcmFrameAssembler.sampleRate,
      channels: DiscordPcmFrameAssembler.channels,
    );
    _decoders = Map.unmodifiable({..._decoders, remoteUserId: decoder});
    return decoder;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('이미 닫힌 Opus codec입니다.');
    }
  }
}
