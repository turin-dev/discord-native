import 'dart:async';

import 'package:discord_native/core/gateway/discord_gateway_client.dart';
import 'package:discord_native/features/voice/data/discord_voice_gateway_client.dart';
import 'package:discord_native/features/voice/data/discord_voice_media_engine.dart';
import 'package:discord_native/features/voice/domain/discord_voice_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_ui_state.dart';
import 'package:discord_native/features/video/data/discord_video_capture.dart';
import 'package:discord_native/features/video/domain/discord_video_protocol.dart';
import 'package:discord_native/features/video/domain/discord_stream_state.dart';
import 'package:discord_native/features/video/domain/discord_video_ui_state.dart';

export 'package:discord_native/features/voice/data/discord_voice_media_engine.dart'
    show DiscordVoiceMediaConnection;
export 'package:discord_native/features/voice/domain/discord_voice_ui_state.dart';

part 'discord_voice_coordinator_connection.dart';
part 'discord_voice_coordinator_stream.dart';

abstract interface class DiscordVoiceNetworkConnection {
  DiscordVoiceNetworkState get state;

  Stream<DiscordVoiceNetworkState> get states;

  DiscordVoiceMediaNetwork get mediaNetwork;

  Future<void> connect(
    DiscordVoiceCredentials credentials, {
    DiscordVoiceConnectionOptions options =
        const DiscordVoiceConnectionOptions.audioOnly(),
  });

  Future<void> disconnect();

  Future<void> dispose();
}

final class GatewayDiscordVoiceNetworkConnection
    implements DiscordVoiceNetworkConnection {
  GatewayDiscordVoiceNetworkConnection(DiscordVoiceGatewayClient client)
    : _client = client,
      _mediaNetwork = DiscordVoiceGatewayMediaNetwork(client);

  final DiscordVoiceGatewayClient _client;
  final DiscordVoiceMediaNetwork _mediaNetwork;

  @override
  DiscordVoiceNetworkState get state => _client.state;

  @override
  Stream<DiscordVoiceNetworkState> get states => _client.states;

  @override
  DiscordVoiceMediaNetwork get mediaNetwork => _mediaNetwork;

  @override
  Future<void> connect(
    DiscordVoiceCredentials credentials, {
    DiscordVoiceConnectionOptions options =
        const DiscordVoiceConnectionOptions.audioOnly(),
  }) {
    return _client.connect(credentials, options: options);
  }

  @override
  Future<void> disconnect() => _client.disconnect();

  @override
  Future<void> dispose() => _client.dispose();
}

typedef DiscordVoiceNetworkFactory = DiscordVoiceNetworkConnection Function();
typedef DiscordVoiceMediaFactory =
    DiscordVoiceMediaConnection Function(DiscordVoiceMediaNetwork network);

final class DiscordVoiceCoordinator {
  DiscordVoiceCoordinator({
    required DiscordGatewayConnection mainGateway,
    required DiscordVoiceNetworkFactory networkFactory,
    required DiscordVoiceMediaFactory mediaFactory,
    DiscordVideoCaptureController? videoCapture,
    DiscordVoiceNetworkFactory? streamNetworkFactory,
    DiscordVoiceMediaFactory? streamMediaFactory,
    DiscordVideoCaptureController? screenCapture,
  }) : _mainGateway = mainGateway,
       _networkFactory = networkFactory,
       _mediaFactory = mediaFactory,
       _videoCapture = videoCapture,
       _streamNetworkFactory = streamNetworkFactory ?? networkFactory,
       _streamMediaFactory = streamMediaFactory ?? mediaFactory,
       _screenCapture = screenCapture ?? videoCapture;

  final DiscordGatewayConnection _mainGateway;
  final DiscordVoiceNetworkFactory _networkFactory;
  final DiscordVoiceMediaFactory _mediaFactory;
  final DiscordVideoCaptureController? _videoCapture;
  final DiscordVoiceNetworkFactory _streamNetworkFactory;
  final DiscordVoiceMediaFactory _streamMediaFactory;
  final DiscordVideoCaptureController? _screenCapture;
  final StreamController<DiscordVoiceUiState> _states =
      StreamController.broadcast();

  DiscordVoiceUiState _state = const DiscordVoiceUiState();
  DiscordVoiceNetworkConnection? _network;
  DiscordVoiceMediaConnection? _media;
  StreamSubscription<DiscordVoiceNetworkState>? _networkSubscription;
  StreamSubscription<DiscordVoiceMediaState>? _mediaSubscription;
  DiscordVoiceNetworkConnection? _streamNetwork;
  DiscordVoiceMediaConnection? _streamMedia;
  StreamSubscription<DiscordVoiceNetworkState>? _streamNetworkSubscription;
  StreamSubscription<DiscordVoiceMediaState>? _streamMediaSubscription;
  DiscordStreamState? _streamState;
  DiscordVoiceCredentials? _activeStreamCredentials;
  DiscordVideoSource? _streamSource;
  _DiscordStreamIntent? _streamIntent;
  Map<String, Object> _primaryRemotePreviews = const {};
  Map<String, Object> _streamRemotePreviews = const {};
  DiscordVoiceCredentials? _activeCredentials;
  int _generation = 0;
  int _streamGeneration = 0;
  bool _mediaStarting = false;
  Future<void>? _mediaResetWork;
  bool _disposed = false;

