import 'dart:async';
import 'dart:math';
import 'package:discord_native/features/video/domain/discord_video_protocol.dart';
import 'package:discord_native/features/voice/data/discord_dave_session.dart';
import 'package:discord_native/features/voice/data/discord_voice_rtc_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef DiscordRtcConnectionIdFactory = String Function();
typedef DiscordRtcRenderStreamFactory =
    Future<DiscordRtcRenderStream> Function(int ssrc);

abstract interface class DiscordNativeRtcBridge {
  Stream<DiscordNativeRtcError> get errors;

  Stream<DiscordNativeRtcAudioFrame> get audioFrames;

  Stream<DiscordNativeRtcVideoFrame> get videoFrames;

  Future<String> createSession({
    required String sessionId,
    required DiscordVoiceRtcSession session,
  });

  Future<void> acceptAnswer({
    required String sessionId,
    required String sdp,
    required DiscordVideoCodec videoCodec,
    required int daveEncryptorAddress,
  });

  Future<void> closeSession(String sessionId);

  Future<void> sendAudio({
    required String sessionId,
    required Uint8List frame,
    required int durationMilliseconds,
  });

  Future<void> sendVideo({
    required String sessionId,
    required Uint8List frame,
    required int durationMilliseconds,
  });

  Future<void> renderVideo({
    required String sessionId,
    required String renderStreamId,
    required int ssrc,
    required int timestamp,
    required Uint8List frame,
  });
}

final class DiscordRtcRenderStream {
  DiscordRtcRenderStream({
    required this.streamId,
    required this.preview,
    required Future<void> Function() dispose,
  }) : _dispose = dispose {
    if (streamId.trim().isEmpty) {
      throw const FormatException('WebRTC render stream ID가 비어 있습니다.');
    }
  }

  final String streamId;
  final Object preview;
  final Future<void> Function() _dispose;

  Future<void> dispose() => _dispose();
}

final class DiscordNativeRtcError {
  DiscordNativeRtcError({required this.sessionId, required this.message}) {
    if (sessionId.trim().isEmpty) {
      throw const FormatException('네이티브 WebRTC error session ID가 비어 있습니다.');
    }
    if (message.trim().isEmpty) {
      throw const FormatException('네이티브 WebRTC error message가 비어 있습니다.');
    }
  }

  final String sessionId;
  final String message;
}

final class DiscordNativeRtcAudioFrame {
  DiscordNativeRtcAudioFrame({
    required this.sessionId,
    required this.ssrc,
    required this.sequence,
    required Uint8List encryptedOpus,
  }) : _encryptedOpus = Uint8List.fromList(encryptedOpus) {
    if (sessionId.trim().isEmpty) {
      throw const FormatException('네이티브 WebRTC session ID가 비어 있습니다.');
    }
    if (ssrc < 0 || ssrc > 0xFFFFFFFF) {
      throw const FormatException('네이티브 WebRTC audio SSRC가 올바르지 않습니다.');
    }
    if (sequence < 0 || sequence > 0xFFFF) {
      throw const FormatException('네이티브 WebRTC audio sequence가 올바르지 않습니다.');
    }
    if (encryptedOpus.isEmpty) {
      throw const FormatException('네이티브 WebRTC audio frame이 비어 있습니다.');
    }
  }

  final String sessionId;
  final int ssrc;
  final int sequence;
  final Uint8List _encryptedOpus;

  Uint8List get encryptedOpus => Uint8List.fromList(_encryptedOpus);
}

final class DiscordNativeRtcVideoFrame {
  DiscordNativeRtcVideoFrame({
    required this.sessionId,
    required this.ssrc,
    required this.timestamp,
    required Uint8List encryptedH264,
  }) : _encryptedH264 = Uint8List.fromList(encryptedH264) {
    if (sessionId.trim().isEmpty) {
      throw const FormatException('네이티브 WebRTC session ID가 비어 있습니다.');
    }
    if (ssrc < 0 || ssrc > 0xFFFFFFFF) {
      throw const FormatException('네이티브 WebRTC video SSRC가 올바르지 않습니다.');
    }
    if (timestamp < 0 || timestamp > 0xFFFFFFFF) {
      throw const FormatException('네이티브 WebRTC video timestamp가 올바르지 않습니다.');
    }
    if (encryptedH264.isEmpty) {
      throw const FormatException('네이티브 WebRTC video frame이 비어 있습니다.');
    }
  }

  final String sessionId;
  final int ssrc;
  final int timestamp;
  final Uint8List _encryptedH264;

