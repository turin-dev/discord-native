part of 'discord_voice_coordinator_test.dart';

Future<void> _connectReady(
  DiscordVoiceCoordinator coordinator,
  _FakeVoiceNetworkConnection network,
) async {
  await coordinator.join(
    guildId: '100000000000000001',
    channelId: '200000000000000002',
  );
  coordinator.receiveGatewayEvent(
    _voiceStateEvent(),
    currentUserId: '300000000000000003',
  );
  coordinator.receiveGatewayEvent(
    _voiceServerEvent(),
    currentUserId: '300000000000000003',
  );
  await pumpEventQueue();
  network.emit(
    DiscordVoiceNetworkState(
      phase: DiscordVoiceNetworkPhase.ready,
      ssrc: 4242,
      encryptionMode: 'aead_aes256_gcm_rtpsize',
      secretKey: Uint8List(32),
      daveProtocolVersion: 1,
    ),
  );
  await pumpEventQueue();
}

const _selfStreamKey =
    'guild:100000000000000001:200000000000000002:300000000000000003';
const _streamKey =
    'guild:100000000000000001:200000000000000002:600000000000000006';

Map<String, Object?> _streamCreateEvent([String streamKey = _streamKey]) {
  return {
    'op': 0,
    't': 'STREAM_CREATE',
    'd': {
      'stream_key': streamKey,
      'rtc_server_id': '400000000000000004',
      'rtc_channel_id': '500000000000000005',
      'region': 'rotterdam',
      'viewer_ids': const <String>[],
      'paused': false,
    },
  };
}

Map<String, Object?> _streamServerEvent([String streamKey = _streamKey]) {
  return {
    'op': 0,
    't': 'STREAM_SERVER_UPDATE',
    'd': {
      'stream_key': streamKey,
      'token': 'stream-token',
      'endpoint': 'stream.discord.media:443',
    },
  };
}

Map<String, Object?> _streamDeleteEvent({required String reason}) {
  return {
    'op': 0,
    't': 'STREAM_DELETE',
    'd': {'stream_key': _streamKey, 'reason': reason},
  };
}

Map<String, Object?> _voiceServerEvent() {
  return {
    'op': 0,
    't': 'VOICE_SERVER_UPDATE',
    'd': {
      'guild_id': '100000000000000001',
      'token': 'voice-token',
      'endpoint': 'rotterdam123.discord.media:443',
    },
  };
}

Map<String, Object?> _voiceStateEvent() {
  return {
    'op': 0,
    't': 'VOICE_STATE_UPDATE',
    'd': {
      'guild_id': '100000000000000001',
      'channel_id': '200000000000000002',
      'user_id': '300000000000000003',
      'session_id': 'voice-session',
      'deaf': false,
      'mute': false,
      'self_deaf': false,
      'self_mute': false,
      'self_stream': false,
      'self_video': false,
      'suppress': false,
    },
  };
}