  DiscordVoiceUiState get state => _state;

  Stream<DiscordVoiceUiState> get states async* {
    yield _state;
    yield* _states.stream;
  }

  Future<void> join({
    required String guildId,
    required String channelId,
  }) async {
    _ensureActive();
    await _closeConnections();
    final voice = _state.voice.beginJoin(
      guildId: guildId,
      channelId: channelId,
      selfMute: _state.voice.selfMute,
      selfDeaf: _state.voice.selfDeaf,
    );
    _update(_state.copyWith(voice: voice, errorMessage: null));
    try {
      await _mainGateway.updateVoiceState(
        guildId: guildId,
        channelId: channelId,
        selfMute: voice.selfMute,
        selfDeaf: voice.selfDeaf,
      );
    } on Object catch (error) {
      _fail(error);
      rethrow;
    }
  }

  Future<void> leave() async {
    _ensureActive();
    final voice = _state.voice;
    final guildId = voice.guildId;
    if (guildId == null || voice.channelId == null) {
      return;
    }
    _update(_state.copyWith(voice: voice.beginLeave(), errorMessage: null));
    try {
      await _mainGateway.updateVoiceState(
        guildId: guildId,
        channelId: null,
        selfMute: false,
        selfDeaf: false,
      );
      await _stopVideoCapture();
      await _closeConnections();
    } on Object catch (error) {
      _fail(error);
      rethrow;
    }
  }

  Future<void> setCameraEnabled(bool enabled) async {
    _ensureActive();
    if (enabled == _state.video.cameraEnabled) {
      return;
    }
    final credentials = _activeCredentials;
    final guildId = _state.voice.guildId;
    final channelId = _state.voice.channelId;
    final capture = _videoCapture;
    final videoGateway = _mainGateway;
    if (credentials == null || guildId == null || channelId == null) {
      throw StateError('카메라를 사용할 음성 연결이 준비되지 않았습니다.');
    }
    if (capture == null || videoGateway is! DiscordVideoGatewayConnection) {
      throw StateError('카메라 영상 기능이 구성되지 않았습니다.');
    }
    final activeVideoGateway = videoGateway as DiscordVideoGatewayConnection;
    if (enabled) {
      await _enableCamera(
        capture,
        activeVideoGateway,
        credentials,
        guildId,
        channelId,
      );
      return;
    }
    await _disableCamera(activeVideoGateway, credentials, guildId, channelId);
  }

  Future<void> setMuted(bool muted) async {
    await _setSelfAudio(selfMute: muted, selfDeaf: _state.voice.selfDeaf);
  }

  Future<void> setDeafened(bool deafened) async {
    await _setSelfAudio(selfMute: _state.voice.selfMute, selfDeaf: deafened);
  }

  Future<void> setInputMode(DiscordVoiceInputMode inputMode) async {
    _ensureActive();
    final media = _media;
    if (media != null) {
      await media.setInputMode(inputMode);
      return;
    }
    _update(
      _state.copyWith(media: _state.media.copyWith(inputMode: inputMode)),
    );
  }

  Future<void> setPushToTalkPressed(bool pressed) async {
    _ensureActive();
    final media = _media;
    if (media == null) {
      throw StateError('Voice media가 아직 준비되지 않았습니다.');
    }
    await media.setPushToTalkPressed(pressed);
  }

  void setUserVolume(String remoteUserId, double volume) {
    _ensureActive();
    final media = _media;
    if (media == null) {
      throw StateError('Voice media가 아직 준비되지 않았습니다.');
    }
    media.setUserVolume(remoteUserId, volume);
  }