  Uint8List get encryptedH264 => Uint8List.fromList(_encryptedH264);
}

final class MethodChannelDiscordNativeRtcBridge
    implements DiscordNativeRtcBridge {
  MethodChannelDiscordNativeRtcBridge({
    MethodChannel channel = const MethodChannel('FlutterWebRTC.Method'),
    EventChannel eventChannel = const EventChannel('DiscordNativeRTC.Event'),
  }) : _channel = channel,
       _events = eventChannel.receiveBroadcastStream().asBroadcastStream();

  final MethodChannel _channel;
  final Stream<Object?> _events;

  @override
  Stream<DiscordNativeRtcError> get errors {
    return _events.where(_isErrorEvent).map(_parseErrorEvent);
  }

  @override
  Stream<DiscordNativeRtcAudioFrame> get audioFrames {
    return _events.where(_isAudioFrameEvent).map(_parseAudioFrameEvent);
  }

  @override
  Stream<DiscordNativeRtcVideoFrame> get videoFrames {
    return _events.where(_isVideoFrameEvent).map(_parseVideoFrameEvent);
  }

  @override
  Future<String> createSession({
    required String sessionId,
    required DiscordVoiceRtcSession session,
  }) async {
    try {
      final source = session.source;
      final sdp = await _channel
          .invokeMethod<String>('discordVideoCreateSession', {
            'sessionId': sessionId,
            'audioSsrc': session.audioSsrc,
            'videoSsrc': session.videoSsrc,
            'rtxSsrc': session.rtxSsrc,
            'sourceKind': source?.kind.name ?? 'receive',
            'sourceId': source?.sourceId ?? 'discord-receive',
            'width': source?.width ?? 2,
            'height': source?.height ?? 2,
            'framesPerSecond': source?.framesPerSecond ?? 30,
          });
      if (sdp == null || sdp.trim().isEmpty) {
        throw const FormatException('네이티브 WebRTC offer가 비어 있습니다.');
      }
      return sdp;
    } on PlatformException catch (error) {
      throw StateError(_platformError('WebRTC session 생성', error));
    }
  }

  @override
  Future<void> acceptAnswer({
    required String sessionId,
    required String sdp,
    required DiscordVideoCodec videoCodec,
    required int daveEncryptorAddress,
  }) async {
    try {
      await _channel.invokeMethod<void>('discordVideoAcceptAnswer', {
        'sessionId': sessionId,
        'sdp': sdp,
        'videoCodec': videoCodec.gatewayName,
        'daveEncryptorAddress': daveEncryptorAddress,
      });
    } on PlatformException catch (error) {
      throw StateError(_platformError('WebRTC answer 적용', error));
    }
  }

  @override
  Future<void> closeSession(String sessionId) async {
    try {
      await _channel.invokeMethod<void>('discordVideoCloseSession', {
        'sessionId': sessionId,
      });
    } on PlatformException catch (error) {
      throw StateError(_platformError('WebRTC session 종료', error));
    }
  }

  @override
  Future<void> sendAudio({
    required String sessionId,
    required Uint8List frame,
    required int durationMilliseconds,
  }) async {
    try {
      await _channel.invokeMethod<void>('discordVideoSendAudio', {
        'sessionId': sessionId,
        'frame': Uint8List.fromList(frame),
        'durationMilliseconds': durationMilliseconds,
      });
    } on PlatformException catch (error) {
      throw StateError(_platformError('WebRTC audio 전송', error));
    }
  }

  @override
  Future<void> sendVideo({
    required String sessionId,
    required Uint8List frame,
    required int durationMilliseconds,
  }) async {
    try {
      await _channel.invokeMethod<void>('discordVideoSendFrame', {
        'sessionId': sessionId,
        'frame': Uint8List.fromList(frame),
        'durationMilliseconds': durationMilliseconds,
      });
    } on PlatformException catch (error) {
      throw StateError(_platformError('WebRTC video 전송', error));
    }
  }

  @override
  Future<void> renderVideo({
    required String sessionId,
    required String renderStreamId,
    required int ssrc,
    required int timestamp,
    required Uint8List frame,
  }) async {
    try {
      await _channel.invokeMethod<void>('discordVideoRenderFrame', {
        'sessionId': sessionId,
        'renderStreamId': renderStreamId,
        'ssrc': ssrc,
        'timestamp': timestamp,
        'frame': Uint8List.fromList(frame),
      });
    } on PlatformException catch (error) {
      throw StateError(_platformError('WebRTC video render', error));
    }
  }
}

