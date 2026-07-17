part of 'discord_voice_gateway_client.dart';

extension DiscordVoiceGatewayMessages on DiscordVoiceGatewayClient {
  Future<void> _receive(Object? message) async {
    try {
      if (message is Uint8List || message is List<int>) {
        await _receiveBinary(Uint8List.fromList(message as List<int>));
        return;
      }
      final payload = _decodeJson(message);
      final sequence = payload['seq'];
      if (sequence is int) {
        _update(_state.copyWith(sequence: sequence));
      }
      switch (payload['op']) {
        case 8:
          _receiveHello(_readMap(payload['d'], 'Voice Hello data'));
        case 6:
          _update(_state.copyWith(awaitingHeartbeatAck: false));
        case 2:
          await _receiveReady(_readMap(payload['d'], 'Voice Ready data'));
        case 4:
          await _receiveSessionDescription(
            _readMap(payload['d'], 'Voice Session Description data'),
          );
        case 9:
          _reconnectAttempt = 0;
          _update(
            _state.copyWith(
              phase: DiscordVoiceNetworkPhase.ready,
              awaitingHeartbeatAck: false,
              errorMessage: null,
            ),
          );
        case 5:
          _receiveSpeaking(_readMap(payload['d'], 'Voice Speaking data'));
        case 12:
          _receiveVideo(_readMap(payload['d'], 'Voice Video data'));
        case 11:
        case 13:
          if (payload['op'] == 13) {
            _removeRemoteUser(
              _requiredString(
                _readMap(payload['d'], 'Voice DAVE data')['user_id'],
                'Voice user_id',
              ),
            );
          }
        case 21:
        case 22:
        case 24:
          await _dave.handleJson(
            _requiredInt(payload['op'], 'Voice opcode'),
            _readMap(payload['d'], 'Voice DAVE data'),
          );
      }
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _receiveVideo(Map<String, Object?> data) {
    final userId = _requiredString(data['user_id'], 'Voice Video user_id');
    final audioSsrc = _requiredInt(
      data['audio_ssrc'],
      'Voice Video audio_ssrc',
    );
    final videoSsrc = _requiredInt(
      data['video_ssrc'],
      'Voice Video video_ssrc',
    );
    if (int.tryParse(userId) == null ||
        audioSsrc < 0 ||
        audioSsrc > 0xFFFFFFFF ||
        videoSsrc < 0 ||
        videoSsrc > 0xFFFFFFFF) {
      throw const FormatException('Voice Video 사용자 정보가 올바르지 않습니다.');
    }
    final audioUsers = Map<int, String>.fromEntries(
      _state.usersBySsrc.entries.where((entry) => entry.value != userId),
    );
    final videoUsers = Map<int, String>.fromEntries(
      _state.videoUsersBySsrc.entries.where((entry) => entry.value != userId),
    );
    _update(
      _state.copyWith(
        usersBySsrc: audioSsrc == 0
            ? audioUsers
            : {...audioUsers, audioSsrc: userId},
        videoUsersBySsrc: videoSsrc == 0
            ? videoUsers
            : {...videoUsers, videoSsrc: userId},
      ),
    );
  }

  void _receiveSpeaking(Map<String, Object?> data) {
    final ssrc = _requiredInt(data['ssrc'], 'Voice Speaking ssrc');
    final userId = _requiredString(data['user_id'], 'Voice Speaking user_id');
    if (ssrc < 0 || ssrc > 0xFFFFFFFF || int.tryParse(userId) == null) {
      throw const FormatException('Voice Speaking 사용자 정보가 올바르지 않습니다.');
    }
    final retained = Map<int, String>.fromEntries(
      _state.usersBySsrc.entries.where((entry) => entry.value != userId),
    );
    _update(_state.copyWith(usersBySsrc: {...retained, ssrc: userId}));
  }

  void _removeRemoteUser(String userId) {
    _update(
      _state.copyWith(
        usersBySsrc: Map<int, String>.fromEntries(
          _state.usersBySsrc.entries.where((entry) => entry.value != userId),
        ),
        videoUsersBySsrc: Map<int, String>.fromEntries(
          _state.videoUsersBySsrc.entries.where(
            (entry) => entry.value != userId,
          ),
        ),
      ),
    );
  }

  void _receiveHello(Map<String, Object?> data) {
    final interval = _requiredInt(
      data['heartbeat_interval'],
      'Voice heartbeat_interval',
    );
    if (interval <= 0) {
      throw const FormatException('Voice heartbeat_interval이 올바르지 않습니다.');
    }
    _heartbeatTask?.cancel();
    _heartbeatTask = _heartbeatScheduler.schedule(
      Duration(milliseconds: interval),
      _sendHeartbeat,
    );
  }

  Future<void> _sendHeartbeat() async {
    if (_state.awaitingHeartbeatAck) {
      _startReconnect(_preferredReconnectMode);
      return;
    }
    await _transport.sendJson({
      'op': 3,
      'd': {'t': _nowMilliseconds(), 'seq_ack': _state.sequence},
    });
    _update(_state.copyWith(awaitingHeartbeatAck: true));
  }

  Future<void> _receiveReady(Map<String, Object?> data) async {
    if (_connectionOptions.usesWebRtc) {
      await _receiveRtcReady(data);
      return;
    }
    final ssrc = _requiredInt(data['ssrc'], 'Voice Ready ssrc');
    final address = _requiredString(data['ip'], 'Voice Ready ip');
    final port = _requiredInt(data['port'], 'Voice Ready port');
    final modes = _requiredStrings(data['modes'], 'Voice Ready modes');
    final mode = _chooseEncryptionMode(modes);
    _update(
      _state.copyWith(
        phase: DiscordVoiceNetworkPhase.discoveringUdp,
        ssrc: ssrc,
        encryptionMode: mode,
      ),
    );
    final discovered = await _udp.connectAndDiscover(
      serverAddress: address,
      serverPort: port,
      ssrc: ssrc,
    );
    await _transport.sendJson({
      'op': 1,
      'd': {
        'protocol': 'udp',
        'data': {
          'address': discovered.address,
          'port': discovered.port,
          'mode': mode,
        },
      },
    });
    _update(_state.copyWith(phase: DiscordVoiceNetworkPhase.selectingProtocol));
  }

  Future<void> _receiveSessionDescription(Map<String, Object?> data) async {
    if (_connectionOptions.usesWebRtc) {
      await _receiveRtcSessionDescription(data);
      return;
    }
    final mode = _requiredString(data['mode'], 'Voice encryption mode');
    if (mode != _state.encryptionMode) {
      throw const FormatException('Voice encryption mode 협상 결과가 일치하지 않습니다.');
    }
    final secretKey = _secretKey(data['secret_key']);
    final daveVersion = _requiredInt(
      data['dave_protocol_version'],
      'DAVE protocol version',
    );
    if (daveVersion < 0 || daveVersion > _maxDaveProtocolVersion) {
      throw const FormatException('지원할 수 없는 DAVE protocol version입니다.');
    }
    final credentials = _credentials;
    final ssrc = _state.ssrc;
    final groupId = int.tryParse(credentials?.channelId ?? '');
    if (credentials == null || groupId == null || ssrc == null) {
      throw const FormatException('DAVE session 초기화 정보가 올바르지 않습니다.');
    }
    await _dave.initialize(
      protocolVersion: daveVersion,
      groupId: groupId,
      selfUserId: credentials.userId,
    );
    _dave.assignLocalAudioSsrc(ssrc);
    _reconnectAttempt = 0;
    _update(
      _state.copyWith(
        phase: DiscordVoiceNetworkPhase.ready,
        secretKey: secretKey,
        daveProtocolVersion: daveVersion,
        errorMessage: null,
      ),
    );
  }

  Future<void> _receiveBinary(Uint8List frame) async {
    if (frame.length < 3) {
      throw const FormatException('Voice binary frame이 너무 짧습니다.');
    }
    final sequence = (frame[0] << 8) | frame[1];
    final message = VoiceGatewayBinaryMessage(
      sequence: sequence,
      opcode: frame[2],
      payload: List<int>.unmodifiable(frame.sublist(3)),
    );
    _update(_state.copyWith(sequence: sequence));
    if (!_binaryMessages.isClosed) {
      _binaryMessages.add(message);
    }
    await _dave.handleBinary(
      message.opcode,
      Uint8List.fromList(message.payload),
    );
  }
}

String _chooseEncryptionMode(List<String> modes) {
  if (modes.contains(DiscordVoiceGatewayClient.aes256GcmMode)) {
    return DiscordVoiceGatewayClient.aes256GcmMode;
  }
  if (modes.contains(DiscordVoiceGatewayClient.xchacha20Poly1305Mode)) {
    return DiscordVoiceGatewayClient.xchacha20Poly1305Mode;
  }
  throw const FormatException('호환되는 AEAD Voice encryption mode가 없습니다.');
}

Uint8List _secretKey(Object? value) {
  if (value is! List || value.length != 32) {
    throw const FormatException('Voice secret_key는 32바이트여야 합니다.');
  }
  final bytes = <int>[];
  for (final item in value) {
    if (item is! int || item < 0 || item > 255) {
      throw const FormatException('Voice secret_key 형식이 올바르지 않습니다.');
    }
    bytes.add(item);
  }
  return Uint8List.fromList(bytes);
}

Map<String, Object?> _decodeJson(Object? message) {
  final decoded = switch (message) {
    final String text => jsonDecode(text),
    final Map value => value,
    _ => throw const FormatException('Voice Gateway payload 형식이 올바르지 않습니다.'),
  };
  return _readMap(decoded, 'Voice Gateway payload');
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

int _requiredInt(Object? value, String field) {
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

String _requiredString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

List<String> _requiredStrings(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$field 형식이 올바르지 않습니다.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}
