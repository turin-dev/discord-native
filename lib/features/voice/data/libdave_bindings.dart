import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef DaveHandle = Pointer<Void>;

final class LibdaveCommitResult {
  const LibdaveCommitResult({
    required this.failed,
    required this.ignored,
    required this.rosterUserIds,
  });

  final bool failed;
  final bool ignored;
  final List<int> rosterUserIds;
}

final class LibdaveBindings {
  LibdaveBindings._(this._library) {
    _maxSupportedProtocolVersion = _library
        .lookupFunction<Uint16 Function(), int Function()>(
          'daveMaxSupportedProtocolVersion',
        );
    _free = _library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('daveFree');
    _sessionCreate = _library
        .lookupFunction<
          Pointer<Void> Function(
            Pointer<Void>,
            Pointer<Utf8>,
            Pointer<Void>,
            Pointer<Void>,
          ),
          Pointer<Void> Function(
            Pointer<Void>,
            Pointer<Utf8>,
            Pointer<Void>,
            Pointer<Void>,
          )
        >('daveSessionCreate');
    _sessionDestroy = _library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('daveSessionDestroy');
    _sessionInit = _library
        .lookupFunction<
          Void Function(Pointer<Void>, Uint16, Uint64, Pointer<Utf8>),
          void Function(Pointer<Void>, int, int, Pointer<Utf8>)
        >('daveSessionInit');
    _sessionGetProtocolVersion = _library
        .lookupFunction<
          Uint16 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('daveSessionGetProtocolVersion');
    _sessionGetMarshalledKeyPackage = _library
        .lookupFunction<
          Void Function(Pointer<Void>, Pointer<Pointer<Uint8>>, Pointer<Size>),
          void Function(Pointer<Void>, Pointer<Pointer<Uint8>>, Pointer<Size>)
        >('daveSessionGetMarshalledKeyPackage');
    _sessionSetExternalSender = _library
        .lookupFunction<
          Void Function(Pointer<Void>, Pointer<Uint8>, Size),
          void Function(Pointer<Void>, Pointer<Uint8>, int)
        >('daveSessionSetExternalSender');
    _sessionProcessProposals = _library
        .lookupFunction<
          Void Function(
            Pointer<Void>,
            Pointer<Uint8>,
            Size,
            Pointer<Pointer<Utf8>>,
            Size,
            Pointer<Pointer<Uint8>>,
            Pointer<Size>,
          ),
          void Function(
            Pointer<Void>,
            Pointer<Uint8>,
            int,
            Pointer<Pointer<Utf8>>,
            int,
            Pointer<Pointer<Uint8>>,
            Pointer<Size>,
          )
        >('daveSessionProcessProposals');
    _sessionProcessCommit = _library
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, Size),
          Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, int)
        >('daveSessionProcessCommit');
    _sessionProcessWelcome = _library
        .lookupFunction<
          Pointer<Void> Function(
            Pointer<Void>,
            Pointer<Uint8>,
            Size,
            Pointer<Pointer<Utf8>>,
            Size,
          ),
          Pointer<Void> Function(
            Pointer<Void>,
            Pointer<Uint8>,
            int,
            Pointer<Pointer<Utf8>>,
            int,
          )
        >('daveSessionProcessWelcome');
    _sessionGetKeyRatchet = _library
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>),
          Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>)
        >('daveSessionGetKeyRatchet');
    _keyRatchetDestroy = _library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('daveKeyRatchetDestroy');
    _commitResultIsFailed = _library
        .lookupFunction<
          Bool Function(Pointer<Void>),
          bool Function(Pointer<Void>)
        >('daveCommitResultIsFailed');
    _commitResultIsIgnored = _library
        .lookupFunction<
          Bool Function(Pointer<Void>),
          bool Function(Pointer<Void>)
        >('daveCommitResultIsIgnored');
    _commitResultGetRosterMemberIds = _library
        .lookupFunction<
          Void Function(Pointer<Void>, Pointer<Pointer<Uint64>>, Pointer<Size>),
          void Function(Pointer<Void>, Pointer<Pointer<Uint64>>, Pointer<Size>)
        >('daveCommitResultGetRosterMemberIds');
    _commitResultDestroy = _library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('daveCommitResultDestroy');
    _welcomeResultGetRosterMemberIds = _library
        .lookupFunction<
          Void Function(Pointer<Void>, Pointer<Pointer<Uint64>>, Pointer<Size>),
          void Function(Pointer<Void>, Pointer<Pointer<Uint64>>, Pointer<Size>)
        >('daveWelcomeResultGetRosterMemberIds');
    _welcomeResultDestroy = _library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('daveWelcomeResultDestroy');
    _encryptorCreate = _library
        .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
          'daveEncryptorCreate',
        );
    _encryptorDestroy = _library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('daveEncryptorDestroy');
    _encryptorSetPassthroughMode = _library
        .lookupFunction<
          Void Function(Pointer<Void>, Bool),
          void Function(Pointer<Void>, bool)
        >('daveEncryptorSetPassthroughMode');
    _encryptorSetKeyRatchet = _library
        .lookupFunction<
          Void Function(Pointer<Void>, Pointer<Void>),
          void Function(Pointer<Void>, Pointer<Void>)
        >('daveEncryptorSetKeyRatchet');
    _encryptorAssignSsrcToCodec = _library
        .lookupFunction<
          Void Function(Pointer<Void>, Uint32, Int32),
          void Function(Pointer<Void>, int, int)
        >('daveEncryptorAssignSsrcToCodec');
    _encryptorGetMaxCiphertextByteSize = _library
        .lookupFunction<
          Size Function(Pointer<Void>, Int32, Size),
          int Function(Pointer<Void>, int, int)
        >('daveEncryptorGetMaxCiphertextByteSize');
    _encryptorEncrypt = _library
        .lookupFunction<
          Int32 Function(
            Pointer<Void>,
            Int32,
            Uint32,
            Pointer<Uint8>,
            Size,
            Pointer<Uint8>,
            Size,
            Pointer<Size>,
          ),
          int Function(
            Pointer<Void>,
            int,
            int,
            Pointer<Uint8>,
            int,
            Pointer<Uint8>,
            int,
            Pointer<Size>,
          )
        >('daveEncryptorEncrypt');
    _decryptorCreate = _library
        .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
          'daveDecryptorCreate',
        );
    _decryptorDestroy = _library
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('daveDecryptorDestroy');
    _decryptorTransitionToPassthroughMode = _library
        .lookupFunction<
          Void Function(Pointer<Void>, Bool),
          void Function(Pointer<Void>, bool)
        >('daveDecryptorTransitionToPassthroughMode');
    _decryptorTransitionToKeyRatchet = _library
        .lookupFunction<
          Void Function(Pointer<Void>, Pointer<Void>),
          void Function(Pointer<Void>, Pointer<Void>)
        >('daveDecryptorTransitionToKeyRatchet');
    _decryptorGetMaxPlaintextByteSize = _library
        .lookupFunction<
          Size Function(Pointer<Void>, Int32, Size),
          int Function(Pointer<Void>, int, int)
        >('daveDecryptorGetMaxPlaintextByteSize');
    _decryptorDecrypt = _library
        .lookupFunction<
          Int32 Function(
            Pointer<Void>,
            Int32,
            Pointer<Uint8>,
            Size,
            Pointer<Uint8>,
            Size,
            Pointer<Size>,
          ),
          int Function(
            Pointer<Void>,
            int,
            Pointer<Uint8>,
            int,
            Pointer<Uint8>,
            int,
            Pointer<Size>,
          )
        >('daveDecryptorDecrypt');
  }

  static const int audioMediaType = 0;
  static const int videoMediaType = 1;
  static const int opusCodec = 1;
  static const int successResult = 0;

  final DynamicLibrary _library;
  late final int Function() _maxSupportedProtocolVersion;
  late final void Function(Pointer<Void>) _free;
  late final Pointer<Void> Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Void>,
    Pointer<Void>,
  )
  _sessionCreate;
  late final void Function(Pointer<Void>) _sessionDestroy;
  late final void Function(Pointer<Void>, int, int, Pointer<Utf8>) _sessionInit;
  late final int Function(Pointer<Void>) _sessionGetProtocolVersion;
  late final void Function(
    Pointer<Void>,
    Pointer<Pointer<Uint8>>,
    Pointer<Size>,
  )
  _sessionGetMarshalledKeyPackage;
  late final void Function(Pointer<Void>, Pointer<Uint8>, int)
  _sessionSetExternalSender;
  late final void Function(
    Pointer<Void>,
    Pointer<Uint8>,
    int,
    Pointer<Pointer<Utf8>>,
    int,
    Pointer<Pointer<Uint8>>,
    Pointer<Size>,
  )
  _sessionProcessProposals;
  late final Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, int)
  _sessionProcessCommit;
  late final Pointer<Void> Function(
    Pointer<Void>,
    Pointer<Uint8>,
    int,
    Pointer<Pointer<Utf8>>,
    int,
  )
  _sessionProcessWelcome;
  late final Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>)
  _sessionGetKeyRatchet;
  late final void Function(Pointer<Void>) _keyRatchetDestroy;
  late final bool Function(Pointer<Void>) _commitResultIsFailed;
  late final bool Function(Pointer<Void>) _commitResultIsIgnored;
  late final void Function(
    Pointer<Void>,
    Pointer<Pointer<Uint64>>,
    Pointer<Size>,
  )
  _commitResultGetRosterMemberIds;
  late final void Function(Pointer<Void>) _commitResultDestroy;
  late final void Function(
    Pointer<Void>,
    Pointer<Pointer<Uint64>>,
    Pointer<Size>,
  )
  _welcomeResultGetRosterMemberIds;
  late final void Function(Pointer<Void>) _welcomeResultDestroy;
  late final Pointer<Void> Function() _encryptorCreate;
  late final void Function(Pointer<Void>) _encryptorDestroy;
  late final void Function(Pointer<Void>, bool) _encryptorSetPassthroughMode;
  late final void Function(Pointer<Void>, Pointer<Void>)
  _encryptorSetKeyRatchet;
  late final void Function(Pointer<Void>, int, int) _encryptorAssignSsrcToCodec;
  late final int Function(Pointer<Void>, int, int)
  _encryptorGetMaxCiphertextByteSize;
  late final int Function(
    Pointer<Void>,
    int,
    int,
    Pointer<Uint8>,
    int,
    Pointer<Uint8>,
    int,
    Pointer<Size>,
  )
  _encryptorEncrypt;
  late final Pointer<Void> Function() _decryptorCreate;
  late final void Function(Pointer<Void>) _decryptorDestroy;
  late final void Function(Pointer<Void>, bool)
  _decryptorTransitionToPassthroughMode;
  late final void Function(Pointer<Void>, Pointer<Void>)
  _decryptorTransitionToKeyRatchet;
  late final int Function(Pointer<Void>, int, int)
  _decryptorGetMaxPlaintextByteSize;
  late final int Function(
    Pointer<Void>,
    int,
    Pointer<Uint8>,
    int,
    Pointer<Uint8>,
    int,
    Pointer<Size>,
  )
  _decryptorDecrypt;

  factory LibdaveBindings.open(String libraryPath) {
    if (libraryPath.trim().isEmpty) {
      throw const FormatException('libdave library path가 비어 있습니다.');
    }
    try {
      return LibdaveBindings._(DynamicLibrary.open(libraryPath));
    } on ArgumentError catch (error) {
      throw StateError('libdave를 로드하지 못했습니다: $error');
    }
  }

  int get maxSupportedProtocolVersion => _maxSupportedProtocolVersion();

  DaveHandle createSession() {
    final handle = _sessionCreate(nullptr, nullptr, nullptr, nullptr);
    if (handle == nullptr) {
      throw StateError('libdave session 생성에 실패했습니다.');
    }
    return handle;
  }

  void destroySession(DaveHandle session) => _sessionDestroy(session);

  void initializeSession(
    DaveHandle session, {
    required int protocolVersion,
    required int groupId,
    required String selfUserId,
  }) {
    final userId = selfUserId.toNativeUtf8();
    try {
      _sessionInit(session, protocolVersion, groupId, userId);
    } finally {
      calloc.free(userId);
    }
  }

  int getSessionProtocolVersion(DaveHandle session) {
    return _sessionGetProtocolVersion(session);
  }

  Uint8List getMarshalledKeyPackage(DaveHandle session) {
    final bytes = calloc<Pointer<Uint8>>();
    final length = calloc<Size>();
    try {
      _sessionGetMarshalledKeyPackage(session, bytes, length);
      return _copyOwnedBytes(bytes.value, length.value);
    } finally {
      calloc.free(length);
      calloc.free(bytes);
    }
  }

  void setExternalSender(DaveHandle session, Uint8List payload) {
    _withInputBytes(payload, (bytes, length) {
      _sessionSetExternalSender(session, bytes, length);
    });
  }

  Uint8List? processProposals(
    DaveHandle session,
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  }) {
    final output = calloc<Pointer<Uint8>>();
    final outputLength = calloc<Size>();
    try {
      _withInputBytes(payload, (bytes, length) {
        _withUserIds(recognizedUserIds, (userIds, userIdCount) {
          _sessionProcessProposals(
            session,
            bytes,
            length,
            userIds,
            userIdCount,
            output,
            outputLength,
          );
        });
      });
      final result = _copyOwnedBytes(output.value, outputLength.value);
      return result.isEmpty ? null : result;
    } finally {
      calloc.free(outputLength);
      calloc.free(output);
    }
  }

  LibdaveCommitResult processCommit(DaveHandle session, Uint8List payload) {
    final result = _withInputBytes(
      payload,
      (bytes, length) => _sessionProcessCommit(session, bytes, length),
    );
    if (result == nullptr) {
      return const LibdaveCommitResult(
        failed: true,
        ignored: false,
        rosterUserIds: [],
      );
    }
    try {
      final failed = _commitResultIsFailed(result);
      final ignored = !failed && _commitResultIsIgnored(result);
      final roster = failed || ignored
          ? const <int>[]
          : _readOwnedRoster(result, _commitResultGetRosterMemberIds);
      return LibdaveCommitResult(
        failed: failed,
        ignored: ignored,
        rosterUserIds: List.unmodifiable(roster),
      );
    } finally {
      _commitResultDestroy(result);
    }
  }

  List<int>? processWelcome(
    DaveHandle session,
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  }) {
    final result = _withInputBytes(
      payload,
      (bytes, length) => _withUserIds(
        recognizedUserIds,
        (userIds, userIdCount) => _sessionProcessWelcome(
          session,
          bytes,
          length,
          userIds,
          userIdCount,
        ),
      ),
    );
    if (result == nullptr) {
      return null;
    }
    try {
      return List.unmodifiable(
        _readOwnedRoster(result, _welcomeResultGetRosterMemberIds),
      );
    } finally {
      _welcomeResultDestroy(result);
    }
  }

  DaveHandle getKeyRatchet(DaveHandle session, String userId) {
    final nativeUserId = userId.toNativeUtf8();
    try {
      return _sessionGetKeyRatchet(session, nativeUserId);
    } finally {
      calloc.free(nativeUserId);
    }
  }

  void destroyKeyRatchet(DaveHandle keyRatchet) {
    _keyRatchetDestroy(keyRatchet);
  }

  DaveHandle createEncryptor() =>
      _requireHandle(_encryptorCreate(), resourceName: 'encryptor');

  void destroyEncryptor(DaveHandle encryptor) => _encryptorDestroy(encryptor);

  void setEncryptorPassthrough(DaveHandle encryptor, bool enabled) {
    _encryptorSetPassthroughMode(encryptor, enabled);
  }

  void setEncryptorKeyRatchet(DaveHandle encryptor, DaveHandle keyRatchet) {
    _encryptorSetKeyRatchet(encryptor, keyRatchet);
  }

  void assignOpusSsrc(DaveHandle encryptor, int ssrc) {
    _encryptorAssignSsrcToCodec(encryptor, ssrc, opusCodec);
  }

  void assignVideoSsrc(DaveHandle encryptor, int ssrc, {required int codec}) {
    _encryptorAssignSsrcToCodec(encryptor, ssrc, codec);
  }

  Uint8List encryptAudio(DaveHandle encryptor, Uint8List frame, int ssrc) {
    final capacity = _encryptorGetMaxCiphertextByteSize(
      encryptor,
      audioMediaType,
      frame.length,
    );
    return _transformFrame(
      frame: frame,
      capacity: capacity,
      transform: (input, output, bytesWritten) => _encryptorEncrypt(
        encryptor,
        audioMediaType,
        ssrc,
        input,
        frame.length,
        output,
        capacity,
        bytesWritten,
      ),
      operationName: 'DAVE audio 암호화',
    );
  }

  Uint8List encryptVideo(DaveHandle encryptor, Uint8List frame, int ssrc) {
    final capacity = _encryptorGetMaxCiphertextByteSize(
      encryptor,
      videoMediaType,
      frame.length,
    );
    return _transformFrame(
      frame: frame,
      capacity: capacity,
      transform: (input, output, bytesWritten) => _encryptorEncrypt(
        encryptor,
        videoMediaType,
        ssrc,
        input,
        frame.length,
        output,
        capacity,
        bytesWritten,
      ),
      operationName: 'DAVE video 암호화',
    );
  }

  DaveHandle createDecryptor() =>
      _requireHandle(_decryptorCreate(), resourceName: 'decryptor');

  void destroyDecryptor(DaveHandle decryptor) => _decryptorDestroy(decryptor);

  void setDecryptorPassthrough(DaveHandle decryptor, bool enabled) {
    _decryptorTransitionToPassthroughMode(decryptor, enabled);
  }

  void setDecryptorKeyRatchet(DaveHandle decryptor, DaveHandle keyRatchet) {
    _decryptorTransitionToKeyRatchet(decryptor, keyRatchet);
  }

  Uint8List decryptAudio(DaveHandle decryptor, Uint8List frame) {
    final capacity = _decryptorGetMaxPlaintextByteSize(
      decryptor,
      audioMediaType,
      frame.length,
    );
    return _transformFrame(
      frame: frame,
      capacity: capacity,
      transform: (input, output, bytesWritten) => _decryptorDecrypt(
        decryptor,
        audioMediaType,
        input,
        frame.length,
        output,
        capacity,
        bytesWritten,
      ),
      operationName: 'DAVE audio 복호화',
    );
  }

  Uint8List decryptVideo(DaveHandle decryptor, Uint8List frame) {
    final capacity = _decryptorGetMaxPlaintextByteSize(
      decryptor,
      videoMediaType,
      frame.length,
    );
    return _transformFrame(
      frame: frame,
      capacity: capacity,
      transform: (input, output, bytesWritten) => _decryptorDecrypt(
        decryptor,
        videoMediaType,
        input,
        frame.length,
        output,
        capacity,
        bytesWritten,
      ),
      operationName: 'DAVE video 복호화',
    );
  }

  Uint8List _copyOwnedBytes(Pointer<Uint8> bytes, int length) {
    if (bytes == nullptr || length == 0) {
      if (bytes != nullptr) {
        _free(bytes.cast<Void>());
      }
      return Uint8List(0);
    }
    try {
      return Uint8List.fromList(bytes.asTypedList(length));
    } finally {
      _free(bytes.cast<Void>());
    }
  }

  List<int> _readOwnedRoster(
    DaveHandle result,
    void Function(DaveHandle, Pointer<Pointer<Uint64>>, Pointer<Size>)
    readRoster,
  ) {
    final roster = calloc<Pointer<Uint64>>();
    final length = calloc<Size>();
    try {
      readRoster(result, roster, length);
      if (roster.value == nullptr || length.value == 0) {
        if (roster.value != nullptr) {
          _free(roster.value.cast<Void>());
        }
        return const [];
      }
      try {
        return List<int>.from(roster.value.asTypedList(length.value));
      } finally {
        _free(roster.value.cast<Void>());
      }
    } finally {
      calloc.free(length);
      calloc.free(roster);
    }
  }

  T _withInputBytes<T>(
    Uint8List payload,
    T Function(Pointer<Uint8> bytes, int length) callback,
  ) {
    if (payload.isEmpty) {
      return callback(nullptr.cast<Uint8>(), 0);
    }
    final bytes = calloc<Uint8>(payload.length);
    try {
      bytes.asTypedList(payload.length).setAll(0, payload);
      return callback(bytes, payload.length);
    } finally {
      calloc.free(bytes);
    }
  }

  T _withUserIds<T>(
    Set<String> userIds,
    T Function(Pointer<Pointer<Utf8>> userIds, int length) callback,
  ) {
    if (userIds.isEmpty) {
      return callback(nullptr.cast<Pointer<Utf8>>(), 0);
    }
    final orderedIds = userIds.toList(growable: false)..sort();
    final pointers = calloc<Pointer<Utf8>>(orderedIds.length);
    try {
      for (var index = 0; index < orderedIds.length; index += 1) {
        pointers[index] = orderedIds[index].toNativeUtf8();
      }
      return callback(pointers, orderedIds.length);
    } finally {
      for (var index = 0; index < orderedIds.length; index += 1) {
        calloc.free(pointers[index]);
      }
      calloc.free(pointers);
    }
  }

  Uint8List _transformFrame({
    required Uint8List frame,
    required int capacity,
    required int Function(
      Pointer<Uint8> input,
      Pointer<Uint8> output,
      Pointer<Size> bytesWritten,
    )
    transform,
    required String operationName,
  }) {
    if (capacity < frame.length) {
      throw StateError('$operationName 출력 buffer 크기가 올바르지 않습니다.');
    }
    final input = calloc<Uint8>(frame.length);
    final output = calloc<Uint8>(capacity);
    final bytesWritten = calloc<Size>();
    try {
      input.asTypedList(frame.length).setAll(0, frame);
      final result = transform(input, output, bytesWritten);
      if (result != successResult) {
        throw StateError('$operationName에 실패했습니다. libdave code: $result');
      }
      return Uint8List.fromList(output.asTypedList(bytesWritten.value));
    } finally {
      calloc.free(bytesWritten);
      calloc.free(output);
      calloc.free(input);
    }
  }

  DaveHandle _requireHandle(DaveHandle handle, {required String resourceName}) {
    if (handle == nullptr) {
      throw StateError('libdave $resourceName 생성에 실패했습니다.');
    }
    return handle;
  }
}
