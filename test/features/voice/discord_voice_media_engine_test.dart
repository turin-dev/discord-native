import 'dart:async';
import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_opus_codec.dart';
import 'package:discord_native/features/voice/data/discord_pcm_frame_assembler.dart';
import 'package:discord_native/features/voice/data/discord_voice_gateway_client.dart';
import 'package:discord_native/features/voice/data/discord_voice_media_engine.dart';
import 'package:discord_native/features/voice/data/discord_voice_rtp_codec.dart';
import 'package:discord_native/features/voice/data/record_discord_microphone_capture.dart';
import 'package:discord_native/features/voice/data/soloud_discord_voice_playback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordVoiceMediaEngine', () {
    late _FakeVoiceMediaNetwork network;
    late _FakeMicrophoneCapture microphone;
    late _FakeOpusCodec opus;
    late _FakeVoicePlayback playback;
    late DiscordVoiceMediaEngine engine;

    setUp(() {
      network = _FakeVoiceMediaNetwork();
      microphone = _FakeMicrophoneCapture();
      opus = _FakeOpusCodec();
      playback = _FakeVoicePlayback();
      engine = DiscordVoiceMediaEngine(
        network: network,
        microphone: microphone,
        opus: opus,
        playback: playback,
        initialSequence: 65535,
        initialTimestamp: 0xFFFFFF00,
        initialNonce: 0xFFFFFFFF,
      );
    });

    tearDown(() async {
      await engine.dispose();
      await network.dispose();
      await microphone.disposeController();
    });

    test('PCM 20ms frame을 Opus, DAVE, RTP AEAD 순서로 UDP 전송한다', () async {
      await engine.start();
      microphone.add(_pcmBytes(DiscordPcmFrameAssembler.samplesPerFrame));
      await engine.waitForPendingWork();

      expect(network.events.take(2), ['speaking:true', 'udp']);
      expect(network.sentPackets, hasLength(1));
      expect(opus.encodedFrames, hasLength(1));

      final decoded = await DiscordVoiceRtpCodec(
        mode: network.session.encryptionMode,
        secretKey: network.session.secretKey,
      ).decryptAudio(network.sentPackets.single);

      expect(decoded.opusFrame, [0xDA, 0x11, 0x22]);
      expect(decoded.sequence, 65535);
      expect(decoded.timestamp, 0xFFFFFF00);
      expect(decoded.ssrc, 4242);
      expect(decoded.nonceCounter, 0xFFFFFFFF);

      microphone.add(_pcmBytes(DiscordPcmFrameAssembler.samplesPerFrame));
      await engine.waitForPendingWork();
      final wrapped = await DiscordVoiceRtpCodec(
        mode: network.session.encryptionMode,
        secretKey: network.session.secretKey,
      ).decryptAudio(network.sentPackets.last);

      expect(wrapped.sequence, 0);
      expect(wrapped.timestamp, 704);
      expect(wrapped.nonceCounter, 0);
    });

    test('수신 RTP를 SSRC 사용자별 DAVE와 Opus로 해제해 재생한다', () async {
      network.replaceUsers({5150: '400000000000000004'});
      await engine.start();
      final encoder = DiscordVoiceRtpCodec(
        mode: network.session.encryptionMode,
        secretKey: network.session.secretKey,
      );
      network.addPacket(
        await encoder.encryptAudio(
          opusFrame: Uint8List.fromList([0xDA, 0x31]),
          sequence: 10,
          timestamp: 9600,
          ssrc: 5150,
          nonceCounter: 9,
        ),
      );
      await engine.waitForPendingWork();

      expect(network.unprotectedUsers, ['400000000000000004']);
      expect(opus.decodedUsers, ['400000000000000004']);
      expect(playback.playedUsers, ['400000000000000004']);
      expect(playback.playedPcm.single, Int16List.fromList([31, 32]));

      network.addPacket(
        await encoder.encryptAudio(
          opusFrame: Uint8List.fromList([0xDA, 0x32]),
          sequence: 12,
          timestamp: 11520,
          ssrc: 5150,
          nonceCounter: 10,
        ),
      );
      await engine.waitForPendingWork();

      expect(opus.packetLossUsers, ['400000000000000004']);
      expect(playback.playedPcm[1], Int16List.fromList([-1, -1]));
      expect(playback.playedPcm[2], Int16List.fromList([31, 32]));
    });

    test('mute 시 5개 silence frame 뒤 Speaking을 끄고 capture를 중지한다', () async {
      await engine.start();
      microphone.add(_pcmBytes(DiscordPcmFrameAssembler.samplesPerFrame));
      await engine.waitForPendingWork();

      await engine.setMuted(true);

      expect(microphone.stopCount, 1);
      expect(network.sentPackets, hasLength(6));
      expect(network.events.last, 'speaking:false');
      expect(engine.state.muted, isTrue);
      expect(engine.state.speaking, isFalse);

      final decoder = DiscordVoiceRtpCodec(
        mode: network.session.encryptionMode,
        secretKey: network.session.secretKey,
      );
      for (final packet in network.sentPackets.skip(1)) {
        final decoded = await decoder.decryptAudio(packet);
        expect(decoded.opusFrame, [0xDA, 0xF8, 0xFF, 0xFE]);
      }
    });

    test('사용자가 나가면 decoder와 playback stream을 함께 정리한다', () async {
      network.replaceUsers({5150: '400000000000000004'});
      await engine.start();

      network.replaceUsers(const {});
      await engine.waitForPendingWork();

      expect(opus.removedUsers, ['400000000000000004']);
      expect(playback.removedUsers, ['400000000000000004']);
    });

    test('VAD는 무음 frame을 버리고 음성 frame부터 전송한다', () async {
      await engine.start();

      microphone.add(Uint8List(DiscordPcmFrameAssembler.bytesPerFrame));
      await engine.waitForPendingWork();
      expect(network.sentPackets, isEmpty);

      microphone.add(_pcmBytes(DiscordPcmFrameAssembler.samplesPerFrame));
      await engine.waitForPendingWork();
      expect(network.sentPackets, hasLength(1));
    });

    test('PTT는 press 동안만 전송하고 release 시 speaking을 종료한다', () async {
      await engine.setInputMode(DiscordVoiceInputMode.pushToTalk);
      await engine.start();

      microphone.add(_pcmBytes(DiscordPcmFrameAssembler.samplesPerFrame));
      await engine.waitForPendingWork();
      expect(network.sentPackets, isEmpty);

      await engine.setPushToTalkPressed(true);
      microphone.add(_pcmBytes(DiscordPcmFrameAssembler.samplesPerFrame));
      await engine.waitForPendingWork();
      expect(network.sentPackets, hasLength(1));

      await engine.setPushToTalkPressed(false);
      expect(network.sentPackets, hasLength(6));
      expect(network.events.last, 'speaking:false');
    });

    test('원격 사용자별 0~200% 음량을 playback에 위임한다', () async {
      await engine.start();

      engine.setUserVolume('400000000000000004', 1.5);

      expect(playback.volumes, {'400000000000000004': 1.5});
    });

    test('WebRTC session은 Opus frame을 RTP 이중 처리 없이 전송한다', () async {
      await engine.dispose();
      await network.dispose();
      network = _FakeVoiceMediaNetwork.webRtc();
      engine = DiscordVoiceMediaEngine(
        network: network,
        microphone: microphone,
        opus: opus,
        playback: playback,
      );
      await engine.start();

      microphone.add(_pcmBytes(DiscordPcmFrameAssembler.samplesPerFrame));
      await engine.waitForPendingWork();

      expect(network.sentPackets, isEmpty);
      expect(network.sentRtcFrames, [
        const _SentRtcAudio([0x11, 0x22], 20),
      ]);
      expect(network.events.take(2), ['speaking:true', 'rtc']);
    });

    test('WebRTC 수신 audio payload를 SSRC별 DAVE 해제 후 재생한다', () async {
      await engine.dispose();
      await network.dispose();
      network = _FakeVoiceMediaNetwork.webRtc();
      network.replaceUsers({5150: '400000000000000004'});
      engine = DiscordVoiceMediaEngine(
        network: network,
        microphone: microphone,
        opus: opus,
        playback: playback,
      );
      await engine.start();

      network.addRtcAudio(
        DiscordVoiceRtcAudioFrame(
          ssrc: 5150,
          sequence: 10,
          encryptedOpus: Uint8List.fromList([0xDA, 0x31]),
        ),
      );
      await engine.waitForPendingWork();

      expect(network.unprotectedUsers, ['400000000000000004']);
      expect(opus.decodedUsers, ['400000000000000004']);
      expect(playback.playedUsers, ['400000000000000004']);
    });

    test('WebRTC video를 사용자별 DAVE 해제해 render stream 상태로 노출한다', () async {
      await engine.dispose();
      await network.dispose();
      network = _FakeVoiceMediaNetwork.webRtc();
      network.replaceVideoUsers({5150: '400000000000000004'});
      engine = DiscordVoiceMediaEngine(
        network: network,
        microphone: microphone,
        opus: opus,
        playback: playback,
      );
      await engine.start();

      network.addRtcVideo(
        DiscordVoiceRtcVideoFrame(
          ssrc: 5150,
          timestamp: 90000,
          encryptedH264: Uint8List.fromList([0xDA, 0, 0, 0, 1, 0x65]),
        ),
      );
      await engine.waitForPendingWork();
      final preview = Object();
      network.addRtcVideoStream(
        DiscordVoiceRtcVideoStream(ssrc: 5150, preview: preview),
      );
      await engine.waitForPendingWork();

      expect(network.unprotectedVideoUsers, ['400000000000000004']);
      expect(network.renderedVideo, [
        const _RenderedRtcVideo([0, 0, 0, 1, 0x65], 5150, 90000),
      ]);
      expect(engine.state.remoteVideoPreviews, {
        '400000000000000004': same(preview),
      });

      network.replaceVideoUsers(const {});
      await engine.waitForPendingWork();
      expect(engine.state.remoteVideoPreviews, isEmpty);
    });

    test('Go Live 시청 media는 마이크를 열지 않고 수신만 처리한다', () async {
      await engine.dispose();
      await network.dispose();
      network = _FakeVoiceMediaNetwork.webRtc();
      engine = DiscordVoiceMediaEngine(
        network: network,
        microphone: microphone,
        opus: opus,
        playback: playback,
        captureInput: false,
      );

      await engine.start();

      expect(microphone.isCapturing, isFalse);
      expect(engine.state.phase, DiscordVoiceMediaPhase.active);
    });
  });
}

