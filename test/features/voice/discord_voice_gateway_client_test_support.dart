part of 'discord_voice_gateway_client_test.dart';

Future<void> _prepareReadyClient(
  DiscordVoiceGatewayClient client,
  _FakeVoiceGatewayTransport transport,
) async {
  await client.connect(
    const DiscordVoiceCredentials(
      guildId: '100000000000000001',
      channelId: '200000000000000002',
      userId: '300000000000000003',
      sessionId: 'session-1',
      token: 'voice-token',
      endpoint: 'rotterdam123.discord.media',
    ),
  );
  transport.addJson({
    'op': 2,
    'd': {
      'ssrc': 10,
      'ip': '198.51.100.10',
      'port': 50000,
      'modes': ['aead_xchacha20_poly1305_rtpsize'],
    },
  });
  await pumpEventQueue();
  transport.addJson({
    'op': 4,
    'seq': 9,
    'd': {
      'mode': 'aead_xchacha20_poly1305_rtpsize',
      'secret_key': List<int>.generate(32, (index) => index),
      'dave_protocol_version': 1,
    },
  });
  await pumpEventQueue();
}

final class _FakeVoiceGatewayTransport implements VoiceGatewayTransport {
  final StreamController<Object?> _messages = StreamController.broadcast();
  final StreamController<int?> _closes = StreamController.broadcast();

  Uri? connectedUri;
  List<Uri> connectedUris = const [];
  List<Map<String, Object?>> sentJson = const [];
  List<Uint8List> sentBinary = const [];
  int connectAttempts = 0;
  int connectFailuresRemaining = 0;

  @override
  Stream<int?> get closes => _closes.stream;

  @override
  Stream<Object?> get messages => _messages.stream;

  void addJson(Map<String, Object?> payload) {
    _messages.add(jsonEncode(payload));
  }

  void addBinary(Uint8List payload) => _messages.add(payload);

  void addClose(int? code) => _closes.add(code);

  @override
  Future<void> close() async {}

  @override
  Future<void> connect(Uri uri) async {
    connectAttempts += 1;
    if (connectFailuresRemaining > 0) {
      connectFailuresRemaining -= 1;
      throw StateError('임시 Voice WebSocket 연결 실패');
    }
    connectedUri = uri;
    connectedUris = List.unmodifiable([...connectedUris, uri]);
  }

  Future<void> dispose() async {
    await _messages.close();
    await _closes.close();
  }

  @override
  Future<void> sendBinary(Uint8List payload) async {
    sentBinary = List.unmodifiable([
      ...sentBinary,
      Uint8List.fromList(payload),
    ]);
  }

  @override
  Future<void> sendJson(Map<String, Object?> payload) async {
    sentJson = List.unmodifiable([...sentJson, payload]);
  }
}

final class _FakeVoiceUdpTransport implements VoiceUdpTransport {
  VoiceIpDiscoveryResult discoveryResult = const VoiceIpDiscoveryResult(
    address: '203.0.113.7',
    port: 54321,
  );
  String? serverAddress;
  int? serverPort;
  int? ssrc;
  int closeCount = 0;

  @override
  Stream<Uint8List> get packets => const Stream.empty();

  @override
  Future<void> close() async {
    closeCount += 1;
  }

  @override
  Future<VoiceIpDiscoveryResult> connectAndDiscover({
    required String serverAddress,
    required int serverPort,
    required int ssrc,
  }) async {
    this.serverAddress = serverAddress;
    this.serverPort = serverPort;
    this.ssrc = ssrc;
    return discoveryResult;
  }

  @override
  Future<void> send(Uint8List packet) async {}
}

final class _FakeVoiceHeartbeatScheduler implements VoiceHeartbeatScheduler {
  Duration? interval;
  Future<void> Function()? callback;

  @override
  VoiceScheduledTask schedule(
    Duration interval,
    Future<void> Function() callback,
  ) {
    this.interval = interval;
    this.callback = callback;
    return _FakeVoiceScheduledTask();
  }

  Future<void> tick() async => callback?.call();
}

final class _FakeVoiceScheduledTask implements VoiceScheduledTask {
  @override
  void cancel() {}
}

final class _FakeDiscordDaveSession implements DiscordDaveSession {
  @override
  int get maxSupportedProtocolVersion => 1;

  @override
  int protocolVersion = 0;

  ({int protocolVersion, int groupId, String selfUserId})? initialization;
  int initializationCount = 0;
  int? localAudioSsrc;
  ({int ssrc, DiscordDaveVideoCodec codec})? localVideo;
  int? encryptedSsrc;
  String? decryptedRemoteUserId;

