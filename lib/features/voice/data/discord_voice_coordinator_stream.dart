part of 'discord_voice_coordinator.dart';

enum _DiscordStreamIntent { broadcast, watch }

extension DiscordVoiceCoordinatorStream on DiscordVoiceCoordinator {
  Map<String, Object> get _mergedRemotePreviews =>
      Map.unmodifiable({..._primaryRemotePreviews, ..._streamRemotePreviews});

  Future<void> setScreenShareEnabled(bool enabled) async {
    _ensureActive();
    final phase = _state.video.screenSharePhase;
    if (enabled &&
        (phase == DiscordVideoPhase.starting ||
            phase == DiscordVideoPhase.active)) {
      return;
    }
    if (!enabled && phase == DiscordVideoPhase.idle) {
      return;
    }
    if (enabled) {
      await _startScreenShare();
      return;
    }
    await _stopActiveStream(bestEffort: false);
  }

  Future<void> setScreenSharePaused(bool paused) async {
    _ensureActive();
    final streamKey = _state.video.screenStreamKey;
    final gateway = _mainGateway;
    if (!_state.video.screenShareEnabled ||
        streamKey == null ||
        gateway is! DiscordVideoGatewayConnection) {
      throw StateError('일시 정지할 Go Live 화면 공유가 없습니다.');
    }
    final videoGateway = gateway as DiscordVideoGatewayConnection;
    await _screenCapture?.setPaused(paused);
    await videoGateway.setStreamPaused(streamKey: streamKey, paused: paused);
    _update(
      _state.copyWith(
        video: _state.video.copyWith(screenPaused: paused),
        errorMessage: null,
      ),
    );
  }

  Future<void> watchStream(String streamKey) async {
    _ensureActive();
    final gateway = _mainGateway;
    if (gateway is! DiscordVideoGatewayConnection) {
      throw StateError('Go Live 시청 기능이 구성되지 않았습니다.');
    }
    final videoGateway = gateway as DiscordVideoGatewayConnection;
    _requireActiveVoiceSession();
    final normalized = _normalizeStreamKey(streamKey);
    if (_state.video.watchingStreamKey == normalized &&
        _streamNetwork != null) {
      return;
    }
    await _stopActiveStream(bestEffort: true);
    _streamIntent = _DiscordStreamIntent.watch;
    _streamState = DiscordStreamState(requestedStreamKey: normalized);
    _streamSource = null;
    _update(
      _state.copyWith(
        video: _state.video.copyWith(watchingStreamKey: normalized),
        errorMessage: null,
      ),
    );
    try {
      await videoGateway.watchStream(normalized);
    } on Object catch (error) {
      await _disposeStreamResources(stopCapture: false);
      _failStream(error);
      rethrow;
    }
  }

  Future<void> stopWatchingStream() async {
    if (_streamIntent != _DiscordStreamIntent.watch) {
      return;
    }
    await _stopActiveStream(bestEffort: false);
  }

  void _receiveStreamGatewayEvent(Map<String, Object?> event) {
    final current = _streamState;
    if (current == null) {
      return;
    }
    final next = current.receiveGatewayEvent(event);
    if (identical(next, current)) {
      return;
    }
    _streamState = next;
    if (_streamIntent == _DiscordStreamIntent.broadcast) {
      _update(
        _state.copyWith(
          video: _state.video.copyWith(screenPaused: next.paused),
        ),
      );
    }
    if (next.deleteReason != null) {
      unawaited(_handleStreamDeleted(next.deleteReason!));
      return;
    }
    if (next.endpoint == null && current.endpoint != null) {
      unawaited(_disposeStreamResources(stopCapture: false));
      return;
    }
    unawaited(_connectStreamIfReady(next));
  }

