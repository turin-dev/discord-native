import 'package:discord_native/core/auth/discord_account_repository.dart';
import 'package:discord_native/core/auth/discord_account_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordAccountSessionController', () {
    test('선택된 저장 계정의 토큰을 초기 연결에 제공한다', () async {
      final repository = _MemoryAccountRepository(
        accounts: const [SavedDiscordAccount(id: 'user-1', username: 'alice')],
        tokens: const {'user-1': 'token-one'},
        selectedId: 'user-1',
      );
      final controller = DiscordAccountSessionController(repository);
      addTearDown(controller.dispose);

      final token = await controller.initialize();

      expect(token, 'token-one');
      expect(controller.state.selectedAccountId, 'user-1');
      expect(controller.state.accounts, repository.accounts);
    });

    test('READY 계정을 pending 토큰과 함께 저장하고 선택한다', () async {
      final repository = _MemoryAccountRepository();
      final controller = DiscordAccountSessionController(repository);
      addTearDown(controller.dispose);
      await controller.initialize();
      controller.tokenConnected('token-one');

      await controller.completeConnection(
        const SavedDiscordAccount(id: 'user-1', username: 'alice'),
      );

      expect(repository.tokens['user-1'], 'token-one');
      expect(repository.selectedId, 'user-1');
      expect(controller.state.selectedAccountId, 'user-1');
      expect(controller.state.accounts.single.username, 'alice');
    });

    test('계정 전환은 저장 토큰만 반환하고 선택 상태를 갱신한다', () async {
      final repository = _MemoryAccountRepository(
        accounts: const [
          SavedDiscordAccount(id: 'user-1', username: 'alice'),
          SavedDiscordAccount(id: 'user-2', username: 'bob'),
        ],
        tokens: const {'user-1': 'token-one', 'user-2': 'token-two'},
        selectedId: 'user-1',
      );
      final controller = DiscordAccountSessionController(repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      final token = await controller.selectAccount('user-2');

      expect(token, 'token-two');
      expect(repository.selectedId, 'user-2');
      expect(controller.state.selectedAccountId, 'user-2');
    });

    test('토큰이 없는 계정은 명시적인 오류를 반환한다', () async {
      final repository = _MemoryAccountRepository(
        accounts: const [SavedDiscordAccount(id: 'user-1', username: 'alice')],
      );
      final controller = DiscordAccountSessionController(repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      expect(
        () => controller.selectAccount('user-1'),
        throwsA(isA<MissingDiscordAccountTokenException>()),
      );
    });

    test('현재 계정 삭제 후 선택을 해제하고 나머지 계정을 유지한다', () async {
      final repository = _MemoryAccountRepository(
        accounts: const [
          SavedDiscordAccount(id: 'user-1', username: 'alice'),
          SavedDiscordAccount(id: 'user-2', username: 'bob'),
        ],
        tokens: const {'user-1': 'token-one', 'user-2': 'token-two'},
        selectedId: 'user-1',
      );
      final controller = DiscordAccountSessionController(repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.removeAccount('user-1');

      expect(controller.state.selectedAccountId, isNull);
      expect(controller.state.accounts.map((account) => account.id), [
        'user-2',
      ]);
      expect(repository.tokens.containsKey('user-1'), isFalse);
    });

    test('중복 initialize와 명시적인 선택 해제를 지원한다', () async {
      final repository = _MemoryAccountRepository(
        accounts: const [SavedDiscordAccount(id: 'user-1', username: 'alice')],
        tokens: const {'user-1': 'token-one'},
        selectedId: 'user-1',
      );
      final controller = DiscordAccountSessionController(repository);
      addTearDown(controller.dispose);

      expect(await controller.initialize(), 'token-one');
      expect(await controller.initialize(), 'token-one');
      await controller.clearSelection();

      expect(controller.state.selectedAccountId, isNull);
      expect(repository.selectedId, isNull);
    });

    test('pending token 없는 중복 READY는 기존 계정을 변경하지 않는다', () async {
      final repository = _MemoryAccountRepository(
        accounts: const [SavedDiscordAccount(id: 'user-1', username: 'alice')],
      );
      final controller = DiscordAccountSessionController(repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.completeConnection(
        const SavedDiscordAccount(id: 'user-1', username: 'changed'),
      );

      expect(repository.accounts.single.username, 'alice');
    });

    test('빈 연결 토큰과 dispose 이후 접근을 거부한다', () async {
      final controller = DiscordAccountSessionController(
        _MemoryAccountRepository(),
      );

      expect(() => controller.tokenConnected('  '), throwsFormatException);
      await controller.dispose();
      expect(controller.initialize, throwsStateError);
    });
  });
}

final class _MemoryAccountRepository implements DiscordAccountRepository {
  _MemoryAccountRepository({
    List<SavedDiscordAccount> accounts = const [],
    Map<String, String> tokens = const {},
    this.selectedId,
  }) : accounts = List.of(accounts),
       tokens = Map.of(tokens);

  List<SavedDiscordAccount> accounts;
  Map<String, String> tokens;
  String? selectedId;

  @override
  Future<List<SavedDiscordAccount>> loadAll() async => List.of(accounts);

  @override
  Future<String?> loadSelectedId() async => selectedId;

  @override
  Future<String?> loadToken(String accountId) async => tokens[accountId];

  @override
  Future<void> remove(String accountId) async {
    accounts = accounts.where((account) => account.id != accountId).toList();
    tokens = {
      for (final entry in tokens.entries)
        if (entry.key != accountId) entry.key: entry.value,
    };
    if (selectedId == accountId) {
      selectedId = null;
    }
  }

  @override
  Future<void> save(SavedDiscordAccount account, String token) async {
    accounts = [
      for (final current in accounts)
        if (current.id == account.id) account else current,
      if (!accounts.any((current) => current.id == account.id)) account,
    ];
    tokens = {...tokens, account.id: token};
  }

  @override
  Future<void> select(String? accountId) async {
    selectedId = accountId;
  }
}
