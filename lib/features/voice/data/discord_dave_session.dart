import 'dart:ffi';
import 'dart:typed_data';

import 'package:discord_native/features/voice/data/libdave_bindings.dart';

enum DiscordDaveGroupUpdate { applied, ignored, failed }

enum DiscordDaveVideoCodec {
  vp8(2),
  vp9(3),
  h264(4),
  h265(5),
  av1(6);

  const DiscordDaveVideoCodec(this.nativeValue);

  final int nativeValue;
}

abstract interface class DiscordDaveSession {
  int get maxSupportedProtocolVersion;

  int get protocolVersion;

  void initialize({
    required int protocolVersion,
    required int groupId,
    required String selfUserId,
  });

  Uint8List createKeyPackage();

  void setExternalSender(Uint8List payload);

  Uint8List? processProposals(
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  });

  DiscordDaveGroupUpdate processCommit(Uint8List payload);

  DiscordDaveGroupUpdate processWelcome(
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  });

  void assignLocalAudioSsrc(int ssrc);

  void assignLocalVideoSsrc(int ssrc, {required DiscordDaveVideoCodec codec});

  void setPassthroughMode({
    required bool enabled,
    required Iterable<String> remoteUserIds,
  });

  Uint8List encryptAudio(Uint8List frame, {required int ssrc});

  Uint8List encryptVideo(Uint8List frame, {required int ssrc});

  Uint8List decryptAudio(Uint8List frame, {required String remoteUserId});

  Uint8List decryptVideo(Uint8List frame, {required String remoteUserId});

  void close();
}

abstract interface class DiscordDaveNativeHandles {
  int get nativeEncryptorAddress;
}

