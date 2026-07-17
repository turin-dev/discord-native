part of 'discord_app_controller.dart';

extension DiscordAppControllerAccounts on DiscordAppController {
  Future<void> switchAccount(String accountId) async {
    _ensureActive();
    final pendingReadAck = _readAckWrite;
    if (pendingReadAck != null) {
      await pendingReadAck;
    }
    final accountSession = _accountSession;
    if (accountSession == null) {
      throw StateError('다중 계정 저장소가 구성되지 않았습니다.');
    }
    final token = await accountSession.selectAccount(accountId);
    await _voiceCoordinator?.reset();
    await _gateway.disconnect();
    _update(const DiscordAppState(phase: DiscordAppPhase.connecting));
    await connect(token);
  }

  Future<void> removeSavedAccount(String accountId) async {
    _ensureActive();
    final accountSession = _accountSession;
    if (accountSession == null) {
      return;
    }
    if (accountSession.state.selectedAccountId == accountId) {
      await logout();
    }
    await _messageCacheRepository?.clearAccount(accountId);
    await accountSession.removeAccount(accountId);
  }

  Future<void> logout() async {
    _ensureActive();
    await _tokenRepository.clear();
    await _accountSession?.clearSelection();
    await _voiceCoordinator?.reset();
    await _gateway.disconnect();
    final pendingReadStateWrite = _readStateWrite;
    if (pendingReadStateWrite != null) {
      await pendingReadStateWrite;
    }
    final pendingReadAck = _readAckWrite;
    if (pendingReadAck != null) {
      await pendingReadAck;
    }
    await _readStateRepository?.clear();
    _clearTypingState();
    _messageRepository = null;
    _threadRepository = null;
    _directMessageRepository = null;
    _relationshipRepository = null;
    _clientSyncRepository = null;
    _clientSyncDisabled = false;
    _update(const DiscordAppState(phase: DiscordAppPhase.signedOut));
  }

  Future<void> _completeAccountConnection(DiscordUser user) async {
    try {
      await _accountSession?.completeConnection(
        SavedDiscordAccount(
          id: user.id,
          username: user.username,
          displayName: user.displayName,
          avatarHash: user.avatarHash,
        ),
      );
    } on Object {
      _update(_state.copyWith(errorMessage: '계정 정보를 안전하게 저장하지 못했습니다.'));
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _clearTypingState();
    await _gatewayStateSubscription?.cancel();
    await _eventSubscription?.cancel();
    await _voiceStateSubscription?.cancel();
    await _voiceCoordinator?.dispose();
    await _gateway.dispose();
    final pendingReadStateWrite = _readStateWrite;
    if (pendingReadStateWrite != null) {
      await pendingReadStateWrite;
    }
    final pendingReadAck = _readAckWrite;
    if (pendingReadAck != null) {
      await pendingReadAck;
    }
    await _readStateRepository?.dispose();
    await _messageCacheRepository?.dispose();
    await _states.close();
  }
}