final class _FakeGatewayConnection
    implements DiscordGatewayConnection, DiscordVideoGatewayConnection {
  final StreamController<GatewaySessionState> _states =
      StreamController.broadcast();
  final StreamController<Map<String, Object?>> _events =
      StreamController.broadcast();

  List<({String guildId, String? channelId, bool selfMute, bool selfDeaf})>
  voiceUpdates = const [];
  List<
    ({
      String guildId,
      String channelId,
      bool selfMute,
      bool selfDeaf,
      bool selfVideo,
    })
  >
  videoUpdates = const [];
  List<({String guildId, String channelId})> createdStreams = const [];
  List<String> deletedStreams = const [];
  List<String> watchedStreams = const [];
  List<({String streamKey, bool paused})> pausedStreams = const [];

  @override
  GatewaySessionState get state => const GatewaySessionState.disconnected();

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Stream<GatewaySessionState> get states => _states.stream;

  @override
  Future<void> connect(String input) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> updateVoiceState({
    required String guildId,
    required String? channelId,
    required bool selfMute,
    required bool selfDeaf,
  }) async {
    voiceUpdates = List.unmodifiable([
      ...voiceUpdates,
      (
        guildId: guildId,
        channelId: channelId,
        selfMute: selfMute,
        selfDeaf: selfDeaf,
      ),
    ]);
  }

  @override
  Future<void> updateVoiceVideoState({
    required String guildId,
    required String channelId,
    required bool selfMute,
    required bool selfDeaf,
    required bool selfVideo,
  }) async {
    videoUpdates = List.unmodifiable([
      ...videoUpdates,
      (
        guildId: guildId,
        channelId: channelId,
        selfMute: selfMute,
        selfDeaf: selfDeaf,
        selfVideo: selfVideo,
      ),
    ]);
  }

  @override
  Future<void> createStream({
    required String guildId,
    required String channelId,
  }) async {
    createdStreams = List.unmodifiable([
      ...createdStreams,
      (guildId: guildId, channelId: channelId),
    ]);
  }

  @override
  Future<void> deleteStream(String streamKey) async {
    deletedStreams = List.unmodifiable([...deletedStreams, streamKey]);
  }

  @override
  Future<void> setStreamPaused({
    required String streamKey,
    required bool paused,
  }) async {
    pausedStreams = List.unmodifiable([
      ...pausedStreams,
      (streamKey: streamKey, paused: paused),
    ]);
  }

  @override
  Future<void> watchStream(String streamKey) async {
    watchedStreams = List.unmodifiable([...watchedStreams, streamKey]);
  }

  Future<void> disposeControllers() async {
    await _states.close();
    await _events.close();
  }
}

final class _FakeVoiceNetworkConnection
    implements DiscordVoiceNetworkConnection {
  final StreamController<DiscordVoiceNetworkState> _states =
      StreamController.broadcast();

  DiscordVoiceNetworkState _state = DiscordVoiceNetworkState();
  DiscordVoiceCredentials? connectedCredentials;
  DiscordVoiceConnectionOptions? connectedOptions;
  int disposeCount = 0;

  @override
  DiscordVoiceMediaNetwork get mediaNetwork => _NoopVoiceMediaNetwork();

  @override
  DiscordVoiceNetworkState get state => _state;

  @override
  Stream<DiscordVoiceNetworkState> get states => _states.stream;

  void emit(DiscordVoiceNetworkState state) {
    _state = state;
    _states.add(state);
  }

  @override
  Future<void> connect(
    DiscordVoiceCredentials credentials, {
    DiscordVoiceConnectionOptions options =
        const DiscordVoiceConnectionOptions.audioOnly(),
  }) async {
    connectedCredentials = credentials;
    connectedOptions = options;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }

  Future<void> disposeControllers() => _states.close();
}

final class _FakeVideoCapture implements DiscordVideoCaptureController {
  _FakeVideoCapture({
    DiscordVideoSource source = const DiscordVideoSource.camera(
      sourceId: 'camera-track',
      width: 1280,
      height: 720,
      framesPerSecond: 30,
    ),
  }) : session = _FakeVideoCaptureSession(source);

  final _FakeVideoCaptureSession session;
  int startCameraCount = 0;
  int startScreenCount = 0;
  int stopCount = 0;
  List<bool> pausedValues = const [];

  @override
  DiscordVideoCaptureSession? get activeSession =>
      startCameraCount + startScreenCount > stopCount ? session : null;

  @override
  Future<DiscordVideoCaptureSession> startCamera() async {
    startCameraCount += 1;
    return session;
  }

  @override
  Future<DiscordVideoCaptureSession> startScreen() async {
    startScreenCount += 1;
    return session;
  }

  @override
  Future<void> setPaused(bool paused) async {
    pausedValues = List.unmodifiable([...pausedValues, paused]);
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}

final class _FakeVideoCaptureSession implements DiscordVideoCaptureSession {
  const _FakeVideoCaptureSession(this.source);

  @override
  final DiscordVideoSource source;