final class NativeDiscordDaveSession
    implements DiscordDaveSession, DiscordDaveNativeHandles {
  NativeDiscordDaveSession._({
    required LibdaveBindings bindings,
    required DaveHandle session,
    required DaveHandle encryptor,
  }) : _bindings = bindings,
       _session = session,
       _encryptor = encryptor;

  final LibdaveBindings _bindings;
  final DaveHandle _session;
  final DaveHandle _encryptor;
  Map<String, DaveHandle> _decryptors = const {};
  String? _selfUserId;
  bool _initialized = false;
  bool _closed = false;

  factory NativeDiscordDaveSession.open({required String libraryPath}) {
    final bindings = LibdaveBindings.open(libraryPath);
    final session = bindings.createSession();
    try {
      final encryptor = bindings.createEncryptor();
      return NativeDiscordDaveSession._(
        bindings: bindings,
        session: session,
        encryptor: encryptor,
      );
    } catch (_) {
      bindings.destroySession(session);
      rethrow;
    }
  }

  @override
  int get maxSupportedProtocolVersion {
    _ensureOpen();
    return _bindings.maxSupportedProtocolVersion;
  }

  @override
  int get protocolVersion {
    _ensureInitialized();
    return _bindings.getSessionProtocolVersion(_session);
  }

  @override
  int get nativeEncryptorAddress {
    _ensureInitialized();
    return _encryptor.address;
  }

  @override
  void initialize({
    required int protocolVersion,
    required int groupId,
    required String selfUserId,
  }) {
    _ensureOpen();
    if (protocolVersion < 0 ||
        protocolVersion > _bindings.maxSupportedProtocolVersion) {
      throw FormatException(
        '지원하지 않는 DAVE protocol version입니다: $protocolVersion',
      );
    }
    if (groupId < 0) {
      throw const FormatException('DAVE group ID는 음수가 될 수 없습니다.');
    }
    if (selfUserId.isEmpty || int.tryParse(selfUserId) == null) {
      throw const FormatException('DAVE self user ID는 숫자 snowflake여야 합니다.');
    }
    _bindings.initializeSession(
      _session,
      protocolVersion: protocolVersion,
      groupId: groupId,
      selfUserId: selfUserId,
    );
    _clearDecryptors();
    _bindings.setEncryptorPassthrough(_encryptor, true);
    _selfUserId = selfUserId;
    _initialized = true;
  }

  @override
  Uint8List createKeyPackage() {
    _ensureInitialized();
    if (protocolVersion == 0) {
      throw StateError('DAVE protocol 0에서는 MLS key package를 만들 수 없습니다.');
    }
    return _bindings.getMarshalledKeyPackage(_session);
  }

  @override
  void setExternalSender(Uint8List payload) {
    _ensureInitialized();
    _validateMlsPayload(payload, 'MLS external sender');
    _bindings.setExternalSender(_session, payload);
  }

  @override
  Uint8List? processProposals(
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  }) {
    _ensureInitialized();
    _validateMlsPayload(payload, 'MLS proposals');
    _validateUserIds(recognizedUserIds);
    return _bindings.processProposals(
      _session,
      payload,
      recognizedUserIds: recognizedUserIds,
    );
  }

  @override
  DiscordDaveGroupUpdate processCommit(Uint8List payload) {
    _ensureInitialized();
    _validateMlsPayload(payload, 'MLS commit');
    final result = _bindings.processCommit(_session, payload);
    if (result.failed) {
      return DiscordDaveGroupUpdate.failed;
    }
    if (result.ignored) {
      return DiscordDaveGroupUpdate.ignored;
    }
    _applyRoster(result.rosterUserIds);
    return DiscordDaveGroupUpdate.applied;
  }

  @override
  DiscordDaveGroupUpdate processWelcome(
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  }) {
    _ensureInitialized();
    _validateMlsPayload(payload, 'MLS welcome');
    _validateUserIds(recognizedUserIds);
    final roster = _bindings.processWelcome(
      _session,
      payload,
      recognizedUserIds: recognizedUserIds,
    );
    if (roster == null) {
      return DiscordDaveGroupUpdate.failed;
    }
    _applyRoster(roster);
    return DiscordDaveGroupUpdate.applied;
  }

  @override
  void assignLocalAudioSsrc(int ssrc) {
    _ensureInitialized();
    _validateSsrc(ssrc);
    _bindings.assignOpusSsrc(_encryptor, ssrc);
  }

  @override
  void assignLocalVideoSsrc(int ssrc, {required DiscordDaveVideoCodec codec}) {
    _ensureInitialized();
    _validateSsrc(ssrc);
    _bindings.assignVideoSsrc(_encryptor, ssrc, codec: codec.nativeValue);
  }

  @override
  void setPassthroughMode({
    required bool enabled,
    required Iterable<String> remoteUserIds,
  }) {
    _ensureInitialized();
    _bindings.setEncryptorPassthrough(_encryptor, enabled);
    final userIds = remoteUserIds.toSet();
    final nextDecryptors = _withMissingDecryptors(userIds);
    for (final userId in userIds) {
      _bindings.setDecryptorPassthrough(nextDecryptors[userId]!, enabled);
    }
    _decryptors = Map.unmodifiable(nextDecryptors);
  }

  @override
  Uint8List encryptAudio(Uint8List frame, {required int ssrc}) {
    _ensureInitialized();
    _validateSsrc(ssrc);
    if (frame.isEmpty) {
      throw const FormatException('암호화할 Opus frame이 비어 있습니다.');
    }
    if (_isSilenceFrame(frame)) {
      return Uint8List.fromList(frame);
    }
    return _bindings.encryptAudio(_encryptor, frame, ssrc);
  }

  @override
  Uint8List encryptVideo(Uint8List frame, {required int ssrc}) {
    _ensureInitialized();
    _validateSsrc(ssrc);
    if (frame.isEmpty) {
      throw const FormatException('암호화할 video frame이 비어 있습니다.');
    }
    return _bindings.encryptVideo(_encryptor, frame, ssrc);
  }

  @override
  Uint8List decryptAudio(Uint8List frame, {required String remoteUserId}) {
    _ensureInitialized();
    if (frame.isEmpty) {
      throw const FormatException('복호화할 DAVE frame이 비어 있습니다.');
    }
    if (_isSilenceFrame(frame)) {
      return Uint8List.fromList(frame);
    }
    final decryptor = _decryptors[remoteUserId];
    if (decryptor == null) {
      throw StateError('DAVE decryptor가 없는 사용자입니다: $remoteUserId');
    }
    return _bindings.decryptAudio(decryptor, frame);
  }

  @override
  Uint8List decryptVideo(Uint8List frame, {required String remoteUserId}) {
    _ensureInitialized();
    if (frame.isEmpty) {
      throw const FormatException('복호화할 DAVE video frame이 비어 있습니다.');
    }
    final decryptor = _decryptors[remoteUserId];
    if (decryptor == null) {
      throw StateError('DAVE decryptor가 없는 사용자입니다: $remoteUserId');
    }
    return _bindings.decryptVideo(decryptor, frame);
  }

  @override
  void close() {
    if (_closed) {
      return;
    }
    _clearDecryptors();
    _bindings.destroyEncryptor(_encryptor);
    _bindings.destroySession(_session);
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('이미 닫힌 DAVE session입니다.');
    }
  }

  void _ensureInitialized() {
    _ensureOpen();
    if (!_initialized) {
      throw StateError('DAVE session이 초기화되지 않았습니다.');
    }
  }

  void _validateSsrc(int ssrc) {
    if (ssrc < 0 || ssrc > 0xFFFFFFFF) {
      throw FormatException('DAVE audio SSRC 범위가 올바르지 않습니다: $ssrc');
    }
  }

  void _applyRoster(List<int> rosterUserIds) {
    final selfUserId = _selfUserId;
    if (selfUserId == null) {
      throw StateError('DAVE self user ID가 초기화되지 않았습니다.');
    }
    final roster = rosterUserIds.map((userId) => userId.toString()).toSet();
    if (!roster.contains(selfUserId)) {
      throw StateError('DAVE MLS roster에 현재 사용자가 없습니다.');
    }
    final remoteUserIds = roster
        .where((userId) => userId != selfUserId)
        .toSet();
    final availableDecryptors = _withMissingDecryptors(remoteUserIds);
    for (final entry in _decryptors.entries) {
      if (!remoteUserIds.contains(entry.key)) {
        _bindings.destroyDecryptor(entry.value);
      }
    }
    final nextDecryptors = <String, DaveHandle>{
      for (final entry in availableDecryptors.entries)
        if (remoteUserIds.contains(entry.key)) entry.key: entry.value,
    };
    for (final userId in roster) {
      final keyRatchet = _bindings.getKeyRatchet(_session, userId);
      if (keyRatchet == nullptr) {
        throw StateError('DAVE key ratchet을 만들 수 없는 사용자입니다: $userId');
      }
      try {
        if (userId == selfUserId) {
          _bindings.setEncryptorKeyRatchet(_encryptor, keyRatchet);
        } else {
          _bindings.setDecryptorKeyRatchet(nextDecryptors[userId]!, keyRatchet);
        }
      } finally {
        _bindings.destroyKeyRatchet(keyRatchet);
      }
    }
    _bindings.setEncryptorPassthrough(_encryptor, false);
    _decryptors = Map.unmodifiable(nextDecryptors);
  }

  Map<String, DaveHandle> _withMissingDecryptors(Set<String> userIds) {
    _validateUserIds(userIds);
    final createdDecryptors = <String, DaveHandle>{};
    try {
      for (final userId in userIds.where(
        (userId) => !_decryptors.containsKey(userId),
      )) {
        createdDecryptors[userId] = _bindings.createDecryptor();
      }
      return <String, DaveHandle>{..._decryptors, ...createdDecryptors};
    } catch (_) {
      for (final decryptor in createdDecryptors.values) {
        _bindings.destroyDecryptor(decryptor);
      }
      rethrow;
    }
  }

  void _clearDecryptors() {
    for (final decryptor in _decryptors.values) {
      _bindings.destroyDecryptor(decryptor);
    }
    _decryptors = const {};
  }

  void _validateMlsPayload(Uint8List payload, String field) {
    if (payload.isEmpty) {
      throw FormatException('$field payload가 비어 있습니다.');
    }
  }

  void _validateUserIds(Iterable<String> userIds) {
    if (userIds.any(
      (userId) => userId.isEmpty || int.tryParse(userId) == null,
    )) {
      throw const FormatException('DAVE user ID는 숫자 snowflake여야 합니다.');
    }
  }
}

bool _isSilenceFrame(Uint8List frame) {
  return frame.length == 3 &&
      frame[0] == 0xF8 &&
      frame[1] == 0xFF &&
      frame[2] == 0xFE;
}
