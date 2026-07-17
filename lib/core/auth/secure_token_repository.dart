import 'package:discord_native/core/auth/token_validator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecretStorage {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

abstract interface class TokenRepository {
  Future<String?> load();

  Future<void> save(String input);

  Future<void> clear();
}

final class FlutterSecretStorage implements SecretStorage {
  const FlutterSecretStorage(this._storage);

  factory FlutterSecretStorage.platformDefault() {
    return const FlutterSecretStorage(FlutterSecureStorage());
  }

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

final class SecureTokenRepository implements TokenRepository {
  const SecureTokenRepository(this._storage);

  static const String tokenKey = 'discord_user_token';

  final SecretStorage _storage;

  @override
  Future<String?> load() async {
    final storedToken = await _storage.read(key: tokenKey);
    if (storedToken == null) {
      return null;
    }
    try {
      return TokenValidator.validate(storedToken);
    } on InvalidTokenException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(String input) {
    final token = TokenValidator.validate(input);
    return _storage.write(key: tokenKey, value: token);
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: tokenKey);
  }
}