Uint8List _pcmBytes(int sampleCount) {
  final bytes = Uint8List(sampleCount * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < sampleCount; index += 1) {
    data.setInt16(index * 2, index.isEven ? 20000 : -20000, Endian.little);
  }
  return bytes;
}

final class _FakeVoiceMediaNetwork implements DiscordVoiceMediaNetwork {
  _FakeVoiceMediaNetwork()
    : session = DiscordVoiceMediaSession(
        ssrc: 4242,
        encryptionMode: DiscordVoiceGatewayClient.xchacha20Poly1305Mode,
        secretKey: Uint8List.fromList(List<int>.generate(32, (index) => index)),
      );

  _FakeVoiceMediaNetwork.webRtc()
    : session = DiscordVoiceMediaSession.webRtc(ssrc: 4242);

  final StreamController<Uint8List> _packets = StreamController.broadcast();
  final StreamController<DiscordVoiceRtcAudioFrame> _rtcAudioFrames =
      StreamController.broadcast();
  final StreamController<DiscordVoiceRtcVideoFrame> _rtcVideoFrames =
      StreamController.broadcast();
  final StreamController<DiscordVoiceRtcVideoStream> _rtcVideoStreams =
      StreamController.broadcast();
  final StreamController<Map<int, String>> _users =
      StreamController.broadcast();
  final StreamController<Map<int, String>> _videoUsers =
      StreamController.broadcast();

