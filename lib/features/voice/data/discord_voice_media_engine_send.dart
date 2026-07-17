part of 'discord_voice_media_engine.dart';

extension DiscordVoiceMediaEngineSend on DiscordVoiceMediaEngine {
  Future<void> _sendPcmChunk(Uint8List chunk) async {
    if (_state.phase != DiscordVoiceMediaPhase.active || _state.muted) {
      return;
    }
    for (final frame in _frameAssembler.add(chunk)) {
      final decision = _inputGate.evaluate(
        frame,
        inputMode: _state.inputMode,
        pushToTalkPressed: _state.pushToTalkPressed,
        currentlySpeaking: _state.speaking,
      );
      switch (decision) {
        case DiscordVoiceInputDecision.send:
          await _sendOpus(_opus.encode(frame), announceSpeaking: true);
        case DiscordVoiceInputDecision.drop:
          continue;
        case DiscordVoiceInputDecision.stop:
          await _stopSpeaking();
      }
    }
  }

  Future<void> _sendOpus(
    Uint8List opusFrame, {
    required bool announceSpeaking,
  }) async {
    if (announceSpeaking && !_state.speaking) {
      await _network.setSpeaking(true);
      _update(_state.copyWith(speaking: true));
    }
    final session = _network.session;
    if (session.usesWebRtc) {
      await _network.sendRtcAudio(opusFrame);
      return;
    }
    final rtp = _rtp;
    if (rtp == null) {
      throw StateError('Voice RTP codec이 준비되지 않았습니다.');
    }
    final protectedFrame = _network.protectAudio(opusFrame);
    final packet = await rtp.encryptAudio(
      opusFrame: protectedFrame,
      sequence: _sequence,
      timestamp: _timestamp,
      ssrc: session.ssrc,
      nonceCounter: _nonce,
    );
    await _network.sendUdp(packet);
    _advanceCounters();
  }

  Future<void> _stopSpeaking({bool bestEffort = false}) async {
    if (!_state.speaking) {
      return;
    }
    try {
      for (var index = 0; index < 5; index += 1) {
        await _sendOpus(_silenceFrame, announceSpeaking: false);
      }
      await _network.setSpeaking(false);
    } on Object catch (error) {
      _reportError(error);
      if (!bestEffort) {
        rethrow;
      }
    }
    _update(_state.copyWith(speaking: false));
  }

  void _advanceCounters() {
    _sequence = (_sequence + 1) & 0xFFFF;
    _timestamp =
        (_timestamp + DiscordPcmFrameAssembler.samplesPerChannel) & 0xFFFFFFFF;
    _nonce = (_nonce + 1) & 0xFFFFFFFF;
  }
}
