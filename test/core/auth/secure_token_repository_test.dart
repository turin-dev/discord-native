import 'package:discord_native/core/auth/secure_token_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecureTokenRepository', () {
    test('검증한 토큰만 저장한다', () async {
      final storage = _MemorySecretStorage();
      final repository = SecureTokenRepository(storage);

      await repository.save('  abc.def.ghi  ');

      expect(
        await storage.read(key: SecureTokenRepository.tokenKey),
        'abc.def.ghi',
      );
    });

    test('손상된 저장 토큰은 삭제하고 null을 반환한다', () async {
      final storage = _MemorySecretStorage({
        SecureTokenRepository.tokenKey: 'invalid token',
      });
      final repository = SecureTokenRepository(storage);

      expect(await repository.load(), isNull);
      expect(await storage.read(key: SecureTokenRepository.tokenKey), isNull);
    });

    test('로그아웃 시 저장 토큰을 삭제한다', () async {
      final storage = _MemorySecretStorage({
        SecureTokenRepository.tokenKey: 'abc.def.ghi',
      });
      final repository = SecureTokenRepository(storage);

      await repository.clear();

      expect(await repository.load(), isNull);
    });
  });
}

final class _MemorySecretStorage implements SecretStorage {
  _MemorySecretStorage([Map<String, String>? values])
    : _values = Map.unmodifiable(values ?? const {});

  Map<String, String> _values;

  @override
  Future<void> delete({required String key}) async {
    _values = Map.unmodifiable({
      for (final entry in _values.entries)
        if (entry.key != key) entry.key: entry.value,
    });
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _values = Map.unmodifiable({..._values, key: value});
  }
}
