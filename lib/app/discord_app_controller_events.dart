part of 'discord_app_controller.dart';

extension DiscordAppControllerEvents on DiscordAppController {
  void _subscribeToGateway() {
    _gatewayStateSubscription ??= _gateway.states.listen(_receiveGatewayState);
    _eventSubscription ??= _gateway.events.listen(_receiveEvent);
  }

  void _receiveGatewayState(GatewaySessionState gatewayState) {
    final phase = switch (gatewayState.phase) {
      GatewayPhase.ready => DiscordAppPhase.connected,
      GatewayPhase.reconnecting => DiscordAppPhase.reconnecting,
      GatewayPhase.disconnected
          when _state.phase == DiscordAppPhase.signedOut =>
        DiscordAppPhase.signedOut,
      _ => DiscordAppPhase.connecting,
    };
    _update(_state.copyWith(phase: phase));
  }

  void _receiveEvent(Map<String, Object?> event) {
    final receivedAt = _now();
    final typingUser = DiscordTypingUser.fromPayload(
      event,
      now: receivedAt,
      currentUserId: _state.workspace.currentUser?.id,
    );
    final workspace = _state.workspace.payloadReceived(event);
    final nextMessages = _state.messageState.payloadReceived(
      event,
      currentUserId: workspace.currentUser?.id,
    );
    final typingState = _state.typingState.payloadReceived(
      event,
      now: receivedAt,
      currentUserId: workspace.currentUser?.id,
    );
    final peopleState = _state.peopleState.payloadReceived(event);
    final selectedGuildId = _validGuildId(workspace, _state.selectedGuildId);
    final selectedChannelId = _validChannelId(
      workspace,
      selectedGuildId,
      _state.selectedChannelId,
    );
    final channelChanged = selectedChannelId != _state.selectedChannelId;
    _update(
      _state.copyWith(
        workspace: workspace,
        selectedGuildId: selectedGuildId,
        selectedChannelId: selectedChannelId,
        typingState: typingState,
        peopleState: peopleState,
        pinnedMessagesState: channelChanged
            ? const DiscordPinnedMessagesState()
            : _state.pinnedMessagesState,
        messageState: channelChanged
            ? DiscordMessageState(
                channelId: selectedChannelId,
                isLoading: selectedChannelId != null,
              )
            : nextMessages,
      ),
    );
    _voiceCoordinator?.receiveGatewayEvent(
      event,
      currentUserId: workspace.currentUser?.id,
    );
    if (event['t'] == 'READY' && workspace.currentUser != null) {
      unawaited(_completeAccountConnection(workspace.currentUser!));
    }
    if (typingUser != null) {
      _scheduleTypingExpiry(typingUser);
    }
    if (channelChanged && selectedChannelId != null) {
      unawaited(_loadMessages(selectedChannelId));
    }
    _receiveReadEvent(event);
    _receiveMessageNotification(event);
    _cacheGatewayMessageEvent(event);
  }

