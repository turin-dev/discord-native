part of 'discord_voice_gateway_client.dart';

enum _VoiceReconnectMode { resume, identify }

extension DiscordVoiceGatewayReconnect on DiscordVoiceGatewayClient {
  _VoiceReconnectMode get _preferredReconnectMode {
    if (_connectionOptions.usesWebRtc) {
      return _state.ssrc != null && _state.daveProtocolVersion != null
          ? _VoiceReconnectMode.resume
          : _VoiceReconnectMode.identify;
    }
    return _state.ssrc != null &&
            _state.secretKey != null &&
            _state.encryptionMode != null
        ? _VoiceReconnectMode.resume
        : _VoiceReconnectMode.identify;
  }

  void _handleClose(int? code) {
    if (_disposed ||
        _credentials == null ||
        _state.phase == DiscordVoiceNetworkPhase.disconnected ||
        _state.phase == DiscordVoiceNetworkPhase.failed) {
      return;
    }
    if (_terminalVoiceCloseCodes.contains(code)) {
      _fail(StateError('Voice Gateway 연결이 종료되었습니다. ($code)'));
      return;
    }
    final mode = _freshVoiceCloseCodes.contains(code)
        ? _VoiceReconnectMode.identify
        : _preferredReconnectMode;
    _startReconnect(mode);
  }

  void _handleTransportError(Object error, StackTrace stackTrace) {
    if (_disposed || _credentials == null) {
      return;
    }
    _startReconnect(_preferredReconnectMode);
  }

  void _startReconnect(_VoiceReconnectMode mode) {
    if (_disposed || _credentials == null) {
      return;
    }
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      _fail(StateError('Voice Gateway 재연결 횟수를 초과했습니다.'));
      return;
    }
    _reconnectAttempt += 1;
    if (_reconnectWork != null) {
      if (mode == _VoiceReconnectMode.identify) {
        _queuedReconnectMode = mode;
      }
      return;
    }
    _heartbeatTask?.cancel();
    _heartbeatTask = null;
    _update(
      _state.copyWith(
        phase: mode == _VoiceReconnectMode.resume
            ? DiscordVoiceNetworkPhase.resuming
            : DiscordVoiceNetworkPhase.connecting,
        awaitingHeartbeatAck: false,
        errorMessage: null,
      ),
    );
    final work = _recoverConnection(mode);
    _reconnectWork = work;
    unawaited(
      work
          .then<void>((_) {})
          .catchError((Object error) {
            _fail(error);
          })
          .whenComplete(() {
            _reconnectWork = null;
            final queued = _queuedReconnectMode;
            _queuedReconnectMode = null;
            if (queued != null) {
              _startReconnect(queued);
            }
          }),
    );
  }

  Future<void> _recoverConnection(_VoiceReconnectMode mode) async {
    while (!_disposed && _credentials != null) {
      try {
        await _reconnect(mode);
        return;
      } on Object catch (error) {
        if (_reconnectAttempt >= _maxReconnectAttempts) {
          _fail(StateError('Voice Gateway 재연결에 실패했습니다: $error'));
          return;
        }
        final delay = _reconnectBackoffPolicy.delayForAttempt(
          _reconnectAttempt - 1,
        );
        await _reconnectDelay(delay);
        if (_disposed || _credentials == null) {
          return;
        }
        _reconnectAttempt += 1;
      }
    }
  }

  Future<void> _reconnect(_VoiceReconnectMode mode) async {
    final credentials = _credentials;
    if (credentials == null) {
      return;
    }
    await _closeWebSocket();
    if (!identical(_credentials, credentials) || _disposed) {
      return;
    }
    if (mode == _VoiceReconnectMode.identify) {
      await _udp.close();
      await _rtcTransport?.close();
      _dave.resetConnectionState();
      _update(
        DiscordVoiceNetworkState(phase: DiscordVoiceNetworkPhase.connecting),
      );
    }
    await _openWebSocket(_voiceGatewayUri(credentials));
    if (!identical(_credentials, credentials) || _disposed) {
      return;
    }
    if (mode == _VoiceReconnectMode.resume) {
      await _resume(credentials);
    } else {
      await _identify(credentials);
    }
  }

  Future<void> _resume(DiscordVoiceCredentials credentials) async {
    await _transport.sendJson({
      'op': 7,
      'd': {
        'server_id': credentials.guildId,
        'session_id': credentials.sessionId,
        'token': credentials.token,
        'seq_ack': _state.sequence,
      },
    });
    _update(_state.copyWith(phase: DiscordVoiceNetworkPhase.resuming));
  }
}

Uri _voiceGatewayUri(DiscordVoiceCredentials credentials) {
  final endpoint = credentials.endpoint.trim();
  if (endpoint.isEmpty) {
    throw const FormatException('Voice Gateway endpoint가 필요합니다.');
  }
  return Uri.parse('wss://$endpoint?v=8');
}

const Set<int?> _freshVoiceCloseCodes = {4006, 4009};

const Set<int?> _terminalVoiceCloseCodes = {
  4001,
  4002,
  4003,
  4004,
  4005,
  4011,
  4012,
  4014,
  4016,
  4017,
  4020,
  4021,
  4022,
};
