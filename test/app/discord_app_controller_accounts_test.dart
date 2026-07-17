import 'dart:async';

import 'package:discord_native/app/discord_app_controller.dart';
import 'package:discord_native/core/auth/discord_account_repository.dart';
import 'package:discord_native/core/auth/discord_account_session_controller.dart';
import 'package:discord_native/core/auth/secure_token_repository.dart';
import 'package:discord_native/core/gateway/discord_gateway_client.dart';
import 'package:discord_native/core/gateway/gateway_session_state.dart';
import 'package:discord_native/features/messages/data/discord_message_repository.dart';
import 'package:discord_native/features/messages/data/message_cache_repository.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordAppController 다중 계정', () {
    late _FakeGateway gateway;
    late _FakeAccountRepository accountRepository;
    late DiscordAccountSessionController accounts;
    late DiscordAppController controller;

    tearDown(() async {
      await controller.dispose();
      await accounts.dispose();
      await gateway.disposeStreams();
    });

    test('선택된 계정 토큰을 legacy 토큰보다 먼저 자동 연결한다', () async {
      gateway = _FakeGateway();
      accountRepository = _FakeAccountRepository(
        accounts: const [SavedDiscordAccount(id: 'user-1', username: 'alice')],
        tokens: const {'user-1': 'account-token'},
        selectedId: 'user-1',
      );
      accounts = DiscordAccountSessionController(accountRepository);
      controller = DiscordAppController(
        tokenRepository: _FakeTokenRepository('legacy-token'),
        gateway: gateway,
        accountSession: accounts,
      );

      await controller.initialize();

      expect(gateway.connectedToken, 'account-token');
    });

    test('READY 사용자를 현재 연결 토큰과 함께 계정 목록에 저장한다', () async {
      gateway = _FakeGateway();
      accountRepository = _FakeAccountRepository();
      accounts = DiscordAccountSessionController(accountRepository);
      controller = DiscordAppController(
        tokenRepository: _FakeTokenRepository(),
        gateway: gateway,
        accountSession: accounts,
      );
      await controller.initialize();
      await controller.connect('manual-token');

      gateway.emitEvent({
        'op': 0,
        't': 'READY',
        'd': {
          'user': {'id': 'user-1', 'username': 'alice', 'global_name': 'Alice'},
          'guilds': [],
        },
      });
      await pumpEventQueue();

      expect(accountRepository.tokens['user-1'], 'manual-token');
      expect(accounts.state.selectedAccountId, 'user-1');
      expect(accounts.state.accounts.single.displayName, 'Alice');
    });

    test('계정 전환 전 기존 Gateway를 끊고 선택 토큰으로 연결한다', () async {
      gateway = _FakeGateway();
      accountRepository = _FakeAccountRepository(
        accounts: const [
          SavedDiscordAccount(id: 'user-1', username: 'alice'),
          SavedDiscordAccount(id: 'user-2', username: 'bob'),
        ],
        tokens: const {'user-1': 'token-one', 'user-2': 'token-two'},
        selectedId: 'user-1',
      );
      accounts = DiscordAccountSessionController(accountRepository);
      controller = DiscordAppController(
        tokenRepository: _FakeTokenRepository(),
        gateway: gateway,
        accountSession: accounts,
      );
      await controller.initialize();

      await controller.switchAccount('user-2');

      expect(gateway.disconnectCount, 1);
      expect(gateway.connectedToken, 'token-two');
      expect(accounts.state.selectedAccountId, 'user-2');
    });

    test('REST 조회 실패 시 현재 계정의 오프라인 캐시를 복원한다', () async {
      gateway = _FakeGateway();
      accountRepository = _FakeAccountRepository();
      accounts = DiscordAccountSessionController(accountRepository);
      final cache = _FakeMessageCacheRepository([
        _cachedMessage('cached-1', '오프라인 메시지'),
      ]);
      controller = DiscordAppController(
        tokenRepository: _FakeTokenRepository(),
        gateway: gateway,
        accountSession: accounts,
        messageRepositoryFactory: (_) => _OfflineMessageRepository(),
        messageCacheRepository: cache,
      );
      await controller.initialize();
      await controller.connect('manual-token');
      gateway.emitEvent({
        'op': 0,
        't': 'READY',
        'd': {
          'user': {'id': 'user-1', 'username': 'alice'},
          'guilds': [],
        },
      });
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue(times: 20);

      expect(controller.state.messageState.messages.single.id, 'cached-1');
      expect(controller.state.messageState.errorMessage, contains('오프라인'));
      expect(cache.loadedAccountId, 'user-1');
    });
  });
}

DiscordMessage _cachedMessage(String id, String content) {
  return DiscordMessage(
    id: id,
    channelId: 'channel-1',
    content: content,
    authorId: 'user-2',
    authorName: 'Bob',
    timestamp: DateTime.utc(2026, 7, 17, 12),
  );
}

final class _FakeTokenRepository implements TokenRepository {
  _FakeTokenRepository([this.token]);

  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> load() async => token;

  @override
  Future<void> save(String input) async => token = input;
}

final class _FakeAccountRepository implements DiscordAccountRepository {
  _FakeAccountRepository({
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
  Future<void> select(String? accountId) async => selectedId = accountId;
}

final class _FakeGateway implements DiscordGatewayConnection {
  final StreamController<GatewaySessionState> _states =
      StreamController.broadcast();
  final StreamController<Map<String, Object?>> _events =
      StreamController.broadcast();
  GatewaySessionState _state = const GatewaySessionState.disconnected();
  String? connectedToken;
  int disconnectCount = 0;

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  GatewaySessionState get state => _state;

  @override
  Stream<GatewaySessionState> get states => _states.stream;

  @override
  Future<void> connect(String input) async {
    connectedToken = input;
    _state = _state.connectionOpened();
    _states.add(_state);
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    _state = const GatewaySessionState.disconnected();
    _states.add(_state);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> updateVoiceState({
    required String guildId,
    required String? channelId,
    required bool selfMute,
    required bool selfDeaf,
  }) async {}

  void emitEvent(Map<String, Object?> event) => _events.add(event);

  Future<void> disposeStreams() async {
    await _states.close();
    await _events.close();
  }
}

final class _OfflineMessageRepository implements MessageRepository {
  @override
  Future<List<DiscordMessage>> fetchMessages(
    String channelId, {
    int limit = 50,
    String? before,
  }) async {
    throw StateError('network offline');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeMessageCacheRepository implements MessageCacheRepository {
  _FakeMessageCacheRepository(this.messages);

  final List<DiscordMessage> messages;
  String? loadedAccountId;

  @override
  Future<List<DiscordMessage>> load({
    required String accountId,
    required String channelId,
    int limit = 50,
  }) async {
    loadedAccountId = accountId;
    return List.of(messages);
  }

  @override
  Future<void> clearAccount(String accountId) async {}

  @override
  Future<void> delete({
    required String accountId,
    required String channelId,
    required String messageId,
  }) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> replace({
    required String accountId,
    required String channelId,
    required List<DiscordMessage> messages,
  }) async {}

  @override
  Future<void> save({
    required String accountId,
    required DiscordMessage message,
  }) async {}
}
