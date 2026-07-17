import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_dave_session.dart';

typedef DiscordDaveJsonSender =
    Future<void> Function(int opcode, Map<String, Object?> data);
typedef DiscordDaveBinarySender =
    Future<void> Function(int opcode, Uint8List payload);

final class DiscordDaveController {
  DiscordDaveController({
    required DiscordDaveSession session,
    required DiscordDaveJsonSender sendJson,
    required DiscordDaveBinarySender sendBinary,
  }) : _session = session,
       _sendJson = sendJson,
       _sendBinary = sendBinary;

  static const int clientsConnectOpcode = 11;
  static const int clientDisconnectOpcode = 13;
  static const int prepareTransitionOpcode = 21;
  static const int executeTransitionOpcode = 22;
  static const int transitionReadyOpcode = 23;
  static const int prepareEpochOpcode = 24;
  static const int externalSenderOpcode = 25;
  static const int keyPackageOpcode = 26;
  static const int proposalsOpcode = 27;
  static const int commitWelcomeOpcode = 28;
  static const int announceCommitOpcode = 29;
  static const int welcomeOpcode = 30;
  static const int invalidCommitWelcomeOpcode = 31;

  final DiscordDaveSession _session;
  final DiscordDaveJsonSender _sendJson;
  final DiscordDaveBinarySender _sendBinary;

  Set<String> _connectedUserIds = const {};
  Map<int, int> _pendingTransitions = const {};
  int? _groupId;
  String? _selfUserId;
  int _protocolVersion = 0;
  bool _initialized = false;
  Uint8List? _pendingExternalSender;

  int get protocolVersion => _protocolVersion;

  DiscordDaveSession get session => _session;

  Set<String> get connectedUserIds => _connectedUserIds;

  Future<void> initialize({
    required int protocolVersion,
    required int groupId,
    required String selfUserId,
  }) async {
    if (protocolVersion < 0 ||
        protocolVersion > _session.maxSupportedProtocolVersion) {
      throw FormatException(
        '지원하지 않는 DAVE protocol version입니다: $protocolVersion',
      );
    }
    _session.initialize(
      protocolVersion: protocolVersion,
      groupId: groupId,
      selfUserId: selfUserId,
    );
    _protocolVersion = protocolVersion;
    _groupId = groupId;
    _selfUserId = selfUserId;
    _pendingTransitions = const {};
    _initialized = true;
    final pendingExternalSender = _pendingExternalSender;
    if (pendingExternalSender != null) {
      _session.setExternalSender(pendingExternalSender);
      _pendingExternalSender = null;
    }
    if (protocolVersion > 0) {
      await _sendKeyPackage();
    }
  }

  void resetConnectionState() {
    _connectedUserIds = const {};
    _pendingTransitions = const {};
    _pendingExternalSender = null;
    _initialized = false;
  }

  Future<void> handleJson(int opcode, Map<String, Object?> data) async {
    if (opcode == clientsConnectOpcode) {
      _connectClients(_requiredStrings(data['user_ids'], 'Voice user_ids'));
      return;
    }
    if (opcode == clientDisconnectOpcode) {
      _disconnectClient(_requiredString(data['user_id'], 'Voice user_id'));
      return;
    }
    _ensureInitialized();
    switch (opcode) {
      case prepareTransitionOpcode:
        await _prepareTransition(data);
      case executeTransitionOpcode:
        _executeTransition(
          _requiredInt(data['transition_id'], 'DAVE transition_id'),
        );
      case prepareEpochOpcode:
        await _prepareEpoch(data);
    }
  }

  Future<void> handleBinary(int opcode, Uint8List payload) async {
    if (opcode == externalSenderOpcode && !_initialized) {
      _pendingExternalSender = Uint8List.fromList(payload);
      return;
    }
    _ensureInitialized();
    switch (opcode) {
      case externalSenderOpcode:
        _session.setExternalSender(payload);
      case proposalsOpcode:
        final response = _session.processProposals(
          payload,
          recognizedUserIds: _connectedUserIds,
        );
        if (response != null) {
          await _sendBinary(commitWelcomeOpcode, response);
        }
      case announceCommitOpcode:
        await _processGroupUpdate(payload, isWelcome: false);
      case welcomeOpcode:
        await _processGroupUpdate(payload, isWelcome: true);
    }
  }

  Uint8List encryptAudio(Uint8List frame, {required int ssrc}) {
    _ensureInitialized();
    if (_protocolVersion == 0) {
      return Uint8List.fromList(frame);
    }
    return _session.encryptAudio(frame, ssrc: ssrc);
  }

  void assignLocalAudioSsrc(int ssrc) {
    _ensureInitialized();
    _session.assignLocalAudioSsrc(ssrc);
  }

