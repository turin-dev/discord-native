part of 'discord_app_controller.dart';

extension DiscordAppControllerClientApi on DiscordAppController {
  Future<void> votePoll(DiscordMessage message, int answerId) async {
    final repository = _messageRepository;
    final current = _state.messageState.messages
        .where((item) => item.id == message.id)
        .firstOrNull;
    final poll = current?.poll;
    if (repository == null ||
        current == null ||
        poll == null ||
        poll.finalized) {
      return;
    }
    if (!poll.answers.any((answer) => answer.id == answerId)) {
      throw const InvalidMessageException('투표 답변이 올바르지 않습니다.');
    }
    final selectedIds = _nextPollSelection(poll, answerId);
    try {
      await repository.votePoll(current.channelId, current.id, selectedIds);
      if (_state.messageState.channelId == current.channelId) {
        _update(
          _state.copyWith(
            messageState: _state.messageState.setPollSelection(
              current.id,
              selectedIds,
            ),
          ),
        );
      }
    } on Object catch (error) {
      throw InvalidMessageException(_privateClientActionError(error, '투표'));
    }
  }

  void _markChannelRead(String channelId, String? messageId) {
    final current =
        _state.readStates[channelId] ?? DiscordReadState.initial(channelId);
    if (current.unreadCount == 0 &&
        (messageId == null || current.lastReadMessageId == messageId)) {
      return;
    }
    _setReadState(current.markRead(messageId, _now()));
    if (messageId != null) {
      _queueReadAck(channelId, messageId);
    }
  }

  void _incrementUnread(String channelId) {
    final current =
        _state.readStates[channelId] ?? DiscordReadState.initial(channelId);
    _setReadState(current.incrementUnread(_now()));
  }

  void _setReadState(DiscordReadState next) {
    _setReadStates([next]);
  }

  void _setReadStates(Iterable<DiscordReadState> values) {
    final nextValues = List<DiscordReadState>.unmodifiable(values);
    if (nextValues.isEmpty) {
      return;
    }
    var readStates = _state.readStates;
    for (final value in nextValues) {
      readStates = Map.unmodifiable({...readStates, value.channelId: value});
    }
    _update(_state.copyWith(readStates: readStates));
    final repository = _readStateRepository;
    if (repository != null) {
      for (final value in nextValues) {
        _queueReadStatePersistence(repository, value);
      }
    }
  }

  void _queueReadStatePersistence(
    ReadStateRepository repository,
    DiscordReadState next,
  ) {
    final pending = _readStateWrite;
    _readStateWrite = pending == null
        ? _persistReadState(repository, next)
        : pending.then((_) => _persistReadState(repository, next));
  }

  Future<void> _persistReadState(
    ReadStateRepository repository,
    DiscordReadState state,
  ) async {
    try {
      await repository.save(state);
    } on Object catch (error) {
      if (!_disposed) {
        _showMessageError(error);
      }
    }
  }

  void _queueReadAck(String channelId, String messageId) {
    final repository = _clientSyncRepository;
    if (repository == null || _clientSyncDisabled) {
      return;
    }
    final pending = _readAckWrite;
    _readAckWrite = pending == null
        ? _syncReadAck(repository, channelId, messageId)
        : pending.then((_) => _syncReadAck(repository, channelId, messageId));
  }

  Future<void> _syncReadAck(
    ClientSyncRepository repository,
    String channelId,
    String messageId,
  ) async {
    if (_clientSyncDisabled) {
      return;
    }
    try {
      await repository.acknowledgeRead(channelId, messageId);
      if (!_disposed && _state.clientApiWarning != null) {
        _update(_state.copyWith(clientApiWarning: null));
      }
    } on Object catch (error) {
      if (_isUnsupportedClientApi(error)) {
        _clientSyncDisabled = true;
      }
      if (!_disposed) {
        _update(
          _state.copyWith(
            clientApiWarning: 'Discord 읽음 동기화를 사용할 수 없습니다. 읽음 상태는 로컬에는 저장됩니다.',
          ),
        );
      }
    }
  }

  void _receiveReadyReadStates(Object? rawData) {
    if (rawData is! Map) {
      return;
    }
    final entries = _readReadyReadStateEntries(rawData['read_state']);
    final replacements = <DiscordReadState>[];
    for (final entry in entries) {
      final remote = _remoteReadState(entry);
      if (remote == null) {
        continue;
      }
      final local = _state.readStates[remote.channelId];
      final localMessageId = local?.lastReadMessageId;
      if (localMessageId != null &&
          _compareSnowflakes(localMessageId, remote.messageId) > 0) {
        _queueReadAck(remote.channelId, localMessageId);
        continue;
      }
      final next = _readStateFromRemote(
        remote,
        fallbackUnreadCount: localMessageId == remote.messageId
            ? local?.unreadCount ?? 0
            : 0,
      );
      if (local?.lastReadMessageId != next.lastReadMessageId ||
          local?.unreadCount != next.unreadCount) {
        replacements.add(next);
      }
    }
    _setReadStates(replacements);
  }