  Future<void> _startScreenShare() async {
    final voice = _requireActiveVoiceSession();
    final gateway = _mainGateway;
    final capture = _screenCapture;
    if (gateway is! DiscordVideoGatewayConnection || capture == null) {
      throw StateError('Go Live 화면 공유 기능이 구성되지 않았습니다.');
    }
    final videoGateway = gateway as DiscordVideoGatewayConnection;
    await _stopActiveStream(bestEffort: true);
    final streamKey =
        'guild:${voice.guildId}:${voice.channelId}:${voice.userId}';
    _streamIntent = _DiscordStreamIntent.broadcast;
    _streamState = DiscordStreamState(requestedStreamKey: streamKey);
    _update(
      _state.copyWith(
        video: _state.video.copyWith(
          screenSharePhase: DiscordVideoPhase.starting,
          screenStreamKey: streamKey,
          screenPaused: false,
          watchingStreamKey: null,
        ),
        errorMessage: null,
      ),
    );
    try {
      final session = await capture.startScreen();
      if (session.source.kind != DiscordVideoSourceKind.screen) {
        throw StateError('Go Live capture source가 화면 공유가 아닙니다.');
      }
      _streamSource = session.source;
      await videoGateway.createStream(
        guildId: voice.guildId,
        channelId: voice.channelId,
      );
    } on Object catch (error) {
      await _disposeStreamResources(stopCapture: true);
      _failStream(error);
      rethrow;
    }
  }

  DiscordVoiceCredentials _requireActiveVoiceSession() {
    final credentials = _activeCredentials;
    if (credentials == null || _state.voice.phase != DiscordVoicePhase.ready) {
      throw StateError('Go Live를 사용할 음성 연결이 준비되지 않았습니다.');
    }
    return credentials;
  }

  Future<void> _connectStreamIfReady(DiscordStreamState streamState) async {
    final voice = _state.voice;
    final userId = voice.currentUserId;
    final sessionId = voice.sessionId;
    if (userId == null || sessionId == null) {
      return;
    }
    final credentials = streamState.credentials(
      userId: userId,
      sessionId: sessionId,
    );
    if (credentials == null || credentials == _activeStreamCredentials) {
      return;
    }
    await _disposeStreamResources(stopCapture: false);
    if (_streamState != streamState || _streamIntent == null) {
      return;
    }
    final generation = ++_streamGeneration;
    final network = _streamNetworkFactory();
    _activeStreamCredentials = credentials;
    _streamNetwork = network;
    _streamNetworkSubscription = network.states.listen(
      (state) => _receiveStreamNetworkState(network, state, generation),
      onError: _failStream,
    );
    final source = _streamSource;
    final options = _streamIntent == _DiscordStreamIntent.broadcast
        ? DiscordVoiceConnectionOptions.video(source!)
        : const DiscordVoiceConnectionOptions.receiveVideo();
    try {
      await network.connect(credentials, options: options);
    } on Object catch (error) {
      if (generation == _streamGeneration) {
        _failStream(error);
      }
    }
  }

  void _receiveStreamNetworkState(
    DiscordVoiceNetworkConnection network,
    DiscordVoiceNetworkState networkState,
    int generation,
  ) {
    if (network != _streamNetwork || generation != _streamGeneration) {
      return;
    }
    if (networkState.phase == DiscordVoiceNetworkPhase.ready) {
      if (_streamIntent == _DiscordStreamIntent.broadcast) {
        _update(
          _state.copyWith(
            video: _state.video.copyWith(
              screenSharePhase: DiscordVideoPhase.active,
              screenStreamKey: _streamState?.requestedStreamKey,
              screenPaused: _streamState?.paused ?? false,
            ),
            errorMessage: null,
          ),
        );
      } else {
        unawaited(_startStreamMedia(network, generation));
      }
    } else if (networkState.phase == DiscordVoiceNetworkPhase.failed) {
      _failStream(networkState.errorMessage ?? 'Go Live Voice 연결에 실패했습니다.');
    }
  }

