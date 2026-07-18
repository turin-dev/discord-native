import 'dart:async';

import 'package:collection/collection.dart';
import 'package:discord_native/app/discord_app_state.dart';
import 'package:discord_native/app/typing_expiry_scheduler.dart';
import 'package:discord_native/core/auth/discord_account_repository.dart';
import 'package:discord_native/core/auth/discord_account_session_controller.dart';
import 'package:discord_native/core/auth/secure_token_repository.dart';
import 'package:discord_native/core/gateway/discord_gateway_client.dart';
import 'package:discord_native/core/gateway/gateway_session_state.dart';
import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/messages/data/attachment_download_service.dart';
import 'package:discord_native/features/messages/data/discord_message_repository.dart';
import 'package:discord_native/features/messages/data/message_cache_repository.dart';
import 'package:discord_native/features/messages/domain/discord_message_search_state.dart';
import 'package:discord_native/features/messages/domain/discord_pinned_messages_state.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/messages/domain/discord_typing_state.dart';
import 'package:discord_native/features/system/domain/discord_message_notification.dart';
import 'package:discord_native/features/voice/data/discord_voice_coordinator.dart';
import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';
import 'package:discord_native/features/workspace/data/discord_direct_message_repository.dart';
import 'package:discord_native/features/workspace/data/discord_channel_management_repository.dart';
import 'package:discord_native/features/workspace/data/discord_client_sync_repository.dart';
import 'package:discord_native/features/workspace/data/discord_relationship_repository.dart';
import 'package:discord_native/features/workspace/data/discord_role_repository.dart';
import 'package:discord_native/features/workspace/data/discord_invite_repository.dart';
import 'package:discord_native/features/workspace/data/discord_scheduled_event_repository.dart';
import 'package:discord_native/features/workspace/data/read_state_repository.dart';
import 'package:discord_native/features/workspace/data/discord_thread_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_scheduled_event.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';

export 'package:discord_native/app/discord_app_state.dart';

part 'discord_app_controller_typing.dart';
part 'discord_app_controller_events.dart';
part 'discord_app_controller_relationships.dart';
part 'discord_app_controller_guilds.dart';
part 'discord_app_controller_voice.dart';
part 'discord_app_controller_accounts.dart';
part 'discord_app_controller_client_api.dart';

typedef MessageRepositoryFactory = MessageRepository Function(String token);
typedef ThreadRepositoryFactory = ThreadRepository Function(String token);
typedef DirectMessageRepositoryFactory =
    DirectMessageRepository Function(String token);
typedef RelationshipRepositoryFactory =
    RelationshipRepository Function(String token);
typedef ChannelManagementRepositoryFactory =
    ChannelManagementRepository Function(String token);
typedef RoleRepositoryFactory = RoleRepository Function(String token);
typedef InviteRepositoryFactory = InviteRepository Function(String token);
typedef ScheduledEventRepositoryFactory =
    ScheduledEventRepository Function(String token);
typedef ClientSyncRepositoryFactory =
    ClientSyncRepository Function(String token);
typedef NowCallback = DateTime Function();
typedef MessageNotificationCallback =
    Future<void> Function(DiscordMessageNotification notification);