  @override
  final DiscordVoiceMediaSession session;

  Map<int, String> _usersBySsrc = const {};
  Map<int, String> _videoUsersBySsrc = const {};
  List<Uint8List> sentPackets = const [];
  List<String> events = const [];
  List<String> unprotectedUsers = const [];
  List<String> unprotectedVideoUsers = const [];
  List<_SentRtcAudio> sentRtcFrames = const [];
  List<_RenderedRtcVideo> renderedVideo = const [];

  @override
  Stream<Uint8List> get udpPackets => _packets.stream;

  @override
  Stream<DiscordVoiceRtcAudioFrame> get rtcAudioFrames =>
      _rtcAudioFrames.stream;

  @override
  Stream<DiscordVoiceRtcVideoFrame> get rtcVideoFrames =>
      _rtcVideoFrames.stream;

  @override
  Stream<DiscordVoiceRtcVideoStream> get rtcVideoStreams =>
      _rtcVideoStreams.stream;

  @override
  Map<int, String> get usersBySsrc => _usersBySsrc;

  @override
  Stream<Map<int, String>> get usersBySsrcChanges => _users.stream;

  @override
  Map<int, String> get videoUsersBySsrc => _videoUsersBySsrc;

  @override
  Stream<Map<int, String>> get videoUsersBySsrcChanges => _videoUsers.stream;

