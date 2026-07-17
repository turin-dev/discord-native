import 'dart:async';
import 'dart:typed_data';

import 'package:discord_native/features/video/data/native_discord_voice_rtc_transport.dart';
import 'package:discord_native/features/video/domain/discord_video_protocol.dart';
import 'package:discord_native/features/voice/data/discord_dave_session.dart';
import 'package:discord_native/features/voice/data/discord_voice_rtc_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = DiscordVideoSource.camera(
    sourceId: 'camera-1',
    width: 1280,
    height: 720,
    framesPerSecond: 30,
  );
  const session = DiscordVoiceRtcSession(
    audioSsrc: 11,
    videoSsrc: 22,
    rtxSsrc: 23,
    source: source,
  );

  test('네이티브 세션을 만들고 고정된 connection ID로 offer를 반환한다', () async {
    final bridge = _FakeNativeRtcBridge(localSdp: 'local-sdp');
    final transport = NativeDiscordVoiceRtcTransport(
      bridge: bridge,
      rtcConnectionIdFactory: () => 'rtc-connection-1',
    );

    final offer = await transport.createOffer(session);

    expect(offer.sdp, 'local-sdp');
    expect(offer.rtcConnectionId, 'rtc-connection-1');
    expect(bridge.createdSessions, [
      const _CreatedSession('rtc-connection-1', session),
    ]);
  });

  test('Discord SDP를 정규화하고 DAVE encryptor handle과 함께 적용한다', () async {
    final bridge = _FakeNativeRtcBridge(localSdp: 'local-sdp');
    final transport = NativeDiscordVoiceRtcTransport(
      bridge: bridge,
      rtcConnectionIdFactory: () => 'rtc-connection-1',
    );
    await transport.createOffer(session);

    await transport.acceptAnswer(
      DiscordVoiceRtcAnswer(
        sdp: _discordAnswer,
        audioCodec: 'opus',
        videoCodec: DiscordVideoCodec.h264,
        daveSession: _FakeNativeDaveSession(0x1234),
      ),
    );

    final applied = bridge.appliedAnswers.single;
    expect(applied.sessionId, 'rtc-connection-1');
    expect(applied.daveEncryptorAddress, 0x1234);
    expect(applied.sdp, contains('m=audio 50000 UDP/TLS/RTP/SAVPF 120'));
    expect(applied.sdp, contains('m=video 50000 UDP/TLS/RTP/SAVPF 101 102'));
    expect(applied.sdp, contains('a=rtpmap:101 H264/90000'));
    expect(applied.sdp, contains('a=fmtp:102 apt=101'));
    expect(applied.sdp, contains('a=ice-lite'));
  });

  test('네이티브 DAVE handle이 없는 session은 answer 적용 전에 거부한다', () async {
    final bridge = _FakeNativeRtcBridge(localSdp: 'local-sdp');
    final transport = NativeDiscordVoiceRtcTransport(
      bridge: bridge,
      rtcConnectionIdFactory: () => 'rtc-connection-1',
    );
    await transport.createOffer(session);

    expect(
      () => transport.acceptAnswer(
        DiscordVoiceRtcAnswer(
          sdp: _discordAnswer,
          audioCodec: 'opus',
          videoCodec: DiscordVideoCodec.h264,
          daveSession: _FakeDaveSession(),
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(bridge.appliedAnswers, isEmpty);
  });

  test('close는 활성 네이티브 세션을 한 번만 닫고 재사용을 허용한다', () async {
    var nextId = 0;
    final bridge = _FakeNativeRtcBridge(localSdp: 'local-sdp');
    final transport = NativeDiscordVoiceRtcTransport(
      bridge: bridge,
      rtcConnectionIdFactory: () => 'rtc-${nextId++}',
    );
    await transport.createOffer(session);

    await transport.close();
    await transport.close();
    final nextOffer = await transport.createOffer(session);

    expect(bridge.closedSessionIds, ['rtc-0']);
    expect(nextOffer.rtcConnectionId, 'rtc-1');
  });

  test('필수 ICE answer 필드가 없으면 명확한 형식 오류를 반환한다', () {
    expect(
      () => DiscordRtcSdpNormalizer.normalizeAnswer('a=ice-ufrag:user'),
      throwsA(isA<FormatException>()),
    );
  });

  test('활성 WebRTC session으로 Opus frame을 명시적 duration과 전송한다', () async {
    final bridge = _FakeNativeRtcBridge(localSdp: 'local-sdp');
    final transport = NativeDiscordVoiceRtcTransport(
      bridge: bridge,
      rtcConnectionIdFactory: () => 'rtc-connection-1',
    );
    await transport.createOffer(session);
    await transport.acceptAnswer(
      DiscordVoiceRtcAnswer(
        sdp: _discordAnswer,
        audioCodec: 'opus',
        videoCodec: DiscordVideoCodec.h264,
        daveSession: _FakeNativeDaveSession(0x1234),
      ),
    );

    await transport.sendAudio(
      Uint8List.fromList([0x11, 0x22]),
      durationMilliseconds: 20,
    );

    expect(bridge.sentAudio, [
      const _SentAudio('rtc-connection-1', [0x11, 0x22], 20),
    ]);
  });

  test('현재 session의 수신 WebRTC audio frame만 불변 복사해 노출한다', () async {
    final bridge = _FakeNativeRtcBridge(localSdp: 'local-sdp');
    final transport = NativeDiscordVoiceRtcTransport(
      bridge: bridge,
      rtcConnectionIdFactory: () => 'rtc-connection-1',
    );
    await transport.createOffer(session);
    final received = transport.audioFrames.first;

    bridge.emitAudio(
      DiscordNativeRtcAudioFrame(
        sessionId: 'other-session',
        ssrc: 7,
        sequence: 8,
        encryptedOpus: Uint8List.fromList([1]),
      ),
    );
    final source = Uint8List.fromList([2, 3]);
    bridge.emitAudio(
      DiscordNativeRtcAudioFrame(
        sessionId: 'rtc-connection-1',
        ssrc: 5150,
        sequence: 9,
        encryptedOpus: source,
      ),
    );
    source[0] = 99;

    final frame = await received;
    expect(frame.ssrc, 5150);
    expect(frame.sequence, 9);
    expect(frame.encryptedOpus, [2, 3]);
  });

  test('H264 access unit을 활성 WebRTC session으로 전송한다', () async {
    final bridge = _FakeNativeRtcBridge(localSdp: 'local-sdp');
    final transport = NativeDiscordVoiceRtcTransport(
      bridge: bridge,
      rtcConnectionIdFactory: () => 'rtc-connection-1',
    );
    await transport.createOffer(session);
    await transport.acceptAnswer(
      DiscordVoiceRtcAnswer(
        sdp: _discordAnswer,
        audioCodec: 'opus',
        videoCodec: DiscordVideoCodec.h264,
        daveSession: _FakeNativeDaveSession(0x1234),
      ),
    );

    await transport.sendVideo(
      Uint8List.fromList([0, 0, 0, 1, 0x65, 0x01]),
      durationMilliseconds: 33,
    );

    expect(bridge.sentVideo, [
      const _SentVideo('rtc-connection-1', [0, 0, 0, 1, 0x65, 0x01], 33),
    ]);
  });

  test('현재 session의 수신 DAVE H264 access unit만 노출한다', () async {
    final bridge = _FakeNativeRtcBridge(localSdp: 'local-sdp');
    final transport = NativeDiscordVoiceRtcTransport(
      bridge: bridge,
      rtcConnectionIdFactory: () => 'rtc-connection-1',
    );
    await transport.createOffer(session);
    final received = transport.videoFrames.first;

    bridge.emitVideo(
      DiscordNativeRtcVideoFrame(
        sessionId: 'other-session',
        ssrc: 20,
        timestamp: 100,
        encryptedH264: Uint8List.fromList([0, 0, 0, 1, 1]),
      ),
    );
    final source = Uint8List.fromList([0, 0, 0, 1, 0x65]);
    bridge.emitVideo(
      DiscordNativeRtcVideoFrame(
        sessionId: 'rtc-connection-1',
        ssrc: 21,
        timestamp: 200,
        encryptedH264: source,
      ),
    );
    source[4] = 1;

    final frame = await received;
    expect(frame.ssrc, 21);
    expect(frame.timestamp, 200);
    expect(frame.encryptedH264, [0, 0, 0, 1, 0x65]);
  });

  test('현재 session의 네이티브 encoder 오류만 노출한다', () async {
    final bridge = _FakeNativeRtcBridge(localSdp: 'local-sdp');
    final transport = NativeDiscordVoiceRtcTransport(
      bridge: bridge,
      rtcConnectionIdFactory: () => 'rtc-connection-1',
    );
    await transport.createOffer(session);
    final received = transport.errors.first;

    bridge.emitError(
      DiscordNativeRtcError(sessionId: 'other-session', message: 'ignored'),
    );
    bridge.emitError(
      DiscordNativeRtcError(
        sessionId: 'rtc-connection-1',
        message: 'H264 encoder failed',
      ),
    );

    expect(await received, 'H264 encoder failed');
  });

  test('복호화한 H264 frame을 SSRC별 render stream으로 재사용한다', () async {
    final bridge = _FakeNativeRtcBridge(localSdp: 'local-sdp');
    final preview = Object();
    var streamCreateCount = 0;
    final transport = NativeDiscordVoiceRtcTransport(
      bridge: bridge,
      rtcConnectionIdFactory: () => 'rtc-connection-1',
      renderStreamFactory: (ssrc) async {
        streamCreateCount += 1;
        return DiscordRtcRenderStream(
          streamId: 'render-$ssrc',
          preview: preview,
          dispose: () async {},
        );
      },
    );
    await transport.createOffer(session);
    await transport.acceptAnswer(
      DiscordVoiceRtcAnswer(
        sdp: _discordAnswer,
        audioCodec: 'opus',
        videoCodec: DiscordVideoCodec.h264,
        daveSession: _FakeNativeDaveSession(0x1234),
      ),
    );
    final streamReceived = transport.videoStreams.first;

    await transport.renderVideo(
      Uint8List.fromList([0, 0, 0, 1, 0x65]),
      ssrc: 5150,
      timestamp: 90000,
    );
    await transport.renderVideo(
      Uint8List.fromList([0, 0, 0, 1, 0x41]),
      ssrc: 5150,
      timestamp: 93000,
    );

    final stream = await streamReceived;
    expect(stream.ssrc, 5150);
    expect(stream.preview, same(preview));
    expect(streamCreateCount, 1);
    expect(bridge.renderedVideo, [
      const _RenderedVideo('rtc-connection-1', 'render-5150', 5150, 90000, [
        0,
        0,
        0,
        1,
        0x65,
      ]),
      const _RenderedVideo('rtc-connection-1', 'render-5150', 5150, 93000, [
        0,
        0,
        0,
        1,
        0x41,
      ]),
    ]);
  });
}

const _discordAnswer = '''
v=0
o=- 1 1 IN IP4 203.0.113.1
s=-
t=0 0
m=audio 50000 UDP/TLS/RTP/SAVPF 120
c=IN IP4 203.0.113.1
a=rtcp:50000
a=ice-ufrag:user
a=ice-pwd:password
a=fingerprint:sha-256 00:11:22:33
a=candidate:1 1 UDP 1 203.0.113.1 50000 typ host
''';

final class _FakeNativeRtcBridge implements DiscordNativeRtcBridge {
  _FakeNativeRtcBridge({required this.localSdp});

  final String localSdp;
  final List<_CreatedSession> createdSessions = [];
  final List<_AppliedAnswer> appliedAnswers = [];
  final List<String> closedSessionIds = [];
  final List<_SentAudio> sentAudio = [];
  final List<_SentVideo> sentVideo = [];
  final List<_RenderedVideo> renderedVideo = [];
  final StreamController<DiscordNativeRtcAudioFrame> _audioFrames =
      StreamController.broadcast(sync: true);
  final StreamController<DiscordNativeRtcVideoFrame> _videoFrames =
      StreamController.broadcast(sync: true);
  final StreamController<DiscordNativeRtcError> _errors =
      StreamController.broadcast(sync: true);

  @override
  Stream<DiscordNativeRtcAudioFrame> get audioFrames => _audioFrames.stream;

  @override
  Stream<DiscordNativeRtcVideoFrame> get videoFrames => _videoFrames.stream;

  @override
  Stream<DiscordNativeRtcError> get errors => _errors.stream;

  void emitAudio(DiscordNativeRtcAudioFrame frame) => _audioFrames.add(frame);

  void emitVideo(DiscordNativeRtcVideoFrame frame) => _videoFrames.add(frame);

  void emitError(DiscordNativeRtcError error) => _errors.add(error);

  @override
  Future<String> createSession({
    required String sessionId,
    required DiscordVoiceRtcSession session,
  }) async {
    createdSessions.add(_CreatedSession(sessionId, session));
    return localSdp;
  }

  @override
  Future<void> acceptAnswer({
    required String sessionId,
    required String sdp,
    required DiscordVideoCodec videoCodec,
    required int daveEncryptorAddress,
  }) async {
    appliedAnswers.add(
      _AppliedAnswer(sessionId, sdp, videoCodec, daveEncryptorAddress),
    );
  }

  @override
  Future<void> closeSession(String sessionId) async {
    closedSessionIds.add(sessionId);
  }

  @override
  Future<void> sendAudio({
    required String sessionId,
    required Uint8List frame,
    required int durationMilliseconds,
  }) async {
    sentAudio.add(
      _SentAudio(
        sessionId,
        List<int>.unmodifiable(frame),
        durationMilliseconds,
      ),
    );
  }

  @override
  Future<void> sendVideo({
    required String sessionId,
    required Uint8List frame,
    required int durationMilliseconds,
  }) async {
    sentVideo.add(
      _SentVideo(
        sessionId,
        List<int>.unmodifiable(frame),
        durationMilliseconds,
      ),
    );
  }

  @override
  Future<void> renderVideo({
    required String sessionId,
    required String renderStreamId,
    required int ssrc,
    required int timestamp,
    required Uint8List frame,
  }) async {
    renderedVideo.add(
      _RenderedVideo(
        sessionId,
        renderStreamId,
        ssrc,
        timestamp,
        List<int>.unmodifiable(frame),
      ),
    );
  }
}

final class _CreatedSession {
  const _CreatedSession(this.sessionId, this.session);

  final String sessionId;
  final DiscordVoiceRtcSession session;

  @override
  bool operator ==(Object other) {
    return other is _CreatedSession &&
        sessionId == other.sessionId &&
        session == other.session;
  }

  @override
  int get hashCode => Object.hash(sessionId, session);
}

final class _AppliedAnswer {
  const _AppliedAnswer(
    this.sessionId,
    this.sdp,
    this.videoCodec,
    this.daveEncryptorAddress,
  );

  final String sessionId;
  final String sdp;
  final DiscordVideoCodec videoCodec;
  final int daveEncryptorAddress;
}

final class _SentAudio {
  const _SentAudio(this.sessionId, this.frame, this.durationMilliseconds);

  final String sessionId;
  final List<int> frame;
  final int durationMilliseconds;

  @override
  bool operator ==(Object other) {
    return other is _SentAudio &&
        sessionId == other.sessionId &&
        durationMilliseconds == other.durationMilliseconds &&
        _sameBytes(frame, other.frame);
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, durationMilliseconds, Object.hashAll(frame));
}

final class _SentVideo {
  const _SentVideo(this.sessionId, this.frame, this.durationMilliseconds);

  final String sessionId;
  final List<int> frame;
  final int durationMilliseconds;

  @override
  bool operator ==(Object other) {
    return other is _SentVideo &&
        sessionId == other.sessionId &&
        durationMilliseconds == other.durationMilliseconds &&
        _sameBytes(frame, other.frame);
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, durationMilliseconds, Object.hashAll(frame));
}

final class _RenderedVideo {
  const _RenderedVideo(
    this.sessionId,
    this.renderStreamId,
    this.ssrc,
    this.timestamp,
    this.frame,
  );

  final String sessionId;
  final String renderStreamId;
  final int ssrc;
  final int timestamp;
  final List<int> frame;

  @override
  bool operator ==(Object other) {
    return other is _RenderedVideo &&
        sessionId == other.sessionId &&
        renderStreamId == other.renderStreamId &&
        ssrc == other.ssrc &&
        timestamp == other.timestamp &&
        _sameBytes(frame, other.frame);
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    renderStreamId,
    ssrc,
    timestamp,
    Object.hashAll(frame),
  );
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

class _FakeDaveSession implements DiscordDaveSession {
  @override
  int get maxSupportedProtocolVersion => 1;

  @override
  int get protocolVersion => 1;

  @override
  void assignLocalAudioSsrc(int ssrc) {}

  @override
  void assignLocalVideoSsrc(int ssrc, {required DiscordDaveVideoCodec codec}) {}

  @override
  void close() {}

  @override
  Uint8List createKeyPackage() => Uint8List(0);

  @override
  Uint8List decryptAudio(Uint8List frame, {required String remoteUserId}) {
    return frame;
  }

  @override
  Uint8List decryptVideo(Uint8List frame, {required String remoteUserId}) {
    return frame;
  }

  @override
  Uint8List encryptAudio(Uint8List frame, {required int ssrc}) => frame;

  @override
  Uint8List encryptVideo(Uint8List frame, {required int ssrc}) => frame;

  @override
  void initialize({
    required int protocolVersion,
    required int groupId,
    required String selfUserId,
  }) {}

  @override
  DiscordDaveGroupUpdate processCommit(Uint8List payload) {
    return DiscordDaveGroupUpdate.applied;
  }

  @override
  Uint8List? processProposals(
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  }) {
    return null;
  }

  @override
  DiscordDaveGroupUpdate processWelcome(
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  }) {
    return DiscordDaveGroupUpdate.applied;
  }

  @override
  void setExternalSender(Uint8List payload) {}

  @override
  void setPassthroughMode({
    required bool enabled,
    required Iterable<String> remoteUserIds,
  }) {}
}

final class _FakeNativeDaveSession extends _FakeDaveSession
    implements DiscordDaveNativeHandles {
  _FakeNativeDaveSession(this.nativeEncryptorAddress);

  @override
  final int nativeEncryptorAddress;
}