final class DiscordAppController {
  DiscordAppController({
    required TokenRepository tokenRepository,
    required DiscordGatewayConnection gateway,
    DiscordAccountSessionController? accountSession,
    MessageNotificationCallback? messageNotificationCallback,
    MessageCacheRepository? messageCacheRepository,
    DiscordVoiceCoordinator? voiceCoordinator,
    AttachmentDownloadService? attachmentDownloadService,
    MessageRepositoryFactory? messageRepositoryFactory,
    ThreadRepositoryFactory? threadRepositoryFactory,
    DirectMessageRepositoryFactory? directMessageRepositoryFactory,
    RelationshipRepositoryFactory? relationshipRepositoryFactory,
    ChannelManagementRepositoryFactory? channelManagementRepositoryFactory,
    RoleRepositoryFactory? roleRepositoryFactory,
    InviteRepositoryFactory? inviteRepositoryFactory,
    ScheduledEventRepositoryFactory? scheduledEventRepositoryFactory,
    ClientSyncRepositoryFactory? clientSyncRepositoryFactory,
    ReadStateRepository? readStateRepository,
    TypingExpiryScheduler typingExpiryScheduler =
        const TimerTypingExpiryScheduler(),
    NowCallback now = DateTime.now,
  }) : _tokenRepository = tokenRepository,
       _gateway = gateway,
       _accountSession = accountSession,
       _messageNotificationCallback = messageNotificationCallback,
       _messageCacheRepository = messageCacheRepository,
       _voiceCoordinator = voiceCoordinator,
       _attachmentDownloadService = attachmentDownloadService,
       _messageRepositoryFactory = messageRepositoryFactory,
       _threadRepositoryFactory = threadRepositoryFactory,
       _directMessageRepositoryFactory = directMessageRepositoryFactory,
       _relationshipRepositoryFactory = relationshipRepositoryFactory,
       _channelManagementRepositoryFactory = channelManagementRepositoryFactory,
       _roleRepositoryFactory = roleRepositoryFactory,
       _inviteRepositoryFactory = inviteRepositoryFactory,
       _scheduledEventRepositoryFactory = scheduledEventRepositoryFactory,
       _clientSyncRepositoryFactory = clientSyncRepositoryFactory,
       _readStateRepository = readStateRepository,
       _typingExpiryScheduler = typingExpiryScheduler,
       _now = now;

  final TokenRepository _tokenRepository;
  final DiscordGatewayConnection _gateway;
  final DiscordAccountSessionController? _accountSession;
  final MessageNotificationCallback? _messageNotificationCallback;
  final MessageCacheRepository? _messageCacheRepository;
  final DiscordVoiceCoordinator? _voiceCoordinator;
  final AttachmentDownloadService? _attachmentDownloadService;
  final MessageRepositoryFactory? _messageRepositoryFactory;
  final ThreadRepositoryFactory? _threadRepositoryFactory;
  final DirectMessageRepositoryFactory? _directMessageRepositoryFactory;
  final RelationshipRepositoryFactory? _relationshipRepositoryFactory;
  final ChannelManagementRepositoryFactory? _channelManagementRepositoryFactory;
  final RoleRepositoryFactory? _roleRepositoryFactory;
  final InviteRepositoryFactory? _inviteRepositoryFactory;
  final ScheduledEventRepositoryFactory? _scheduledEventRepositoryFactory;
  final ClientSyncRepositoryFactory? _clientSyncRepositoryFactory;
  final ReadStateRepository? _readStateRepository;
  final TypingExpiryScheduler _typingExpiryScheduler;
  final NowCallback _now;
  final StreamController<DiscordAppState> _states =
      StreamController.broadcast();

  DiscordAppState _state = const DiscordAppState.booting();
  StreamSubscription<GatewaySessionState>? _gatewayStateSubscription;
  StreamSubscription<Map<String, Object?>>? _eventSubscription;
  StreamSubscription<DiscordVoiceUiState>? _voiceStateSubscription;
  MessageRepository? _messageRepository;
  ThreadRepository? _threadRepository;
  DirectMessageRepository? _directMessageRepository;
  RelationshipRepository? _relationshipRepository;
  ChannelManagementRepository? _channelManagementRepository;
  RoleRepository? _roleRepository;
  InviteRepository? _inviteRepository;
  ScheduledEventRepository? _scheduledEventRepository;
  ClientSyncRepository? _clientSyncRepository;
  Future<void>? _readStateWrite;
  Future<void>? _readAckWrite;
  Map<String, TypingExpiryTask> _typingExpiryTasks = const {};
  Map<String, DateTime> _typingSentAt = const {};
  bool _initialized = false;
  bool _disposed = false;
  bool _clientSyncDisabled = false;

  DiscordAppState get state => _state;

