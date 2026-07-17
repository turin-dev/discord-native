import 'dart:async';

import 'package:discord_native/core/auth/discord_account_repository.dart';

final class DiscordAccountSessionState {
  const DiscordAccountSessionState({
    this.accounts = const [],
    this.selectedAccountId,
    this.errorMessage,
  });

  final List<SavedDiscordAccount> accounts;
  final String? selectedAccountId;
  final String? errorMessage;
}

final class MissingDiscordAccountTokenException implements Exception {
  const MissingDiscordAccountTokenException(this.accountId);

  final String accountId;

  @override
  String toString() => '저장된 계정 토큰을 찾을 수 없습니다: $accountId';
}

final class DiscordAccountSessionController {
  DiscordAccountSessionController(this._repository);

  final DiscordAccountRepository _repository;
  final StreamController<DiscordAccountSessionState> _states =
      StreamController.broadcast();

  DiscordAccountSessionState _state = const DiscordAccountSessionState();
  String? _pendingToken;
  bool _initialized = false;
  bool _disposed = false;

  DiscordAccountSessionState get state => _state;

  Stream<DiscordAccountSessionState> get states async* {
    yield _state;
    yield* _states.stream;
  }

  Future<String?> initialize() async {
    _ensureActive();
    if (_initialized) {
      final selectedId = _state.selectedAccountId;
      return selectedId == null ? null : _repository.loadToken(selectedId);
    }
    _initialized = true;
    final accounts = await _repository.loadAll();
    final storedSelectedId = await _repository.loadSelectedId();
    final selectedId = accounts.any((account) => account.id == storedSelectedId)
        ? storedSelectedId
        : null;
    if (storedSelectedId != null && selectedId == null) {
      await _repository.select(null);
    }
    _update(
      DiscordAccountSessionState(
        accounts: List.unmodifiable(accounts),
        selectedAccountId: selectedId,
      ),
    );
    return selectedId == null ? null : _repository.loadToken(selectedId);
  }

  void tokenConnected(String token) {
    _ensureActive();
    if (token.trim().isEmpty) {
      throw const FormatException('연결 토큰이 비어 있습니다.');
    }
    _pendingToken = token;
  }

  Future<void> completeConnection(SavedDiscordAccount account) async {
    _ensureActive();
    final token = _pendingToken;
    if (token == null) {
      return;
    }
    await _repository.save(account, token);
    await _repository.select(account.id);
    _pendingToken = null;
    await _reload(selectedAccountId: account.id);
  }

  Future<String> selectAccount(String accountId) async {
    _ensureActive();
    final token = await _repository.loadToken(accountId);
    if (token == null || token.isEmpty) {
      throw MissingDiscordAccountTokenException(accountId);
    }
    await _repository.select(accountId);
    _pendingToken = token;
    _update(
      DiscordAccountSessionState(
        accounts: _state.accounts,
        selectedAccountId: accountId,
      ),
    );
    return token;
  }

  Future<void> removeAccount(String accountId) async {
    _ensureActive();
    await _repository.remove(accountId);
    final selectedId = _state.selectedAccountId == accountId
        ? null
        : _state.selectedAccountId;
    await _reload(selectedAccountId: selectedId);
  }

  Future<void> clearSelection() async {
    _ensureActive();
    _pendingToken = null;
    await _repository.select(null);
    _update(
      DiscordAccountSessionState(
        accounts: _state.accounts,
        selectedAccountId: null,
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _states.close();
  }

  Future<void> _reload({required String? selectedAccountId}) async {
    final accounts = await _repository.loadAll();
    _update(
      DiscordAccountSessionState(
        accounts: List.unmodifiable(accounts),
        selectedAccountId: selectedAccountId,
      ),
    );
  }

  void _update(DiscordAccountSessionState next) {
    _state = next;
    if (!_states.isClosed) {
      _states.add(next);
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('DiscordAccountSessionController가 이미 종료되었습니다.');
    }
  }
}
