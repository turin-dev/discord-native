part of 'discord_voice_gateway_client.dart';

extension DiscordVoiceGatewayVideo on DiscordVoiceGatewayClient {
  Future<void> _receiveRtcReady(Map<String, Object?> data) async {
    final rtcTransport = _rtcTransport;
    final source = _connectionOptions.videoSource;
    if (rtcTransport == null) {
      throw StateError('WebRTC video transport가 설정되지 않았습니다.');
    }
    if (source != null) {
      _validateVideoSource(source);
    }
    final audioSsrc = _requiredInt(data['ssrc'], 'Voice Ready audio ssrc');
    final videoStream = DiscordVideoReadyStream.parse(data['streams']);
    final session = DiscordVoiceRtcSession(
      audioSsrc: audioSsrc,
      videoSsrc: videoStream.videoSsrc,
      rtxSsrc: videoStream.rtxSsrc,
      source: source,
    );
    _update(
      _state.copyWith(
        phase: DiscordVoiceNetworkPhase.selectingProtocol,
        ssrc: audioSsrc,
        videoSsrc: videoStream.videoSsrc,
        rtxSsrc: videoStream.rtxSsrc,
      ),
    );
    final offer = await rtcTransport.createOffer(session);
    _validateRtcOffer(offer);
    await _transport.sendJson({
      'op': 1,
      'd': {
        'protocol': 'webrtc',
        'codecs': DiscordVideoCodecCapabilities.gatewayPayload,
        'data': offer.sdp,
        'sdp': offer.sdp,
        'rtc_connection_id': offer.rtcConnectionId,
      },
    });
  }

  Future<void> _receiveRtcSessionDescription(Map<String, Object?> data) async {
    final credentials = _credentials;
    final rtcTransport = _rtcTransport;
    final audioSsrc = _state.ssrc;
    final videoSsrc = _state.videoSsrc;
    if (credentials == null ||
        rtcTransport == null ||
        audioSsrc == null ||
        videoSsrc == null) {
      throw const FormatException('WebRTC session 초기화 정보가 올바르지 않습니다.');
    }
    final daveVersion = _requiredInt(
      data['dave_protocol_version'],
      'DAVE protocol version',
    );
    final groupId = int.tryParse(credentials.channelId);
    if (daveVersion < 0 ||
        daveVersion > _maxDaveProtocolVersion ||
        groupId == null) {
      throw const FormatException('WebRTC DAVE session 정보가 올바르지 않습니다.');
    }
    final videoCodec = DiscordVideoCodec.parse(
      _requiredString(data['video_codec'], 'Voice video codec'),
    );
    final audioCodec = _requiredString(
      data['audio_codec'],
      'Voice audio codec',
    );
    final remoteSdp = _requiredString(data['sdp'], 'Voice remote SDP');
    await _dave.initialize(
      protocolVersion: daveVersion,
      groupId: groupId,
      selfUserId: credentials.userId,
    );
    _dave.assignLocalAudioSsrc(audioSsrc);
    _dave.session.assignLocalVideoSsrc(
      videoSsrc,
      codec: _daveCodec(videoCodec),
    );
    await rtcTransport.acceptAnswer(
      DiscordVoiceRtcAnswer(
        sdp: remoteSdp,
        audioCodec: audioCodec,
        videoCodec: videoCodec,
        daveSession: _dave.session,
      ),
    );
    _reconnectAttempt = 0;
    _update(
      _state.copyWith(
        phase: DiscordVoiceNetworkPhase.ready,
        daveProtocolVersion: daveVersion,
        videoCodec: videoCodec,
        errorMessage: null,
      ),
    );
  }

  Future<void> setVideoEnabled(bool enabled) async {
    _ensureActive();
    final source = _connectionOptions.videoSource;
    final audioSsrc = _state.ssrc;
    final videoSsrc = _state.videoSsrc;
    final rtxSsrc = _state.rtxSsrc;
    if (_state.phase != DiscordVoiceNetworkPhase.ready ||
        source == null ||
        audioSsrc == null ||
        videoSsrc == null ||
        rtxSsrc == null) {
      throw StateError('WebRTC video session이 준비되지 않았습니다.');
    }
    await _transport.sendJson({
      'op': 12,
      'd': enabled
          ? _enabledVideoPayload(source, audioSsrc, videoSsrc, rtxSsrc)
          : {
              'audio_ssrc': audioSsrc,
              'video_ssrc': 0,
              'rtx_ssrc': 0,
              'streams': const <Object>[],
            },
    });
  }
}

Map<String, Object?> _enabledVideoPayload(
  DiscordVideoSource source,
  int audioSsrc,
  int videoSsrc,
  int rtxSsrc,
) {
  return {
    'audio_ssrc': audioSsrc,
    'video_ssrc': videoSsrc,
    'rtx_ssrc': rtxSsrc,
    'streams': [
      {
        'type': 'video',
        'rid': '100',
        'ssrc': videoSsrc,
        'active': true,
        'quality': 100,
        'rtx_ssrc': rtxSsrc,
        'max_bitrate': 10000000,
        'max_framerate': source.framesPerSecond,
        'max_resolution': {
          'type': 'fixed',
          'width': source.width,
          'height': source.height,
        },
      },
    ],
  };
}

DiscordDaveVideoCodec _daveCodec(DiscordVideoCodec codec) {
  return switch (codec) {
    DiscordVideoCodec.h264 => DiscordDaveVideoCodec.h264,
  };
}

void _validateVideoSource(DiscordVideoSource source) {
  if (source.sourceId.trim().isEmpty) {
    throw const FormatException('Video source ID가 필요합니다.');
  }
  if (source.width < 160 ||
      source.width > 3840 ||
      source.height < 90 ||
      source.height > 2160 ||
      source.framesPerSecond < 1 ||
      source.framesPerSecond > 60) {
    throw const FormatException('Video source 해상도 또는 frame rate가 올바르지 않습니다.');
  }
}

void _validateRtcOffer(DiscordVoiceRtcOffer offer) {
  if (offer.sdp.trim().isEmpty || offer.rtcConnectionId.trim().isEmpty) {
    throw const FormatException('WebRTC local offer 정보가 올바르지 않습니다.');
  }
}
