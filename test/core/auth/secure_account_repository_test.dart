import 'package:discord_native/core/auth/discord_account_repository.dart';
import 'package:discord_native/core/auth/secure_token_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecureDiscordAccountRepository', () {
    test('계정 메타데이터와 토큰을 서로 다른 보안 키에 저장한다', () async {
      final storage = _MemorySecretStorage();
      final repository = SecureDiscordAccountRepository(storage);
      const account = SavedDiscordAccount(
        id: 'user-1',
        username: 'alice',
        displayName: 'Alice',
        avatarHash: 'avatar',
      );

      await repository.save(account, 'token-one');

      expect(await repository.loadAll(), [account]);
      expect(await repository.loadToken('user-1'), 'token-one');
      expect(storage.values['discord_accounts'], isNot(contains('token-one')));
      expect(storage.values['discord_account_token_user-1'], 'token-one');
    });

    test('같은 계정 저장은 메타데이터를 교체하고 순서를 유지한다', () async {
      final storage = _MemorySecretStorage();
      final repository = SecureDiscordAccountRepository(storage);
      await repository.save(
        const SavedDiscordAccount(id: 'user-1', username: 'before'),
        'token-one',
      );

      await repository.save(
        const SavedDiscordAccount(id: 'user-1', username: 'after'),
        'token-two',
      );

      expect(await repository.loadAll(), [
        const SavedDiscordAccount(id: 'user-1', username: 'after'),
      ]);
      expect(await repository.loadToken('user-1'), 'token-two');
    });

    test('계정 삭제는 해당 토큰과 선택 상태만 제거한다', () async {
      final storage = _MemorySecretStorage();
      final repository = SecureDiscordAccountRepository(storage);
      await repository.save(
        const SavedDiscordAccount(id: 'user-1', username: 'alice'),
        'token-one',
      );
      await repository.save(
        const SavedDiscordAccount(id: 'user-2', username: 'bob'),
        'token-two',
      );
      await repository.select('user-1');

      await repository.remove('user-1');

      expect(await repository.loadAll(), [
        const SavedDiscordAccount(id: 'user-2', username: 'bob'),
      ]);
      expect(await repository.loadToken('user-1'), isNull);
      expect(await repository.loadSelectedId(), isNull);
      expect(await repository.loadToken('user-2'), 'token-two');
    });

    test('손상된 인덱스는 토큰을 노출하지 않고 빈 목록으로 복구한다', () async {
      final storage = _MemorySecretStorage()
        ..values['discord_accounts'] = '{broken';
      final repository = SecureDiscordAccountRepository(storage);

      expect(await repository.loadAll(), isEmpty);
    });
  });
}

final class _MemorySecretStorage implements SecretStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
