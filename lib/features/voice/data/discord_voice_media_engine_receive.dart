part of 'discord_voice_media_engine.dart';

extension DiscordVoiceMediaEngineReceive on DiscordVoiceMediaEngine {
  Future<void> _receivePacket(Uint8List packet) async {
    if (_state.phase != DiscordVoiceMediaPhase.active ||
        _state.deafened ||
        !_isOpusRtp(packet)) {
      return;
    }
    final decoded = await _rtp!.decryptAudio(packet);
    await _playEncryptedOpus(
      ssrc: decoded.ssrc,
      sequence: decoded.sequence,
      encryptedOpus: decoded.opusFrame,
    );
  }

  Future<void> _receiveRtcAudio(DiscordVoiceRtcAudioFrame frame) async {
    if (_state.phase != DiscordVoiceMediaPhase.active || _state.deafened) {
      return;
    }
    await _playEncryptedOpus(
      ssrc: frame.ssrc,
      sequence: frame.sequence,
      encryptedOpus: frame.encryptedOpus,
    );
  }

  Future<void> _receiveRtcVideo(DiscordVoiceRtcVideoFrame frame) async {
    if (_state.phase != DiscordVoiceMediaPhase.active) {
      return;
    }
    final userId = _videoUsersBySsrc[frame.ssrc];
    if (userId == null) {
      _bufferPendingVideoFrame(frame);
      return;
    }
    final clearH264 = _network.unprotectVideo(
      frame.encryptedH264,
      remoteUserId: userId,
    );
    await _network.renderRtcVideo(
      clearH264,
      ssrc: frame.ssrc,
      timestamp: frame.timestamp,
    );
  }

  Future<void> _receiveRtcVideoStream(DiscordVoiceRtcVideoStream stream) async {
    _videoPreviewsBySsrc = Map.unmodifiable({
      ..._videoPreviewsBySsrc,
      stream.ssrc: stream.preview,
    });
    _publishRemoteVideoPreviews();
  }

  Future<void> _replaceVideoUsers(Map<int, String> users) async {
    _videoUsersBySsrc = Map.unmodifiable(users);
    _publishRemoteVideoPreviews();
    for (final ssrc in _videoUsersBySsrc.keys) {
      final pending = _pendingVideoFramesBySsrc[ssrc];
      if (pending == null) {
        continue;
      }
      _pendingVideoFramesBySsrc = Map.unmodifiable(
        Map<int, List<DiscordVoiceRtcVideoFrame>>.fromEntries(
          _pendingVideoFramesBySsrc.entries.where((entry) => entry.key != ssrc),
        ),
      );
      for (final frame in pending) {
        await _receiveRtcVideo(frame);
      }
    }
  }

  void _bufferPendingVideoFrame(DiscordVoiceRtcVideoFrame frame) {
    const maximumPendingFrames = 120;
    final current = _pendingVideoFramesBySsrc[frame.ssrc] ?? const [];
    final appended = List<DiscordVoiceRtcVideoFrame>.unmodifiable([
      ...current,
      frame,
    ]);
    final bounded = appended.length <= maximumPendingFrames
        ? appended
        : List<DiscordVoiceRtcVideoFrame>.unmodifiable(
            appended.sublist(appended.length - maximumPendingFrames),
          );
    _pendingVideoFramesBySsrc = Map.unmodifiable({
      ..._pendingVideoFramesBySsrc,
      frame.ssrc: bounded,
    });
  }

  void _publishRemoteVideoPreviews() {
    final previews = <String, Object>{
      for (final entry in _videoUsersBySsrc.entries)
        entry.value: ?_videoPreviewsBySsrc[entry.key],
    };
    _update(_state.copyWith(remoteVideoPreviews: Map.unmodifiable(previews)));
  }

  Future<void> _playEncryptedOpus({
    required int ssrc,
    required int sequence,
    required Uint8List encryptedOpus,
  }) async {
    final userId = _usersBySsrc[ssrc];
    if (userId == null) {
      return;
    }
    final missingCount = _missingPacketCount(userId, sequence);
    for (var index = 0; index < min(missingCount, 5); index += 1) {
      await _playback.addPcm(
        userId,
        _opus.decodePacketLoss(remoteUserId: userId),
      );
    }
    final opusFrame = _network.unprotectAudio(
      encryptedOpus,
      remoteUserId: userId,
    );
    await _playback.addPcm(
      userId,
      _opus.decode(opusFrame, remoteUserId: userId),
    );
  }

  int _missingPacketCount(String userId, int sequence) {
    final previous = _lastSequenceByUser[userId];
    _lastSequenceByUser = Map.unmodifiable({
      ..._lastSequenceByUser,
      userId: sequence,
    });
    if (previous == null) {
      return 0;
    }
    final distance = (sequence - previous) & 0xFFFF;
    if (distance == 0 || distance > 0x7FFF) {
      return 0;
    }
    return distance - 1;
  }

  Future<void> _replaceUsers(Map<int, String> users) async {
    final nextUsers = Map<int, String>.unmodifiable(users);
    final removedUsers = _usersBySsrc.values.toSet().difference(
      nextUsers.values.toSet(),
    );
    _usersBySsrc = nextUsers;
    for (final userId in removedUsers) {
      _opus.removeRemoteUser(userId);
      await _playback.removeUser(userId);
      _lastSequenceByUser = Map.unmodifiable(
        Map<String, int>.fromEntries(
          _lastSequenceByUser.entries.where((entry) => entry.key != userId),
        ),
      );
    }
  }
}