  Stream<DiscordAppState> get states async* {
    yield _state;
    yield* _states.stream;
  }

  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }
    _initialized = true;
    _subscribeToGateway();
    _subscribeToVoice();
    try {
      final readStates = await _readStateRepository?.loadAll();
      if (readStates != null) {
        _update(_state.copyWith(readStates: readStates));
      }
      final accountToken = await _accountSession?.initialize();
      final storedToken = accountToken ?? await _tokenRepository.load();
      if (storedToken == null) {
        _update(
          _state.copyWith(phase: DiscordAppPhase.signedOut, errorMessage: null),
        );
        return;
      }
      await connect(storedToken, persist: false);
    } on Object catch (error) {
      _showFailure(error);
    }
  }

  Future<void> connect(String token, {bool persist = true}) async {
    _ensureActive();
    _subscribeToGateway();
    _subscribeToVoice();
    _update(
      _state.copyWith(phase: DiscordAppPhase.connecting, errorMessage: null),
    );
    try {
      _messageRepository = _messageRepositoryFactory?.call(token);
      _threadRepository = _threadRepositoryFactory?.call(token);
      _directMessageRepository = _directMessageRepositoryFactory?.call(token);
      _relationshipRepository = _relationshipRepositoryFactory?.call(token);
      _channelManagementRepository = _channelManagementRepositoryFactory?.call(
        token,
      );
      _roleRepository = _roleRepositoryFactory?.call(token);
      _inviteRepository = _inviteRepositoryFactory?.call(token);
      _scheduledEventRepository = _scheduledEventRepositoryFactory?.call(token);
      _clientSyncRepository = _clientSyncRepositoryFactory?.call(token);
      _clientSyncDisabled = false;
      _update(_state.copyWith(clientApiWarning: null));
      await _gateway.connect(token);
      _accountSession?.tokenConnected(token);
      if (persist) {
        await _tokenRepository.save(token);
      }
    } on Object catch (error) {
      _showFailure(error);
    }
  }

  void selectGuild(String guildId) {
    final channels = _state.workspace.channelsForGuild(guildId);
    final channelId = _firstSelectableChannelId(channels);
    _update(
      _state.copyWith(
        selectedGuildId: guildId,
        pinnedMessagesState: const DiscordPinnedMessagesState(),
      ),
    );
    if (channelId != null) {
      selectChannel(channelId);
    }
  }

  void selectChannel(String channelId) {
    final channel = _state.workspace.channelById(channelId);
    if (channel != null && !channel.supportsMessageHistory) {
      _update(
        _state.copyWith(
          selectedChannelId: channelId,
          messageState: DiscordMessageState.loaded(channelId, const []),
          pinnedMessagesState: const DiscordPinnedMessagesState(),
        ),
      );
      if (channel.isForum || channel.isMedia) {
        unawaited(refreshThreads(channelId));
      }
      return;
    }
    _update(
      _state.copyWith(
        selectedChannelId: channelId,
        messageState: DiscordMessageState(
          channelId: channelId,
          isLoading: true,
        ),
        pinnedMessagesState: const DiscordPinnedMessagesState(),
      ),
    );
    unawaited(_loadMessages(channelId));
  }

  Future<String?> downloadAttachment(DiscordAttachment attachment) async {
    return _attachmentDownloadService?.download(attachment);
  }

  Future<void> loadOlderMessages() async {
    final channelId = _state.selectedChannelId;
    final repository = _messageRepository;
    final messageState = _state.messageState;
    if (channelId == null ||
        repository == null ||
        messageState.channelId != channelId ||
        messageState.messages.isEmpty ||
        messageState.isLoadingOlder ||
        !messageState.hasMore) {
      return;
    }
    final before = messageState.messages.first.id;
    _update(_state.copyWith(messageState: messageState.loadingOlder()));
    try {
      final messages = await repository.fetchMessages(
        channelId,
        before: before,
        limit: _messagePageSize,
      );
      if (_state.selectedChannelId == channelId) {
        _update(
          _state.copyWith(
            messageState: _state.messageState.prependOlder(
              messages,
              hasMore: messages.length >= _messagePageSize,
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (_state.selectedChannelId == channelId) {
        _update(
          _state.copyWith(
            messageState: _state.messageState.copyWith(
              isLoadingOlder: false,
              olderErrorMessage: _friendlyError(error),
            ),
          ),
        );
      }
    }
  }

  Future<void> sendMessage(String content) async {
    final channelId = _state.selectedChannelId;
    final repository = _messageRepository;
    if (channelId == null || repository == null) {
      return;
    }
    try {
      final message = await repository.sendMessage(channelId, content);
      if (_state.selectedChannelId == channelId) {
        _update(
          _state.copyWith(messageState: _state.messageState.add(message)),
        );
        _markChannelRead(channelId, message.id);
      }
    } on Object catch (error) {
      _update(
        _state.copyWith(
          messageState: _state.messageState.copyWith(
            errorMessage: _friendlyError(error),
          ),
        ),
      );
    }
  }

  Future<void> sendPoll(DiscordPollDraft draft) async {
    final channelId = _state.selectedChannelId;
    final repository = _messageRepository;
    if (channelId == null || repository == null) {
      return;
    }
    try {
      final message = await repository.sendPoll(channelId, draft);
      if (_state.selectedChannelId == channelId) {
        _update(
          _state.copyWith(messageState: _state.messageState.add(message)),
        );
        _markChannelRead(channelId, message.id);
      }
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> sendSticker(String stickerId, {String content = ''}) async {
    final channelId = _state.selectedChannelId;
    final repository = _messageRepository;
    if (channelId == null || repository == null) {
      return;
    }
    try {
      final message = await repository.sendStickers(channelId, [
        stickerId,
      ], content: content);
      if (_state.selectedChannelId == channelId) {
        _update(
          _state.copyWith(messageState: _state.messageState.add(message)),
        );
        _markChannelRead(channelId, message.id);
      }
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> sendReply(String content, String messageId) async {
    final channelId = _state.selectedChannelId;
    final repository = _messageRepository;
    if (channelId == null || repository == null) {
      return;
    }
    try {
      final message = await repository.sendReply(channelId, content, messageId);
      if (_state.selectedChannelId == channelId) {
        _update(
          _state.copyWith(messageState: _state.messageState.add(message)),
        );
        _markChannelRead(channelId, message.id);
      }
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> editMessage(DiscordMessage message, String content) async {
    final repository = _messageRepository;
    if (repository == null) {
      return;
    }
    try {
      final edited = await repository.editMessage(
        message.channelId,
        message.id,
        content,
      );
      if (_state.selectedChannelId == message.channelId) {
        _update(_state.copyWith(messageState: _state.messageState.add(edited)));
      }
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> deleteMessage(DiscordMessage message) async {
    final repository = _messageRepository;
    if (repository == null) {
      return;
    }
    try {
      await repository.deleteMessage(message.channelId, message.id);
      if (_state.selectedChannelId == message.channelId) {
        _update(
          _state.copyWith(
            messageState: _state.messageState.remove(message.id),
            pinnedMessagesState: _state.pinnedMessagesState.removeMessage(
              message.id,
            ),
          ),
        );
      }
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> togglePinned(DiscordMessage message) async {
    final repository = _messageRepository;
    if (repository == null) {
      return;
    }
    final pinned = !message.pinned;
    final refreshPanel =
        _state.pinnedMessagesState.channelId == message.channelId && pinned;
    try {
      await repository.setPinned(message.channelId, message.id, pinned);
      if (_state.selectedChannelId == message.channelId) {
        _update(
          _state.copyWith(
            messageState: _state.messageState.add(
              message.copyWith(pinned: pinned),
            ),
            pinnedMessagesState: pinned
                ? _state.pinnedMessagesState
                : _state.pinnedMessagesState.removeMessage(message.id),
          ),
        );
      }
      if (refreshPanel && _isPinnedMessagesCurrent(message.channelId)) {
        await openPinnedMessages();
      }
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> toggleReaction(
    DiscordMessage message,
    DiscordReaction reaction,
  ) async {
    final repository = _messageRepository;
    if (repository == null) {
      return;
    }
    try {
      if (reaction.me) {
        await repository.removeReaction(
          message.channelId,
          message.id,
          reaction.key,
        );
      } else {
        await repository.addReaction(
          message.channelId,
          message.id,
          reaction.key,
        );
      }
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> sendAttachments(
    String content,
    List<DiscordUploadFile> files, {
    String? replyToMessageId,
  }) async {
    final channelId = _state.selectedChannelId;
    final repository = _messageRepository;
    if (channelId == null || repository == null) {
      return;
    }
    try {
      final message = await repository.sendAttachments(
        channelId,
        content,
        files,
        replyToMessageId: replyToMessageId,
      );
      if (_state.selectedChannelId == channelId) {
        _update(
          _state.copyWith(messageState: _state.messageState.add(message)),
        );
        _markChannelRead(channelId, message.id);
      }
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> searchMessages(
    String query, {
    bool currentChannelOnly = false,
  }) async {
    final guildId = _state.selectedGuildId;
    final repository = _messageRepository;
    if (guildId == null || repository == null) {
      return;
    }
    final selectedChannelId = _state.selectedChannelId;
    final selectedChannel = selectedChannelId == null
        ? null
        : _state.workspace.channelById(selectedChannelId);
    final directMessageChannelId =
        guildId == discordDirectMessagesGuildId &&
            selectedChannel?.isPrivate == true
        ? selectedChannel!.id
        : null;
    final effectiveCurrentChannelOnly =
        currentChannelOnly || directMessageChannelId != null;
    final normalized = query.trim();
    _update(
      _state.copyWith(
        searchState: DiscordMessageSearchState.loading(
          normalized,
          currentChannelOnly: effectiveCurrentChannelOnly,
        ),
      ),
    );
    try {
      final result = await _executeMessageSearch(
        repository: repository,
        guildId: guildId,
        directMessageChannelId: directMessageChannelId,
        query: normalized,
        currentChannelOnly: effectiveCurrentChannelOnly,
      );
      if (!_isMessageSearchCurrent(normalized, directMessageChannelId)) {
        return;
      }
      _update(
        _state.copyWith(
          workspace: _state.workspace.upsertChannels(result.threads),
          searchState: DiscordMessageSearchState.loaded(
            query: result.query,
            totalResults: result.totalResults,
            messages: result.messages,
            currentChannelOnly: effectiveCurrentChannelOnly,
          ),
        ),
      );
    } on Object catch (error) {
      if (_isMessageSearchCurrent(normalized, directMessageChannelId)) {
        _update(
          _state.copyWith(
            searchState: _state.searchState.failed(_friendlyError(error)),
          ),
        );
      }
    }
  }

  Future<DiscordMessageSearchResult> _executeMessageSearch({
    required MessageRepository repository,
    required String guildId,
    required String? directMessageChannelId,
    required String query,
    required bool currentChannelOnly,
  }) {
    if (directMessageChannelId != null) {
      return repository.searchChannelMessages(directMessageChannelId, query);
    }
    return repository.searchGuildMessages(
      guildId,
      query,
      channelId: currentChannelOnly ? _state.selectedChannelId : null,
    );
  }

  bool _isMessageSearchCurrent(String query, String? directMessageChannelId) {
    return _state.searchState.query == query &&
        (directMessageChannelId == null ||
            _state.selectedChannelId == directMessageChannelId);
  }

  Future<void> selectSearchResult(DiscordMessage message) async {
    _update(
      _state.copyWith(
        selectedChannelId: message.channelId,
        messageState: DiscordMessageState(
          channelId: message.channelId,
          isLoading: true,
        ),
      ),
    );
    await _loadMessagesAround(message.channelId, message.id);
  }

  void clearSearch() {
    _update(_state.copyWith(searchState: const DiscordMessageSearchState()));
  }

  Future<void> openPinnedMessages() async {
    final channelId = _state.selectedChannelId;
    final repository = _messageRepository;
    if (channelId == null || repository == null) {
      return;
    }
    _update(
      _state.copyWith(
        pinnedMessagesState: DiscordPinnedMessagesState.loading(channelId),
      ),
    );
    try {
      final page = await repository.fetchPinnedMessages(channelId);
      if (_isPinnedMessagesCurrent(channelId)) {
        _update(
          _state.copyWith(
            pinnedMessagesState: DiscordPinnedMessagesState.loaded(
              channelId: channelId,
              pins: page.pins,
              hasMore: page.hasMore,
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (_isPinnedMessagesCurrent(channelId)) {
        _update(
          _state.copyWith(
            pinnedMessagesState: _state.pinnedMessagesState.failed(
              _friendlyError(error),
            ),
          ),
        );
      }
    }
  }

  Future<void> loadMorePinnedMessages() async {
    final current = _state.pinnedMessagesState;
    final repository = _messageRepository;
    final channelId = current.channelId;
    if (channelId == null ||
        repository == null ||
        current.isLoading ||
        current.isLoadingMore ||
        !current.hasMore ||
        current.pins.isEmpty) {
      return;
    }
    _update(_state.copyWith(pinnedMessagesState: current.loadingMore()));
    try {
      final page = await repository.fetchPinnedMessages(
        channelId,
        before: current.pins.last.pinnedAt,
      );
      if (_isPinnedMessagesCurrent(channelId)) {
        _update(
          _state.copyWith(
            pinnedMessagesState: _state.pinnedMessagesState.appendPage(page),
          ),
        );
      }
    } on Object catch (error) {
      if (_isPinnedMessagesCurrent(channelId)) {
        _update(
          _state.copyWith(
            pinnedMessagesState: _state.pinnedMessagesState.failed(
              _friendlyError(error),
            ),
          ),
        );
      }
    }
  }

  Future<void> selectPinnedMessage(DiscordMessage message) async {
    if (!_isPinnedMessagesCurrent(message.channelId)) {
      return;
    }
    _update(
      _state.copyWith(
        messageState: DiscordMessageState(
          channelId: message.channelId,
          isLoading: true,
        ),
      ),
    );
    await _loadMessagesAround(message.channelId, message.id);
  }

  void closePinnedMessages() {
    _update(
      _state.copyWith(pinnedMessagesState: const DiscordPinnedMessagesState()),
    );
  }

  bool _isPinnedMessagesCurrent(String channelId) {
    return _state.selectedChannelId == channelId &&
        _state.pinnedMessagesState.channelId == channelId;
  }

  Future<void> refreshThreads(String parentChannelId) async {
    final guildId = _state.selectedGuildId;
    final repository = _threadRepository;
    if (guildId == null || repository == null) {
      return;
    }
    try {
      final threads = await repository.listThreads(
        guildId: guildId,
        parentChannelId: parentChannelId,
        includePrivateArchived:
            _state.workspace.channelById(parentChannelId)?.isForum != true &&
            _state.workspace.channelById(parentChannelId)?.isMedia != true,
      );
      _update(
        _state.copyWith(workspace: _state.workspace.upsertChannels(threads)),
      );
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> createThread(String parentChannelId, String name) async {
    final guildId = _state.selectedGuildId;
    final repository = _threadRepository;
    if (guildId == null || repository == null) {
      return;
    }
    try {
      final thread = await repository.createPublicThread(
        guildId: guildId,
        parentChannelId: parentChannelId,
        name: name,
      );
      _mergeThreadAndSelect(thread);
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> createForumPost(
    String forumChannelId, {
    required String title,
    required String content,
    List<String> appliedTagIds = const [],
  }) async {
    final guildId = _state.selectedGuildId;
    final repository = _threadRepository;
    if (guildId == null || repository == null) {
      return;
    }
    try {
      final post = await repository.createForumPost(
        guildId: guildId,
        forumChannelId: forumChannelId,
        title: title,
        content: content,
        appliedTagIds: appliedTagIds,
      );
      _mergeThreadAndSelect(post);
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> startThreadFromMessage(String messageId, String name) async {
    final guildId = _state.selectedGuildId;
    final channelId = _state.selectedChannelId;
    final repository = _threadRepository;
    if (guildId == null || channelId == null || repository == null) {
      return;
    }
    try {
      final thread = await repository.startThreadFromMessage(
        guildId: guildId,
        channelId: channelId,
        messageId: messageId,
        name: name,
      );
      _mergeThreadAndSelect(thread);
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> joinThread(String threadId) async {
    final repository = _threadRepository;
    if (repository == null) {
      return;
    }
    try {
      await repository.joinThread(threadId);
      _update(
        _state.copyWith(
          workspace: _state.workspace.markThreadJoined(threadId, true),
        ),
      );
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  Future<void> setThreadArchived(String threadId, bool archived) async {
    final guildId = _state.selectedGuildId;
    final repository = _threadRepository;
    if (guildId == null || repository == null) {
      return;
    }
    try {
      final thread = await repository.setArchived(
        guildId: guildId,
        threadId: threadId,
        archived: archived,
      );
      _update(
        _state.copyWith(workspace: _state.workspace.upsertChannels([thread])),
      );
    } on Object catch (error) {
      _showMessageError(error);
    }
  }

  void _mergeThreadAndSelect(DiscordChannel thread) {
    _update(
      _state.copyWith(workspace: _state.workspace.upsertChannels([thread])),
    );
    selectChannel(thread.id);
  }

  void _showFailure(Object error) {
    _update(
      _state.copyWith(
        phase: DiscordAppPhase.failure,
        errorMessage: _friendlyError(error),
      ),
    );
  }

  void _showMessageError(Object error) {
    _update(
      _state.copyWith(
        messageState: _state.messageState.copyWith(
          errorMessage: _friendlyError(error),
        ),
      ),
    );
  }

  void _update(DiscordAppState nextState) {
    _state = nextState;
    if (!_states.isClosed) {
      _states.add(nextState);
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('이미 종료된 앱 controller입니다.');
    }
  }
}

const int _messagePageSize = 50;

String? _validGuildId(
  DiscordWorkspaceState workspace,
  String? selectedGuildId,
) {
  if (workspace.guilds.any((guild) => guild.id == selectedGuildId)) {
    return selectedGuildId;
  }
  return workspace.guilds.firstOrNull?.id;
}

String? _validChannelId(
  DiscordWorkspaceState workspace,
  String? guildId,
  String? selectedChannelId,
) {
  if (guildId == null) {
    return null;
  }
  final channels = workspace.channelsForGuild(guildId);
  if (channels.any((channel) => channel.id == selectedChannelId)) {
    return selectedChannelId;
  }
  return channels.firstOrNull?.id;
}

String _friendlyError(Object error) {
  if (error is FormatException) {
    return error.message;
  }
  if (error is InvalidMessageException ||
      error is InvalidMessageSearchException ||
      error is InvalidThreadException ||
      error is InvalidDirectMessageException ||
      error is InvalidRelationshipException ||
      error is InvalidGuildChannelException ||
      error is InvalidGuildRoleException ||
      error is InvalidGuildInviteException ||
      error is InvalidScheduledEventException) {
    return error.toString();
  }
  return 'Discord 연결에 실패했습니다. 토큰과 네트워크 상태를 확인해 주세요.';
}

String? _firstSelectableChannelId(List<DiscordChannel> channels) {
  return channels
          .firstWhereOrNull((channel) => channel.supportsMessageHistory)
          ?.id ??
      channels.firstWhereOrNull((channel) => !channel.isCategory)?.id;
}