  void addPacket(Uint8List packet) => _packets.add(packet);

  void addRtcAudio(DiscordVoiceRtcAudioFrame frame) =>
      _rtcAudioFrames.add(frame);

  void addRtcVideo(DiscordVoiceRtcVideoFrame frame) =>
      _rtcVideoFrames.add(frame);

  void addRtcVideoStream(DiscordVoiceRtcVideoStream stream) =>
      _rtcVideoStreams.add(stream);

  void replaceUsers(Map<int, String> users) {
    _usersBySsrc = Map.unmodifiable(users);
    _users.add(_usersBySsrc);
  }

  void replaceVideoUsers(Map<int, String> users) {
    _videoUsersBySsrc = Map.unmodifiable(users);
    _videoUsers.add(_videoUsersBySsrc);
  }

  @override
  Uint8List protectAudio(Uint8List opusFrame) {
    return Uint8List.fromList([0xDA, ...opusFrame]);
  }

  @override
  Uint8List unprotectAudio(
    Uint8List encryptedFrame, {
    required String remoteUserId,
  }) {
    unprotectedUsers = List.unmodifiable([...unprotectedUsers, remoteUserId]);
    return Uint8List.fromList(encryptedFrame.sublist(1));
  }

  @override
  Uint8List unprotectVideo(
    Uint8List encryptedFrame, {
    required String remoteUserId,
  }) {
    unprotectedVideoUsers = List.unmodifiable([
      ...unprotectedVideoUsers,
      remoteUserId,
    ]);
    return Uint8List.fromList(encryptedFrame.sublist(1));
  }

  @override
  Future<void> renderRtcVideo(
    Uint8List h264AccessUnit, {
    required int ssrc,
    required int timestamp,
  }) async {
    renderedVideo = List.unmodifiable([
      ...renderedVideo,
      _RenderedRtcVideo(
        List<int>.unmodifiable(h264AccessUnit),
        ssrc,
        timestamp,
      ),
    ]);
  }

  @override
  Future<void> sendUdp(Uint8List packet) async {
    sentPackets = List.unmodifiable([
      ...sentPackets,
      Uint8List.fromList(packet),
    ]);
    events = List.unmodifiable([...events, 'udp']);
  }

  @override
  Future<void> sendRtcAudio(
    Uint8List opusFrame, {
    int durationMilliseconds = 20,
  }) async {
    sentRtcFrames = List.unmodifiable([
      ...sentRtcFrames,
      _SentRtcAudio(List<int>.unmodifiable(opusFrame), durationMilliseconds),
    ]);
    events = List.unmodifiable([...events, 'rtc']);
  }

  @override
  Future<void> setSpeaking(bool speaking) async {
    events = List.unmodifiable([...events, 'speaking:$speaking']);
  }