  @override
  Object? get preview => null;
}

final class _FakeVoiceMediaConnection implements DiscordVoiceMediaConnection {
  final StreamController<DiscordVoiceMediaState> _states =
      StreamController.broadcast();

  DiscordVoiceMediaState _state = const DiscordVoiceMediaState();
  List<bool> mutedValues = const [];
  List<bool> deafenedValues = const [];
  List<DiscordVoiceInputMode> inputModes = const [];
  List<bool> pushToTalkValues = const [];
  Map<String, double> volumes = const {};
  int startCount = 0;
  int disposeCount = 0;

  @override
  DiscordVoiceMediaState get state => _state;

  @override
  Stream<DiscordVoiceMediaState> get states => _states.stream;

  @override
  Future<void> start() async {
    startCount += 1;
    _state = _state.copyWith(phase: DiscordVoiceMediaPhase.active);
    _states.add(_state);
  }

  @override
  Future<void> setMuted(bool muted) async {
    mutedValues = List.unmodifiable([...mutedValues, muted]);
    _state = _state.copyWith(muted: muted);
    _states.add(_state);
  }

  @override
  Future<void> setDeafened(bool deafened) async {
    deafenedValues = List.unmodifiable([...deafenedValues, deafened]);
    _state = _state.copyWith(deafened: deafened);
    _states.add(_state);
  }

  @override
  Future<void> setInputMode(DiscordVoiceInputMode inputMode) async {
    inputModes = List.unmodifiable([...inputModes, inputMode]);
    _state = _state.copyWith(inputMode: inputMode);
    _states.add(_state);
  }

  @override
  Future<void> setPushToTalkPressed(bool pressed) async {
    pushToTalkValues = List.unmodifiable([...pushToTalkValues, pressed]);
    _state = _state.copyWith(pushToTalkPressed: pressed);
    _states.add(_state);
  }

  @override
  void setUserVolume(String remoteUserId, double volume) {
    volumes = Map.unmodifiable({...volumes, remoteUserId: volume});
  }

  @override
  Future<void> stop() async {}

  void emit(DiscordVoiceMediaState state) {
    _state = state;
    _states.add(state);
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }

  Future<void> disposeControllers() => _states.close();
}

final class _NoopVoiceMediaNetwork implements DiscordVoiceMediaNetwork {
  @override
  DiscordVoiceMediaSession get session => throw UnimplementedError();

  @override
  Stream<Uint8List> get udpPackets => const Stream.empty();

  @override
  Stream<DiscordVoiceRtcAudioFrame> get rtcAudioFrames => const Stream.empty();

  @override
  Stream<DiscordVoiceRtcVideoFrame> get rtcVideoFrames => const Stream.empty();

  @override
  Stream<DiscordVoiceRtcVideoStream> get rtcVideoStreams =>
      const Stream.empty();

  @override
  Map<int, String> get usersBySsrc => const {};

  @override
  Stream<Map<int, String>> get usersBySsrcChanges => const Stream.empty();

  @override
  Map<int, String> get videoUsersBySsrc => const {};

  @override
  Stream<Map<int, String>> get videoUsersBySsrcChanges => const Stream.empty();

  @override
  Uint8List protectAudio(Uint8List opusFrame) => opusFrame;

  @override
  Future<void> sendUdp(Uint8List packet) async {}

  @override
  Future<void> sendRtcAudio(
    Uint8List opusFrame, {
    int durationMilliseconds = 20,
  }) async {}

  @override
  Future<void> renderRtcVideo(
    Uint8List h264AccessUnit, {
    required int ssrc,
    required int timestamp,
  }) async {}

  @override
  Future<void> setSpeaking(bool speaking) async {}

  @override
  Uint8List unprotectAudio(
    Uint8List encryptedFrame, {
    required String remoteUserId,
  }) => encryptedFrame;

  @override
  Uint8List unprotectVideo(
    Uint8List encryptedFrame, {
    required String remoteUserId,
  }) => encryptedFrame;
}
