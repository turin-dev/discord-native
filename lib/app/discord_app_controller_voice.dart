part of 'discord_app_controller.dart';

extension DiscordAppControllerVoice on DiscordAppController {
  void _subscribeToVoice() {
    final coordinator = _voiceCoordinator;
    if (coordinator == null) {
      return;
    }
    _voiceStateSubscription ??= coordinator.states.listen(
      (voiceState) => _update(_state.copyWith(voiceUiState: voiceState)),
      onError: _showFailure,
    );
  }

  Future<void> joinVoiceChannel(String channelId) async {
    final coordinator = _requireVoiceCoordinator();
    final channel = _state.workspace.channelById(channelId);
    if (channel == null || !channel.isVoiceChannel) {
      throw const FormatException('참여할 음성 채널이 올바르지 않습니다.');
    }
    await coordinator.join(guildId: channel.guildId, channelId: channel.id);
  }

  Future<void> leaveVoiceChannel() async {
    await _requireVoiceCoordinator().leave();
  }

  Future<void> setVoiceMuted(bool muted) async {
    await _requireVoiceCoordinator().setMuted(muted);
  }

  Future<void> setVoiceDeafened(bool deafened) async {
    await _requireVoiceCoordinator().setDeafened(deafened);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    await _requireVoiceCoordinator().setCameraEnabled(enabled);
  }

  Future<void> setScreenShareEnabled(bool enabled) async {
    await _requireVoiceCoordinator().setScreenShareEnabled(enabled);
  }

  Future<void> setScreenSharePaused(bool paused) async {
    await _requireVoiceCoordinator().setScreenSharePaused(paused);
  }

  Future<void> watchVoiceStream(String streamKey) async {
    await _requireVoiceCoordinator().watchStream(streamKey);
  }

  Future<void> stopWatchingVoiceStream() async {
    await _requireVoiceCoordinator().stopWatchingStream();
  }

  Future<void> setVoiceInputMode(DiscordVoiceInputMode inputMode) async {
    await _requireVoiceCoordinator().setInputMode(inputMode);
  }

  Future<void> setPushToTalkPressed(bool pressed) async {
    await _requireVoiceCoordinator().setPushToTalkPressed(pressed);
  }

  void setVoiceUserVolume(String userId, double volume) {
    _requireVoiceCoordinator().setUserVolume(userId, volume);
  }

  DiscordVoiceCoordinator _requireVoiceCoordinator() {
    final coordinator = _voiceCoordinator;
    if (coordinator == null) {
      throw StateError('Voice 기능이 구성되지 않았습니다.');
    }
    return coordinator;
  }
}
