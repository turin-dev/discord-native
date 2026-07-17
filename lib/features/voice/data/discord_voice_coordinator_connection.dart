part of 'discord_voice_coordinator.dart';

extension DiscordVoiceCoordinatorConnection on DiscordVoiceCoordinator {
  Future<void> _connectVoice(
    DiscordVoiceCredentials credentials, [
    DiscordVoiceConnectionOptions options =
        const DiscordVoiceConnectionOptions.audioOnly(),
  ]) async {
    final generation = ++_generation;
    try {
      await _disposeActiveConnections();
      if (generation != _generation || _disposed) {
        return;
      }
      _primaryRemotePreviews = const {};
      _update(
        _state.copyWith(
          video: _state.video.copyWith(remotePreviews: _mergedRemotePreviews),
        ),
      );
      final network = _networkFactory();
      _network = network;
      _networkSubscription = network.states.listen(
        (networkState) =>
            _receiveNetworkState(network, networkState, generation),
        onError: _fail,
      );
      await network.connect(credentials, options: options);
    } on Object catch (error) {
      if (generation == _generation) {
        _fail(error);
      }
    }
  }

  void _receiveNetworkState(
    DiscordVoiceNetworkConnection network,
    DiscordVoiceNetworkState networkState,
    int generation,
  ) {
    if (generation != _generation || _disposed) {
      return;
    }
    var voice = _state.voice;
    if (networkState.phase == DiscordVoiceNetworkPhase.ready) {
      voice = voice.withConnectionPhase(DiscordVoicePhase.ready);
      unawaited(_startMedia(network, generation));
    } else if (networkState.phase == DiscordVoiceNetworkPhase.resuming) {
      voice = voice.withConnectionPhase(DiscordVoicePhase.reconnecting);
    } else if (networkState.phase == DiscordVoiceNetworkPhase.connecting &&
        _media != null) {
      voice = voice.withConnectionPhase(DiscordVoicePhase.reconnecting);
      _beginMediaReset(network, generation, restartWhenReady: true);
    } else if (networkState.phase == DiscordVoiceNetworkPhase.failed) {
      voice = voice.withConnectionPhase(
        DiscordVoicePhase.failed,
        errorMessage: networkState.errorMessage,
      );
      _beginMediaReset(network, generation, restartWhenReady: false);
    }
    _update(
      _state.copyWith(
        voice: voice,
        networkPhase: networkState.phase,
        errorMessage: networkState.errorMessage,
      ),
    );
  }

  Future<void> _startMedia(
    DiscordVoiceNetworkConnection network,
    int generation,
  ) async {
    if (_media != null || _mediaStarting || _mediaResetWork != null) {
      return;
    }
    _mediaStarting = true;
    try {
      final media = _mediaFactory(network.mediaNetwork);
      _media = media;
      _mediaSubscription = media.states.listen(
        _receiveMediaState,
        onError: _fail,
      );
      if (_state.media.inputMode != media.state.inputMode) {
        await media.setInputMode(_state.media.inputMode);
      }
      if (_state.voice.selfMute) {
        await media.setMuted(true);
      }
      if (_state.voice.selfDeaf) {
        await media.setDeafened(true);
      }
      await media.start();
      if (generation != _generation) {
        await media.dispose();
      }
    } on Object catch (error) {
      if (generation == _generation) {
        _fail(error);
      }
    } finally {
      _mediaStarting = false;
    }
  }

  void _beginMediaReset(
    DiscordVoiceNetworkConnection network,
    int generation, {
    required bool restartWhenReady,
  }) {
    if (_mediaResetWork != null || _media == null) {
      return;
    }
    final work = _resetMediaForNetworkChange(generation);
    _mediaResetWork = work;
    unawaited(
      work.whenComplete(() {
        if (identical(_mediaResetWork, work)) {
          _mediaResetWork = null;
        }
        if (restartWhenReady &&
            generation == _generation &&
            !_disposed &&
            network.state.phase == DiscordVoiceNetworkPhase.ready) {
          unawaited(_startMedia(network, generation));
        }
      }),
    );
  }

  Future<void> _resetMediaForNetworkChange(int generation) async {
    final inputMode = _state.media.inputMode;
    try {
      await _mediaSubscription?.cancel();
      _mediaSubscription = null;
      final media = _media;
      _media = null;
      _primaryRemotePreviews = const {};
      _update(
        _state.copyWith(
          media: DiscordVoiceMediaState(inputMode: inputMode),
          video: _state.video.copyWith(remotePreviews: _mergedRemotePreviews),
        ),
      );
      await media?.dispose();
    } on Object catch (error) {
      if (generation == _generation) {
        _fail(error);
      }
    }
  }

  void _receiveMediaState(DiscordVoiceMediaState mediaState) {
    _primaryRemotePreviews = Map.unmodifiable(mediaState.remoteVideoPreviews);
    var voice = _state.voice;
    if (mediaState.phase == DiscordVoiceMediaPhase.failed) {
      voice = voice.withConnectionPhase(
        DiscordVoicePhase.failed,
        errorMessage: mediaState.errorMessage,
      );
    }
    _update(
      _state.copyWith(
        voice: voice,
        media: mediaState,
        video: _state.video.copyWith(remotePreviews: _mergedRemotePreviews),
        errorMessage: mediaState.errorMessage,
      ),
    );
  }
}