  Uint8List decryptAudio(Uint8List frame, {required String remoteUserId}) {
    _ensureInitialized();
    if (_protocolVersion == 0) {
      return Uint8List.fromList(frame);
    }
    return _session.decryptAudio(frame, remoteUserId: remoteUserId);
  }

  Uint8List decryptVideo(Uint8List frame, {required String remoteUserId}) {
    _ensureInitialized();
    if (_protocolVersion == 0) {
      return Uint8List.fromList(frame);
    }
    return _session.decryptVideo(frame, remoteUserId: remoteUserId);
  }

  void close() => _session.close();

  void _connectClients(List<String> userIds) {
    _connectedUserIds = Set.unmodifiable({..._connectedUserIds, ...userIds});
  }

  void _disconnectClient(String userId) {
    _connectedUserIds = Set.unmodifiable(
      _connectedUserIds.where((connectedUserId) => connectedUserId != userId),
    );
  }

  Future<void> _prepareTransition(Map<String, Object?> data) async {
    final transitionId = _requiredInt(
      data['transition_id'],
      'DAVE transition_id',
    );
    final protocolVersion = _requiredInt(
      data['protocol_version'],
      'DAVE protocol_version',
    );
    _validateTransition(transitionId, protocolVersion);
    _pendingTransitions = Map.unmodifiable({
      ..._pendingTransitions,
      transitionId: protocolVersion,
    });
    if (transitionId == 0) {
      _executeTransition(transitionId);
      return;
    }
    if (protocolVersion == 0) {
      _session.setPassthroughMode(
        enabled: true,
        remoteUserIds: _connectedUserIds,
      );
    }
    await _sendTransitionReady(transitionId);
  }

  void _executeTransition(int transitionId) {
    final protocolVersion = _pendingTransitions[transitionId];
    if (protocolVersion == null) {
      return;
    }
    _protocolVersion = protocolVersion;
    _pendingTransitions = Map.unmodifiable(
      Map<int, int>.fromEntries(
        _pendingTransitions.entries.where((entry) => entry.key != transitionId),
      ),
    );
  }

  Future<void> _prepareEpoch(Map<String, Object?> data) async {
    final epoch = _requiredInt(data['epoch'], 'DAVE epoch');
    final protocolVersion = _requiredInt(
      data['protocol_version'],
      'DAVE protocol_version',
    );
    if (epoch < 1) {
      throw const FormatException('DAVE epoch은 1 이상이어야 합니다.');
    }
    if (epoch == 1) {
      await initialize(
        protocolVersion: protocolVersion,
        groupId: _groupId!,
        selfUserId: _selfUserId!,
      );
    }
  }

  Future<void> _processGroupUpdate(
    Uint8List payload, {
    required bool isWelcome,
  }) async {
    if (payload.length < 3) {
      throw const FormatException('DAVE commit/welcome payload가 너무 짧습니다.');
    }
    final transitionId = (payload[0] << 8) | payload[1];
    final mlsPayload = Uint8List.fromList(payload.sublist(2));
    DiscordDaveGroupUpdate result;
    try {
      result = isWelcome
          ? _session.processWelcome(
              mlsPayload,
              recognizedUserIds: _connectedUserIds,
            )
          : _session.processCommit(mlsPayload);
    } on Object {
      result = DiscordDaveGroupUpdate.failed;
    }
    if (result == DiscordDaveGroupUpdate.failed) {
      await _recoverInvalidGroup(transitionId);
      return;
    }
    if (result == DiscordDaveGroupUpdate.ignored) {
      return;
    }
    if (transitionId > 0) {
      _pendingTransitions = Map.unmodifiable({
        ..._pendingTransitions,
        transitionId: _protocolVersion,
      });
      await _sendTransitionReady(transitionId);
    }
  }

  Future<void> _recoverInvalidGroup(int transitionId) async {
    await _sendJson(invalidCommitWelcomeOpcode, {
      'transition_id': transitionId,
    });
    await initialize(
      protocolVersion: _protocolVersion,
      groupId: _groupId!,
      selfUserId: _selfUserId!,
    );
  }

  Future<void> _sendKeyPackage() async {
    await _sendBinary(keyPackageOpcode, _session.createKeyPackage());
  }

  Future<void> _sendTransitionReady(int transitionId) async {
    await _sendJson(transitionReadyOpcode, {'transition_id': transitionId});
  }

  void _validateTransition(int transitionId, int protocolVersion) {
    if (transitionId < 0 || transitionId > 0xFFFF) {
      throw const FormatException('DAVE transition_id 범위가 올바르지 않습니다.');
    }
    if (protocolVersion < 0 ||
        protocolVersion > _session.maxSupportedProtocolVersion) {
      throw const FormatException('DAVE protocol_version 범위가 올바르지 않습니다.');
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('DAVE controller가 초기화되지 않았습니다.');
    }
  }
}

int _requiredInt(Object? value, String field) {
  if (value is int) {
    return value;
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