  Future<void> _loadMessages(String channelId) async {
    final repository = _messageRepository;
    if (repository == null) {
      return;
    }
    try {
      final messages = await repository.fetchMessages(channelId);
      if (_state.selectedChannelId == channelId) {
        final cacheError = await _replaceCachedMessages(channelId, messages);
        _update(
          _state.copyWith(
            messageState: DiscordMessageState(
              channelId: channelId,
              messages: messages,
              hasMore: messages.length >= _messagePageSize,
              errorMessage: cacheError,
            ),
          ),
        );
        _markChannelRead(channelId, messages.lastOrNull?.id);
      }
    } on Object catch (error) {
      if (_state.selectedChannelId == channelId) {
        final cached = await _loadCachedMessages(channelId);
        _update(
          _state.copyWith(
            messageState: DiscordMessageState(
              channelId: channelId,
              messages: cached.messages,
              errorMessage: cached.messages.isEmpty
                  ? cached.errorMessage ?? _friendlyError(error)
                  : '오프라인 캐시를 표시하고 있습니다.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadMessagesAround(String channelId, String messageId) async {
    final repository = _messageRepository;
    if (repository == null) {
      return;
    }
    try {
      final messages = await repository.fetchMessagesAround(
        channelId,
        messageId,
      );
      if (_state.selectedChannelId == channelId) {
        _update(
          _state.copyWith(
            messageState: DiscordMessageState.loaded(channelId, messages),
          ),
        );
        _markChannelRead(channelId, messageId);
      }
    } on Object catch (error) {
      if (_state.selectedChannelId == channelId) {
        _update(
          _state.copyWith(
            messageState: DiscordMessageState(
              channelId: channelId,
              errorMessage: _friendlyError(error),
            ),
          ),
        );
      }
    }
  }

  void _receiveReadEvent(Map<String, Object?> event) {
    switch (event['t']) {
      case 'READY':
        _receiveReadyReadStates(event['d']);
      case 'MESSAGE_ACK':
        _receiveMessageAck(event['d']);
      case 'GUILD_CREATE' || 'CHANNEL_UNREAD_UPDATE':
        _reconcileWorkspaceReadStates();
      case 'MESSAGE_CREATE':
        _receiveMessageCreateRead(event['d']);
    }
  }

  void _receiveMessageCreateRead(Object? rawData) {
    if (rawData is! Map) {
      return;
    }
    final channelId = rawData['channel_id'];
    final messageId = rawData['id'];
    if (channelId is! String || messageId is! String) {
      return;
    }
    if (channelId == _state.selectedChannelId) {
      _markChannelRead(channelId, messageId);
      return;
    }
    final rawAuthor = rawData['author'];
    final authorId = rawAuthor is Map ? rawAuthor['id'] : null;
    if (authorId != _state.workspace.currentUser?.id) {
      _incrementUnread(channelId);
    }
  }

  void _receiveMessageNotification(Map<String, Object?> event) {
    final callback = _messageNotificationCallback;
    final notification = DiscordMessageNotification.fromGatewayEvent(
      event,
      currentUserId: _state.workspace.currentUser?.id,
      selectedChannelId: _state.selectedChannelId,
    );
    if (callback == null || notification == null) {
      return;
    }
    unawaited(_deliverMessageNotification(callback, notification));
  }

  Future<void> _deliverMessageNotification(
    MessageNotificationCallback callback,
    DiscordMessageNotification notification,
  ) async {
    try {
      await callback(notification);
    } on Object {
      _update(_state.copyWith(errorMessage: 'Windows 알림을 표시하지 못했습니다.'));
    }
  }

  Future<String?> _replaceCachedMessages(
    String channelId,
    List<DiscordMessage> messages,
  ) async {
    final accountId = _state.workspace.currentUser?.id;
    final cache = _messageCacheRepository;
    if (accountId == null || cache == null) {
      return null;
    }
    try {
      await cache.replace(
        accountId: accountId,
        channelId: channelId,
        messages: messages,
      );
      return null;
    } on Object {
      return '메시지는 불러왔지만 오프라인 캐시에 저장하지 못했습니다.';
    }
  }

  Future<({List<DiscordMessage> messages, String? errorMessage})>
  _loadCachedMessages(String channelId) async {
    final accountId = _state.workspace.currentUser?.id;
    final cache = _messageCacheRepository;
    if (accountId == null || cache == null) {
      return (messages: const <DiscordMessage>[], errorMessage: null);
    }
    try {
      final messages = await cache.load(
        accountId: accountId,
        channelId: channelId,
      );
      return (messages: messages, errorMessage: null);
    } on Object {
      return (
        messages: const <DiscordMessage>[],
        errorMessage: '네트워크와 오프라인 캐시에서 메시지를 불러오지 못했습니다.',
      );
    }
  }

  void _cacheGatewayMessageEvent(Map<String, Object?> event) {
    final accountId = _state.workspace.currentUser?.id;
    final cache = _messageCacheRepository;
    final data = event['d'];
    if (accountId == null || cache == null || data is! Map) {
      return;
    }
    final channelId = data['channel_id'];
    final messageId = data['id'];
    if (channelId is! String || messageId is! String) {
      return;
    }
    final operation = switch (event['t']) {
      'MESSAGE_CREATE' => _saveGatewayMessage(cache, accountId, data),
      'MESSAGE_UPDATE' => _saveUpdatedGatewayMessage(
        cache,
        accountId,
        messageId,
      ),
      'MESSAGE_DELETE' => cache.delete(
        accountId: accountId,
        channelId: channelId,
        messageId: messageId,
      ),
      _ => null,
    };
    if (operation != null) {
      unawaited(_guardCacheWrite(operation));
    }
  }

  Future<void> _saveGatewayMessage(
    MessageCacheRepository cache,
    String accountId,
    Map<Object?, Object?> data,
  ) {
    final payload = data.map((key, value) => MapEntry(key.toString(), value));
    return cache.save(
      accountId: accountId,
      message: DiscordMessage.fromJson(payload),
    );
  }

  Future<void>? _saveUpdatedGatewayMessage(
    MessageCacheRepository cache,
    String accountId,
    String messageId,
  ) {
    final message = _state.messageState.messages
        .where((item) => item.id == messageId)
        .firstOrNull;
    return message == null
        ? null
        : cache.save(accountId: accountId, message: message);
  }

  Future<void> _guardCacheWrite(Future<void> operation) async {
    try {
      await operation;
    } on Object {
      _update(_state.copyWith(errorMessage: '새 메시지를 오프라인 캐시에 저장하지 못했습니다.'));
    }
  }
}