  Future<void> dispose() async {
    await _packets.close();
    await _rtcAudioFrames.close();
    await _rtcVideoFrames.close();
    await _rtcVideoStreams.close();
    await _users.close();
    await _videoUsers.close();
  }
}

final class _RenderedRtcVideo {
  const _RenderedRtcVideo(this.frame, this.ssrc, this.timestamp);

  final List<int> frame;
  final int ssrc;
  final int timestamp;

  @override
  bool operator ==(Object other) {
    return other is _RenderedRtcVideo &&
        ssrc == other.ssrc &&
        timestamp == other.timestamp &&
        _sameBytes(frame, other.frame);
  }

  @override
  int get hashCode => Object.hash(ssrc, timestamp, Object.hashAll(frame));
}

final class _SentRtcAudio {
  const _SentRtcAudio(this.frame, this.durationMilliseconds);

  final List<int> frame;
  final int durationMilliseconds;

  @override
  bool operator ==(Object other) {
    return other is _SentRtcAudio &&
        durationMilliseconds == other.durationMilliseconds &&
        _sameBytes(frame, other.frame);
  }

  @override
  int get hashCode => Object.hash(durationMilliseconds, Object.hashAll(frame));
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

final class _FakeMicrophoneCapture implements DiscordMicrophoneCapture {
  final StreamController<Uint8List> _controller = StreamController.broadcast();
  bool _capturing = false;
  int stopCount = 0;

  @override
  bool get isCapturing => _capturing;

  void add(Uint8List chunk) => _controller.add(chunk);

  @override
  Future<Stream<Uint8List>> start() async {
    _capturing = true;
    return _controller.stream;
  }

  @override
  Future<void> stop() async {
    if (_capturing) {
      stopCount += 1;
    }
    _capturing = false;
  }

  @override
  Future<void> dispose() async {
    _capturing = false;
  }

  Future<void> disposeController() => _controller.close();
}

final class _FakeOpusCodec implements DiscordOpusCodec {
  List<Int16List> encodedFrames = const [];
  List<String> decodedUsers = const [];
  List<String> packetLossUsers = const [];
  List<String> removedUsers = const [];

  @override
  String get version => 'test';

  @override
  Uint8List encode(Int16List pcmFrame) {
    encodedFrames = List.unmodifiable([
      ...encodedFrames,
      Int16List.fromList(pcmFrame),
    ]);
    return Uint8List.fromList([0x11, 0x22]);
  }

  @override
  Int16List decode(Uint8List opusPacket, {required String remoteUserId}) {
    decodedUsers = List.unmodifiable([...decodedUsers, remoteUserId]);
    return Int16List.fromList([31, 32]);
  }

  @override
  Int16List decodePacketLoss({
    required String remoteUserId,
    int durationMilliseconds = 20,
  }) {
    packetLossUsers = List.unmodifiable([...packetLossUsers, remoteUserId]);
    return Int16List.fromList([-1, -1]);
  }

  @override
  void removeRemoteUser(String remoteUserId) {
    removedUsers = List.unmodifiable([...removedUsers, remoteUserId]);
  }

  @override
  void close() {}
}

final class _FakeVoicePlayback implements DiscordVoicePlayback {
  List<String> playedUsers = const [];
  List<Int16List> playedPcm = const [];
  List<String> removedUsers = const [];
  Map<String, double> volumes = const {};

  @override
  Future<void> initialize() async {}

  @override
  Future<void> addPcm(String remoteUserId, Int16List pcm) async {
    playedUsers = List.unmodifiable([...playedUsers, remoteUserId]);
    playedPcm = List.unmodifiable([...playedPcm, Int16List.fromList(pcm)]);
  }

  @override
  void setUserVolume(String remoteUserId, double volume) {
    volumes = Map.unmodifiable({...volumes, remoteUserId: volume});
  }

  @override
  Future<void> removeUser(String remoteUserId) async {
    removedUsers = List.unmodifiable([...removedUsers, remoteUserId]);
  }

  @override
  Future<void> dispose() async {}
}