final class NativeDiscordVoiceRtcTransport
    implements DiscordVoiceRtcMediaTransport {
  NativeDiscordVoiceRtcTransport({
    DiscordNativeRtcBridge? bridge,
    DiscordRtcConnectionIdFactory? rtcConnectionIdFactory,
    DiscordRtcRenderStreamFactory? renderStreamFactory,
  }) : _bridge = bridge ?? MethodChannelDiscordNativeRtcBridge(),
       _rtcConnectionIdFactory =
           rtcConnectionIdFactory ?? _secureRtcConnectionId,
       _renderStreamFactory =
           renderStreamFactory ?? _createFlutterRtcRenderStream;

  final DiscordNativeRtcBridge _bridge;
  final DiscordRtcConnectionIdFactory _rtcConnectionIdFactory;
  final DiscordRtcRenderStreamFactory _renderStreamFactory;
  final StreamController<DiscordVoiceRtcVideoStream> _videoStreams =
      StreamController.broadcast();
  final Map<int, DiscordRtcRenderStream> _renderStreams = {};
  String? _activeSessionId;
  bool _answerAccepted = false;

  @override
  Stream<String> get errors {
    return _bridge.errors
        .where((error) => error.sessionId == _activeSessionId)
        .map((error) => error.message);
  }

  @override
  Stream<DiscordVoiceRtcAudioFrame> get audioFrames {
    return _bridge.audioFrames
        .where((frame) => frame.sessionId == _activeSessionId)
        .map(
          (frame) => DiscordVoiceRtcAudioFrame(
            ssrc: frame.ssrc,
            sequence: frame.sequence,
            encryptedOpus: frame.encryptedOpus,
          ),
        );
  }

  @override
  Stream<DiscordVoiceRtcVideoFrame> get videoFrames {
    return _bridge.videoFrames
        .where((frame) => frame.sessionId == _activeSessionId)
        .map(
          (frame) => DiscordVoiceRtcVideoFrame(
            ssrc: frame.ssrc,
            timestamp: frame.timestamp,
            encryptedH264: frame.encryptedH264,
          ),
        );
  }

  @override
  Stream<DiscordVoiceRtcVideoStream> get videoStreams => _videoStreams.stream;

  @override
  Future<DiscordVoiceRtcOffer> createOffer(
    DiscordVoiceRtcSession session,
  ) async {
    if (_activeSessionId != null) {
      throw StateError('WebRTC video session이 이미 활성 상태입니다.');
    }
    final sessionId = _rtcConnectionIdFactory().trim();
    if (sessionId.isEmpty) {
      throw const FormatException('WebRTC connection ID가 비어 있습니다.');
    }
    final sdp = await _bridge.createSession(
      sessionId: sessionId,
      session: session,
    );
    _activeSessionId = sessionId;
    return DiscordVoiceRtcOffer(sdp: sdp, rtcConnectionId: sessionId);
  }

  @override
  Future<void> acceptAnswer(DiscordVoiceRtcAnswer answer) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) {
      throw StateError('적용할 WebRTC video session이 없습니다.');
    }
    if (answer.audioCodec.trim().toLowerCase() != 'opus') {
      throw FormatException(
        '지원하지 않는 Discord audio codec입니다: ${answer.audioCodec}',
      );
    }
    final daveSession = answer.daveSession;
    if (daveSession is! DiscordDaveNativeHandles) {
      throw StateError('네이티브 DAVE encryptor handle을 사용할 수 없습니다.');
    }
    final nativeHandles = daveSession as DiscordDaveNativeHandles;
    final normalizedSdp = DiscordRtcSdpNormalizer.normalizeAnswer(answer.sdp);
    await _bridge.acceptAnswer(
      sessionId: sessionId,
      sdp: normalizedSdp,
      videoCodec: answer.videoCodec,
      daveEncryptorAddress: nativeHandles.nativeEncryptorAddress,
    );
    _answerAccepted = true;
  }

  @override
  Future<void> sendAudio(
    Uint8List opusFrame, {
    int durationMilliseconds = 20,
  }) async {
    final sessionId = _activeSessionId;
    if (sessionId == null || !_answerAccepted) {
      throw StateError('WebRTC audio session이 준비되지 않았습니다.');
    }
    if (opusFrame.isEmpty) {
      throw const FormatException('전송할 Opus frame이 비어 있습니다.');
    }
    if (durationMilliseconds < 1 || durationMilliseconds > 60) {
      throw const FormatException('Opus frame duration 범위가 올바르지 않습니다.');
    }
    await _bridge.sendAudio(
      sessionId: sessionId,
      frame: Uint8List.fromList(opusFrame),
      durationMilliseconds: durationMilliseconds,
    );
  }

  @override
  Future<void> sendVideo(
    Uint8List h264AccessUnit, {
    required int durationMilliseconds,
  }) async {
    final sessionId = _activeSessionId;
    if (sessionId == null || !_answerAccepted) {
      throw StateError('WebRTC video session이 준비되지 않았습니다.');
    }
    if (!_hasAnnexBStartCode(h264AccessUnit)) {
      throw const FormatException('H264 access unit이 Annex B 형식이 아닙니다.');
    }
    if (durationMilliseconds < 1 || durationMilliseconds > 1000) {
      throw const FormatException('H264 frame duration 범위가 올바르지 않습니다.');
    }
    await _bridge.sendVideo(
      sessionId: sessionId,
      frame: Uint8List.fromList(h264AccessUnit),
      durationMilliseconds: durationMilliseconds,
    );
  }

  @override
  Future<void> renderVideo(
    Uint8List h264AccessUnit, {
    required int ssrc,
    required int timestamp,
  }) async {
    final sessionId = _activeSessionId;
    if (sessionId == null || !_answerAccepted) {
      throw StateError('WebRTC video render session이 준비되지 않았습니다.');
    }
    if (ssrc < 0 ||
        ssrc > 0xFFFFFFFF ||
        timestamp < 0 ||
        timestamp > 0xFFFFFFFF) {
      throw const FormatException('WebRTC video render RTP 정보가 올바르지 않습니다.');
    }
    if (!_hasAnnexBStartCode(h264AccessUnit)) {
      throw const FormatException('Render H264 access unit이 Annex B 형식이 아닙니다.');
    }
    final existing = _renderStreams[ssrc];
    final stream = existing ?? await _renderStreamFactory(ssrc);
    try {
      await _bridge.renderVideo(
        sessionId: sessionId,
        renderStreamId: stream.streamId,
        ssrc: ssrc,
        timestamp: timestamp,
        frame: Uint8List.fromList(h264AccessUnit),
      );
    } on Object {
      if (existing == null) {
        await stream.dispose();
      }
      rethrow;
    }
    if (existing == null) {
      _renderStreams[ssrc] = stream;
      if (!_videoStreams.isClosed) {
        _videoStreams.add(
          DiscordVoiceRtcVideoStream(ssrc: ssrc, preview: stream.preview),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    final sessionId = _activeSessionId;
    if (sessionId == null) {
      return;
    }
    try {
      await _bridge.closeSession(sessionId);
    } finally {
      _activeSessionId = null;
      _answerAccepted = false;
      final streams = List<DiscordRtcRenderStream>.of(_renderStreams.values);
      _renderStreams.clear();
      for (final stream in streams) {
        await stream.dispose();
      }
    }
  }
}

Future<DiscordRtcRenderStream> _createFlutterRtcRenderStream(int ssrc) async {
  final stream = await createLocalMediaStream('discord-remote-video-$ssrc');
  return DiscordRtcRenderStream(
    streamId: stream.id,
    preview: stream,
    dispose: stream.dispose,
  );
}

bool _isAudioFrameEvent(Object? event) {
  return event is Map && event['event'] == 'discordAudioFrame';
}

bool _isVideoFrameEvent(Object? event) {
  return event is Map && event['event'] == 'discordVideoFrame';
}

bool _isErrorEvent(Object? event) {
  return event is Map && event['event'] == 'discordVideoError';
}

DiscordNativeRtcError _parseErrorEvent(Object? event) {
  if (event is! Map) {
    throw const FormatException('네이티브 WebRTC error event 형식이 올바르지 않습니다.');
  }
  final sessionId = event['sessionId'];
  final message = event['message'];
  if (sessionId is! String || message is! String) {
    throw const FormatException('네이티브 WebRTC error event가 올바르지 않습니다.');
  }
  return DiscordNativeRtcError(sessionId: sessionId, message: message);
}

DiscordNativeRtcAudioFrame _parseAudioFrameEvent(Object? event) {
  if (event is! Map) {
    throw const FormatException('네이티브 WebRTC event 형식이 올바르지 않습니다.');
  }
  final sessionId = event['sessionId'];
  final ssrc = event['ssrc'];
  final sequence = event['sequence'];
  final frame = event['frame'];
  if (sessionId is! String ||
      ssrc is! int ||
      sequence is! int ||
      frame is! Uint8List) {
    throw const FormatException('네이티브 WebRTC audio event가 올바르지 않습니다.');
  }
  return DiscordNativeRtcAudioFrame(
    sessionId: sessionId,
    ssrc: ssrc,
    sequence: sequence,
    encryptedOpus: frame,
  );
}

DiscordNativeRtcVideoFrame _parseVideoFrameEvent(Object? event) {
  if (event is! Map) {
    throw const FormatException('네이티브 WebRTC event 형식이 올바르지 않습니다.');
  }
  final sessionId = event['sessionId'];
  final ssrc = event['ssrc'];
  final timestamp = event['timestamp'];
  final frame = event['frame'];
  if (sessionId is! String ||
      ssrc is! int ||
      timestamp is! int ||
      frame is! Uint8List) {
    throw const FormatException('네이티브 WebRTC video event가 올바르지 않습니다.');
  }
  return DiscordNativeRtcVideoFrame(
    sessionId: sessionId,
    ssrc: ssrc,
    timestamp: timestamp,
    encryptedH264: frame,
  );
}

bool _hasAnnexBStartCode(Uint8List frame) {
  if (frame.length < 4 || frame[0] != 0 || frame[1] != 0) {
    return false;
  }
  return frame[2] == 1 || (frame.length >= 5 && frame[2] == 0 && frame[3] == 1);
}

abstract final class DiscordRtcSdpNormalizer {
  static String normalizeAnswer(String sdp) {
    final lines = sdp
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final connection = _requiredLine(lines, 'c=');
    final rtcp = _requiredLine(lines, 'a=rtcp:');
    final port = rtcp.substring('a=rtcp:'.length).split(' ').first;
    if (int.tryParse(port) == null) {
      throw const FormatException('Discord WebRTC RTCP port가 올바르지 않습니다.');
    }
    final shared = [
      _requiredLine(lines, 'a=ice-ufrag:'),
      _requiredLine(lines, 'a=ice-pwd:'),
      _requiredLine(lines, 'a=fingerprint:'),
      _requiredLine(lines, 'a=candidate:'),
    ];
    return [
      ..._audioAnswer(port, connection, shared),
      ..._videoAnswer(port, connection, shared),
      '',
    ].join('\r\n');
  }
}

List<String> _audioAnswer(String port, String connection, List<String> shared) {
  return [
    'm=audio $port UDP/TLS/RTP/SAVPF 120',
    connection,
    'a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level',
    'a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01',
    'a=setup:passive',
    'a=mid:0',
    'a=maxptime:60',
    'a=inactive',
    ...shared,
    'a=rtcp-mux',
    'a=rtpmap:120 opus/48000/2',
    'a=fmtp:120 minptime=10;useinbandfec=1;usedtx=1',
    'a=rtcp-fb:120 transport-cc',
    'a=rtcp-fb:120 nack',
    'a=ice-lite',
  ];
}

List<String> _videoAnswer(String port, String connection, List<String> shared) {
  return [
    'm=video $port UDP/TLS/RTP/SAVPF 101 102',
    connection,
    'a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time',
    'a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01',
    'a=extmap:14 urn:ietf:params:rtp-hdrext:toffset',
    'a=extmap:13 urn:3gpp:video-orientation',
    'a=extmap:5 http://www.webrtc.org/experiments/rtp-hdrext/playout-delay',
    'a=setup:passive',
    'a=mid:1',
    'a=inactive',
    ...shared,
    'a=rtcp-mux',
    'a=ice-lite',
    'a=rtpmap:101 H264/90000',
    'a=rtpmap:102 rtx/90000',
    'a=fmtp:102 apt=101',
    'a=rtcp-fb:101 ccm fir',
    'a=rtcp-fb:101 nack',
    'a=rtcp-fb:101 nack pli',
    'a=rtcp-fb:101 goog-remb',
    'a=rtcp-fb:101 transport-cc',
  ];
}

String _requiredLine(List<String> lines, String prefix) {
  for (final line in lines) {
    if (line.startsWith(prefix)) {
      return line;
    }
  }
  throw FormatException('Discord WebRTC SDP에 $prefix 필드가 없습니다.');
}

String _platformError(String operation, PlatformException error) {
  final detail = error.message?.trim();
  return detail == null || detail.isEmpty
      ? '$operation 작업에 실패했습니다.'
      : '$operation 작업에 실패했습니다: $detail';
}

String _secureRtcConnectionId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