  void receiveGatewayEvent(
    Map<String, Object?> event, {
    required String? currentUserId,
  }) {
    if (_disposed) {
      return;
    }
    try {
      final previousChannelId = _state.voice.channelId;
      final voice = _state.voice.payloadReceived(
        event,
        currentUserId: currentUserId,
      );
      _update(_state.copyWith(voice: voice));
      _receiveStreamGatewayEvent(event);
      final credentials = voice.credentials;
      if (credentials != null && credentials != _activeCredentials) {
        _activeCredentials = credentials;
        unawaited(_connectVoice(credentials));
      } else if (previousChannelId != null && voice.channelId == null) {
        unawaited(_closeConnections());
      }
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    await _stopVideoCapture();
    await _closeConnections();
    _disposed = true;
    await _states.close();
  }

  Future<void> reset() async {
    _ensureActive();
    await _stopVideoCapture();
    await _closeConnections();
    _update(const DiscordVoiceUiState());
  }

  Future<void> _enableCamera(
    DiscordVideoCaptureController capture,
    DiscordVideoGatewayConnection videoGateway,
    DiscordVoiceCredentials credentials,
    String guildId,
    String channelId,
  ) async {
    _update(
      _state.copyWith(
        video: _state.video.copyWith(
          phase: DiscordVideoPhase.starting,
          sourceKind: null,
          errorMessage: null,
        ),
        errorMessage: null,
      ),
    );
    try {
      final session = await capture.startCamera();
      await videoGateway.updateVoiceVideoState(
        guildId: guildId,
        channelId: channelId,
        selfMute: _state.voice.selfMute,
        selfDeaf: _state.voice.selfDeaf,
        selfVideo: true,
      );
      await _connectVoice(
        credentials,
        DiscordVoiceConnectionOptions.video(session.source),
      );
      _update(
        _state.copyWith(
          video: _state.video.copyWith(
            phase: DiscordVideoPhase.active,
            sourceKind: session.source.kind,
            errorMessage: null,
          ),
        ),
      );
    } on Object catch (error) {
      await capture.stop();
      _failVideo(error);
      rethrow;
    }
  }

  Future<void> _disableCamera(
    DiscordVideoGatewayConnection videoGateway,
    DiscordVoiceCredentials credentials,
    String guildId,
    String channelId,
  ) async {
    _update(
      _state.copyWith(
        video: _state.video.copyWith(phase: DiscordVideoPhase.stopping),
        errorMessage: null,
      ),
    );
    try {
      await videoGateway.updateVoiceVideoState(
        guildId: guildId,
        channelId: channelId,
        selfMute: _state.voice.selfMute,
        selfDeaf: _state.voice.selfDeaf,
        selfVideo: false,
      );
      await _stopVideoCapture();
      await _connectVoice(
        credentials,
        const DiscordVoiceConnectionOptions.audioOnly(),
      );
      _update(
        _state.copyWith(
          video: _state.video.copyWith(
            phase: DiscordVideoPhase.idle,
            sourceKind: null,
            errorMessage: null,
          ),
        ),
      );
    } on Object catch (error) {
      _failVideo(error);
      rethrow;
    }
  }

  Future<void> _stopVideoCapture() async {
    await _videoCapture?.stop();
    if (_state.video.phase != DiscordVideoPhase.idle) {
      _update(
        _state.copyWith(
          video: _state.video.copyWith(
            phase: DiscordVideoPhase.idle,
            sourceKind: null,
          ),
        ),
      );
    }
  }

  void _failVideo(Object error) {
    final message = _errorMessage(error);
    _update(
      _state.copyWith(
        video: _state.video.copyWith(
          phase: DiscordVideoPhase.failed,
          sourceKind: _state.video.sourceKind,
          errorMessage: message,
        ),
        errorMessage: message,
      ),
    );
  }

  Future<void> _setSelfAudio({
    required bool selfMute,
    required bool selfDeaf,
  }) async {
    _ensureActive();
    final voice = _state.voice;
    final guildId = voice.guildId;
    final channelId = voice.channelId;
    if (guildId == null || channelId == null) {
      throw StateError('참여 중인 음성 채널이 없습니다.');
    }
    try {
      await _mainGateway.updateVoiceState(
        guildId: guildId,
        channelId: channelId,
        selfMute: selfMute,
        selfDeaf: selfDeaf,
      );
      if (voice.selfMute != selfMute) {
        await _media?.setMuted(selfMute);
      }
      if (voice.selfDeaf != selfDeaf) {
        await _media?.setDeafened(selfDeaf);
      }
      _update(
        _state.copyWith(
          voice: voice.withSelfAudio(selfMute: selfMute, selfDeaf: selfDeaf),
          errorMessage: null,
        ),
      );
    } on Object catch (error) {
      _fail(error);
      rethrow;
    }
  }

  Future<void> _closeConnections() async {
    await _stopActiveStream(bestEffort: true);
    final inputMode = _state.media.inputMode;
    _generation += 1;
    _activeCredentials = null;
    await _disposeActiveConnections();
    _primaryRemotePreviews = const {};
    _update(
      _state.copyWith(
        networkPhase: DiscordVoiceNetworkPhase.disconnected,
        media: DiscordVoiceMediaState(inputMode: inputMode),
        video: _state.video.copyWith(remotePreviews: _mergedRemotePreviews),
      ),
    );
  }

  Future<void> _disposeActiveConnections() async {
    await _networkSubscription?.cancel();
    _networkSubscription = null;
    await _mediaResetWork;
    _mediaResetWork = null;
    await _mediaSubscription?.cancel();
    _mediaSubscription = null;
    final media = _media;
    _media = null;
    await media?.dispose();
    final network = _network;
    _network = null;
    await network?.dispose();
  }

  void _fail(Object error) {
    if (_disposed) {
      return;
    }
    final message = _errorMessage(error);
    _update(
      _state.copyWith(
        voice: _state.voice.withConnectionPhase(
          DiscordVoicePhase.failed,
          errorMessage: message,
        ),
        errorMessage: message,
      ),
    );
  }

  void _update(DiscordVoiceUiState nextState) {
    _state = nextState;
    if (!_states.isClosed) {
      _states.add(nextState);
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('이미 종료된 Voice coordinator입니다.');
    }
  }
}

String _errorMessage(Object error) {
  return error is FormatException
      ? error.message
      : error.toString().replaceFirst('Bad state: ', '');
}