  void _receiveMessageAck(Object? rawData) {
    if (rawData is! Map || _optionalReadInt(rawData['ack_type']) > 0) {
      return;
    }
    final channelId = rawData['channel_id'];
    final messageId = rawData['message_id'];
    if (channelId is! String || messageId is! String) {
      return;
    }
    final current = _state.readStates[channelId];
    final currentMessageId = current?.lastReadMessageId;
    final manual = rawData['manual'] == true;
    if (!manual &&
        currentMessageId != null &&
        _compareSnowflakes(currentMessageId, messageId) > 0) {
      return;
    }
    final next = _remoteReadStateValue(
      channelId,
      messageId,
      fallbackUnreadCount: current?.unreadCount ?? 0,
    );
    if (current?.lastReadMessageId == next.lastReadMessageId &&
        current?.unreadCount == next.unreadCount) {
      return;
    }
    _setReadState(next);
  }

  void _reconcileWorkspaceReadStates() {
    final replacements = <DiscordReadState>[];
    for (final entry in _state.readStates.entries) {
      final latest = _state.workspace.channelById(entry.key)?.lastMessageId;
      if (latest == null) {
        continue;
      }
      if (entry.key == _state.selectedChannelId) {
        _markChannelRead(entry.key, latest);
        continue;
      }
      final nextUnread = _unreadCountFor(
        entry.key,
        entry.value.lastReadMessageId,
        fallbackUnreadCount: entry.value.unreadCount,
      );
      if (nextUnread != entry.value.unreadCount) {
        replacements.add(
          DiscordReadState(
            channelId: entry.key,
            lastReadMessageId: entry.value.lastReadMessageId,
            unreadCount: nextUnread,
            updatedAt: _now().toUtc(),
          ),
        );
      }
    }
    _setReadStates(replacements);
  }

  DiscordReadState _readStateFromRemote(
    _RemoteReadState remote, {
    int fallbackUnreadCount = 0,
  }) {
    return _remoteReadStateValue(
      remote.channelId,
      remote.messageId,
      fallbackUnreadCount: fallbackUnreadCount,
    );
  }

  DiscordReadState _remoteReadStateValue(
    String channelId,
    String messageId, {
    int fallbackUnreadCount = 0,
  }) {
    return DiscordReadState(
      channelId: channelId,
      lastReadMessageId: messageId,
      unreadCount: _unreadCountFor(
        channelId,
        messageId,
        fallbackUnreadCount: fallbackUnreadCount,
      ),
      updatedAt: _now().toUtc(),
    );
  }

  int _unreadCountFor(
    String channelId,
    String? lastReadMessageId, {
    int fallbackUnreadCount = 0,
  }) {
    final latest = _state.workspace.channelById(channelId)?.lastMessageId;
    if (latest == null) {
      return fallbackUnreadCount;
    }
    if (lastReadMessageId == null ||
        _compareSnowflakes(latest, lastReadMessageId) > 0) {
      return fallbackUnreadCount > 0 ? fallbackUnreadCount : 1;
    }
    return 0;
  }
}

typedef _RemoteReadState = ({String channelId, String messageId});

List<Object?> _readReadyReadStateEntries(Object? rawReadState) {
  final rawEntries = switch (rawReadState) {
    final List value => value,
    final Map value when value['entries'] is List => value['entries']! as List,
    _ => const <Object?>[],
  };
  return List<Object?>.unmodifiable(rawEntries);
}

_RemoteReadState? _remoteReadState(Object? rawEntry) {
  if (rawEntry is! Map || _optionalReadInt(rawEntry['read_state_type']) > 0) {
    return null;
  }
  final channelId = rawEntry['id'];
  final messageId = rawEntry['last_message_id'];
  if (channelId is! String || messageId is! String) {
    return null;
  }
  return (channelId: channelId, messageId: messageId);
}

int _optionalReadInt(Object? value) {
  return switch (value) {
    final num number => number.toInt(),
    _ => 0,
  };
}

int _compareSnowflakes(String left, String right) {
  final leftValue = BigInt.tryParse(left);
  final rightValue = BigInt.tryParse(right);
  if (leftValue != null && rightValue != null) {
    return leftValue.compareTo(rightValue);
  }
  return left.compareTo(right);
}

Set<int> _nextPollSelection(DiscordPoll poll, int answerId) {
  final selectedIds = {
    for (final answer in poll.answers)
      if (answer.meVoted) answer.id,
  };
  if (poll.allowMultiselect) {
    return selectedIds.contains(answerId)
        ? Set.unmodifiable(selectedIds.where((id) => id != answerId))
        : Set.unmodifiable({...selectedIds, answerId});
  }
  return selectedIds.contains(answerId)
      ? const <int>{}
      : Set<int>.unmodifiable({answerId});
}

String _privateClientActionError(Object error, String action) {
  if (error is DiscordHttpException) {
    return switch (error.statusCode) {
      401 || 403 => 'Discord가 이 계정의 $action 요청을 허용하지 않았습니다.',
      404 => 'Discord $action API가 변경되었거나 지원되지 않습니다.',
      _ => 'Discord $action 요청에 실패했습니다. 잠시 후 다시 시도해 주세요.',
    };
  }
  return 'Discord $action 요청에 실패했습니다. 네트워크 상태를 확인해 주세요.';
}

bool _isUnsupportedClientApi(Object error) {
  return error is DiscordHttpException &&
      (error.statusCode == 401 ||
          error.statusCode == 403 ||
          error.statusCode == 404);
}