  Future<void> _startStreamMedia(
    DiscordVoiceNetworkConnection network,
    int generation,
  ) async {
    if (_streamMedia != null || generation != _streamGeneration) {
      return;
    }
    try {
      final media = _streamMediaFactory(network.mediaNetwork);
      _streamMedia = media;
      _streamMediaSubscription = media.states.listen(
        _receiveStreamMediaState,
        onError: _failStream,
      );
      await media.start();
      if (generation != _streamGeneration) {
        await media.dispose();
      }
    } on Object catch (error) {
      if (generation == _streamGeneration) {
        _failStream(error);
      }
    }
  }

  void _receiveStreamMediaState(DiscordVoiceMediaState mediaState) {
    _streamRemotePreviews = Map.unmodifiable(mediaState.remoteVideoPreviews);
    _update(
      _state.copyWith(
        video: _state.video.copyWith(remotePreviews: _mergedRemotePreviews),
        errorMessage: mediaState.errorMessage,
      ),
    );
  }

  Future<void> _stopActiveStream({required bool bestEffort}) async {
    final streamKey = _streamState?.requestedStreamKey;
    Object? deleteError;
    if (streamKey != null && _mainGateway is DiscordVideoGatewayConnection) {
      try {
        await (_mainGateway as DiscordVideoGatewayConnection).deleteStream(
          streamKey,
        );
      } on Object catch (error) {
        deleteError = error;
      }
    }
    final stopCapture = _streamIntent == _DiscordStreamIntent.broadcast;
    await _disposeStreamResources(stopCapture: stopCapture);
    _clearStreamState();
    if (deleteError != null && !bestEffort) {
      throw StateError('Go Live 연결을 종료하지 못했습니다: $deleteError');
    }
  }

  Future<void> _handleStreamDeleted(String reason) async {
    final stopCapture = _streamIntent == _DiscordStreamIntent.broadcast;
    await _disposeStreamResources(stopCapture: stopCapture);
    _clearStreamState();
    if (reason != 'user_requested' && reason != 'stream_ended') {
      _failStream('Go Live가 종료되었습니다: $reason');
    }
  }

  Future<void> _disposeStreamResources({required bool stopCapture}) async {
    _streamGeneration += 1;
    _activeStreamCredentials = null;
    await _streamNetworkSubscription?.cancel();
    _streamNetworkSubscription = null;
    await _streamMediaSubscription?.cancel();
    _streamMediaSubscription = null;
    final media = _streamMedia;
    _streamMedia = null;
    await media?.dispose();
    final network = _streamNetwork;
    _streamNetwork = null;
    await network?.dispose();
    if (stopCapture) {
      await _screenCapture?.stop();
    }
    _streamRemotePreviews = const {};
  }

  void _clearStreamState() {
    _streamState = null;
    _streamIntent = null;
    _streamSource = null;
    _update(
      _state.copyWith(
        video: _state.video.copyWith(
          screenSharePhase: DiscordVideoPhase.idle,
          screenStreamKey: null,
          screenPaused: false,
          watchingStreamKey: null,
          remotePreviews: _mergedRemotePreviews,
        ),
      ),
    );
  }

  void _failStream(Object error) {
    if (_disposed) {
      return;
    }
    final message = _errorMessage(error);
    final isBroadcast = _streamIntent == _DiscordStreamIntent.broadcast;
    _update(
      _state.copyWith(
        video: _state.video.copyWith(
          screenSharePhase: isBroadcast
              ? DiscordVideoPhase.failed
              : _state.video.screenSharePhase,
          errorMessage: message,
        ),
        errorMessage: message,
      ),
    );
  }
}

String _normalizeStreamKey(String value) {
  final normalized = value.trim();
  final parts = normalized.split(':');
  final scope = parts.isEmpty ? null : parts.first;
  final expectedLength = scope == 'guild' ? 4 : 3;
  if ((scope != 'guild' && scope != 'call') ||
      parts.length != expectedLength ||
      parts.skip(1).any((part) => int.tryParse(part) == null)) {
    throw const FormatException('Go Live stream key 형식이 올바르지 않습니다.');
  }
  return normalized;
}