  @override
  void initialize({
    required int protocolVersion,
    required int groupId,
    required String selfUserId,
  }) {
    this.protocolVersion = protocolVersion;
    initializationCount += 1;
    initialization = (
      protocolVersion: protocolVersion,
      groupId: groupId,
      selfUserId: selfUserId,
    );
  }

  @override
  Uint8List createKeyPackage() => Uint8List.fromList([7, 8, 9]);

  @override
  void assignLocalAudioSsrc(int ssrc) {
    localAudioSsrc = ssrc;
  }

  @override
  void assignLocalVideoSsrc(int ssrc, {required DiscordDaveVideoCodec codec}) {
    localVideo = (ssrc: ssrc, codec: codec);
  }

  @override
  void setExternalSender(Uint8List payload) {}

  @override
  Uint8List? processProposals(
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  }) => null;

  @override
  DiscordDaveGroupUpdate processCommit(Uint8List payload) {
    return DiscordDaveGroupUpdate.applied;
  }

  @override
  DiscordDaveGroupUpdate processWelcome(
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  }) {
    return DiscordDaveGroupUpdate.applied;
  }

  @override
  void setPassthroughMode({
    required bool enabled,
    required Iterable<String> remoteUserIds,
  }) {}

  @override
  Uint8List encryptAudio(Uint8List frame, {required int ssrc}) {
    encryptedSsrc = ssrc;
    return Uint8List.fromList(frame);
  }

  @override
  Uint8List decryptAudio(Uint8List frame, {required String remoteUserId}) {
    decryptedRemoteUserId = remoteUserId;
    return Uint8List.fromList(frame);
  }

  @override
  Uint8List decryptVideo(Uint8List frame, {required String remoteUserId}) {
    return Uint8List.fromList(frame);
  }

  @override
  Uint8List encryptVideo(Uint8List frame, {required int ssrc}) {
    return Uint8List.fromList(frame);
  }

  @override
  void close() {}
}

final class _FakeVoiceRtcTransport implements DiscordVoiceRtcMediaTransport {
  final StreamController<DiscordVoiceRtcAudioFrame> _audioFrames =
      StreamController.broadcast(sync: true);
  final StreamController<String> _errors = StreamController.broadcast(
    sync: true,
  );
  DiscordVoiceRtcOffer offer = const DiscordVoiceRtcOffer(
    sdp: 'offer',
    rtcConnectionId: 'rtc-id',
  );
  DiscordVoiceRtcSession? session;
  DiscordVoiceRtcAnswer? answer;
  int closeCount = 0;
  List<List<int>> sentAudioFrames = const [];
  List<int> sentAudioDurations = const [];

  @override
  Stream<DiscordVoiceRtcAudioFrame> get audioFrames => _audioFrames.stream;

  @override
  Stream<DiscordVoiceRtcVideoFrame> get videoFrames => const Stream.empty();

  @override
  Stream<DiscordVoiceRtcVideoStream> get videoStreams => const Stream.empty();

  @override
  Stream<String> get errors => _errors.stream;

  void emitAudio(DiscordVoiceRtcAudioFrame frame) => _audioFrames.add(frame);

  void emitError(String message) => _errors.add(message);

  @override
  Future<DiscordVoiceRtcOffer> createOffer(
    DiscordVoiceRtcSession session,
  ) async {
    this.session = session;
    return offer;
  }

  @override
  Future<void> acceptAnswer(DiscordVoiceRtcAnswer answer) async {
    this.answer = answer;
  }

  @override
  Future<void> close() async {
    closeCount += 1;
  }

  @override
  Future<void> sendAudio(
    Uint8List opusFrame, {
    int durationMilliseconds = 20,
  }) async {
    sentAudioFrames = List.unmodifiable([
      ...sentAudioFrames,
      List<int>.unmodifiable(opusFrame),
    ]);
    sentAudioDurations = List.unmodifiable([
      ...sentAudioDurations,
      durationMilliseconds,
    ]);
  }

  @override
  Future<void> sendVideo(
    Uint8List h264AccessUnit, {
    required int durationMilliseconds,
  }) async {}

  @override
  Future<void> renderVideo(
    Uint8List h264AccessUnit, {
    required int ssrc,
    required int timestamp,
  }) async {}

  Future<void> dispose() async {
    await _audioFrames.close();
    await _errors.close();
  }
}
