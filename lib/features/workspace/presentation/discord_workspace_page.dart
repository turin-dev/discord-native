import 'dart:async';

import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/domain/workspace_navigation_history.dart';
import 'package:collection/collection.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/messages/domain/discord_typing_state.dart';
import 'package:discord_native/features/messages/domain/discord_message_search_state.dart';
import 'package:discord_native/features/workspace/data/read_state_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_permissions.dart';
import 'package:discord_native/features/workspace/presentation/conversation_panel.dart';
import 'package:discord_native/features/workspace/presentation/client_api_warning.dart';
import 'package:discord_native/features/workspace/presentation/message_actions.dart';
import 'package:discord_native/features/workspace/presentation/message_search_panel.dart';
import 'package:discord_native/features/workspace/presentation/thread_controls.dart';
import 'package:discord_native/features/workspace/presentation/guild_channel_controls.dart';
import 'package:discord_native/features/workspace/presentation/guild_event_controls.dart';
import 'package:discord_native/features/workspace/presentation/guild_role_controls.dart';
import 'package:discord_native/features/workspace/presentation/guild_invite_controls.dart';
import 'package:discord_native/features/workspace/presentation/forum_channel_panel.dart';
import 'package:discord_native/features/workspace/presentation/workspace_navigation.dart';
import 'package:discord_native/features/workspace/presentation/workspace_right_panel.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:discord_native/features/workspace/presentation/discord_title_bar.dart';
import 'package:discord_native/features/workspace/presentation/direct_messages_components.dart';
import 'package:discord_native/features/workspace/presentation/resizable_channel_sidebar.dart';
import 'package:discord_native/features/voice/domain/discord_voice_ui_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

export 'package:discord_native/features/workspace/presentation/message_actions.dart'
    show PollVoteCallback;

class DiscordWorkspacePage extends StatefulWidget {
  const DiscordWorkspacePage({
    required this.state,
    required this.selectedGuildId,
    required this.selectedChannelId,
    required this.connectionLabel,
    required this.onSelectGuild,
    required this.onSelectChannel,
    required this.onLogout,
    this.onOpenUserSettings,
    this.peopleState = const DiscordPeopleState(),
    this.messageState = const DiscordMessageState(),
    this.typingUsers = const [],
    this.onTyping,
    this.onSendMessage,
    this.onSendPoll,
    this.onSendSticker,
    this.onLoadOlderMessages,
    this.onSendReply,
    this.onToggleReaction,
    this.onVotePoll,
    this.onEditMessage,
    this.onDeleteMessage,
    this.onTogglePinned,
    this.onPickAttachments,
    this.onDownloadAttachment,
    this.onSendAttachments,
    this.onRefreshThreads,
    this.onCreateThread,
    this.onStartThreadFromMessage,
    this.onJoinThread,
    this.onSetThreadArchived,
    this.searchState = const DiscordMessageSearchState(),
    this.onSearchMessages,
    this.onSelectSearchResult,
    this.onClearSearch,
    this.peopleErrorMessage,
    this.onOpenDirectMessage,
    this.onSendFriendRequest,
    this.onAcceptFriendRequest,
    this.onBlockRelationship,
    this.onRemoveRelationship,
    this.guildErrorMessage,
    this.onCreateGuildChannel,
    this.onUpdateGuildChannel,
    this.onDeleteGuildChannel,
    this.onCreateGuildRole,
    this.onUpdateGuildRole,
    this.onUpdateGuildRolePositions,
    this.onDeleteGuildRole,
    this.onLoadGuildInvites,
    this.onCreateGuildInvite,
    this.onDeleteGuildInvite,
    this.onLoadScheduledEvents,
    this.onCreateScheduledEvent,
    this.onUpdateScheduledEvent,
    this.onDeleteScheduledEvent,
    this.onCreateForumPost,
    this.readStates = const {},
    this.voiceUiState = const DiscordVoiceUiState(),
    this.onJoinVoiceChannel,
    this.onSetVoiceMuted,
    this.onSetVoiceDeafened,
    this.onLeaveVoiceChannel,
    this.onSetVoiceInputMode,
    this.onPushToTalkPressed,
    this.onSetVoiceUserVolume,
    this.onSetCameraEnabled,
    this.onSetScreenShareEnabled,
    this.onSetScreenSharePaused,
    this.onWatchVoiceStream,
    this.onStopWatchingVoiceStream,
    this.localVideoStream,
    this.localScreenStream,
    this.displayDensity = DesktopDisplayDensity.defaultMode,
    this.channelSidebarWidth = DesktopSettings.defaultChannelSidebarWidth,
    this.onChannelSidebarWidthChanged,
    this.pinnedChannelIds = const {},
    this.onToggleChannelPinned,
    this.clientApiWarning,
    super.key,
  });

  final DiscordWorkspaceState state;
  final DiscordPeopleState peopleState;
  final DiscordMessageState messageState;
  final List<DiscordTypingUser> typingUsers;
  final VoidCallback? onTyping;
  final DiscordMessageSearchState searchState;
  final Map<String, DiscordReadState> readStates;
  final DiscordVoiceUiState voiceUiState;
  final ValueChanged<String>? onJoinVoiceChannel;
  final ValueChanged<bool>? onSetVoiceMuted;
  final ValueChanged<bool>? onSetVoiceDeafened;
  final VoidCallback? onLeaveVoiceChannel;
  final ValueChanged<DiscordVoiceInputMode>? onSetVoiceInputMode;
  final ValueChanged<bool>? onPushToTalkPressed;
  final void Function(String userId, double volume)? onSetVoiceUserVolume;
  final ValueChanged<bool>? onSetCameraEnabled;
  final ValueChanged<bool>? onSetScreenShareEnabled;
  final ValueChanged<bool>? onSetScreenSharePaused;
  final ValueChanged<String>? onWatchVoiceStream;
  final VoidCallback? onStopWatchingVoiceStream;
  final MediaStream? localVideoStream;
  final MediaStream? localScreenStream;
  final DesktopDisplayDensity displayDensity;
  final double channelSidebarWidth;
  final ValueChanged<double>? onChannelSidebarWidthChanged;
  final Set<String> pinnedChannelIds;
  final ValueChanged<String>? onToggleChannelPinned;
  final String? clientApiWarning;
  final String? selectedGuildId;
  final String? selectedChannelId;
  final String connectionLabel;
  final ValueChanged<String> onSelectGuild;
  final ValueChanged<String> onSelectChannel;
  final SendMessageCallback? onSendMessage;
  final SendPollCallback? onSendPoll;
  final SendStickerCallback? onSendSticker;
  final LoadOlderMessagesCallback? onLoadOlderMessages;
  final SendReplyCallback? onSendReply;
  final ToggleReactionCallback? onToggleReaction;
  final PollVoteCallback? onVotePoll;
  final EditMessageCallback? onEditMessage;
  final MessageActionCallback? onDeleteMessage;
  final MessageActionCallback? onTogglePinned;
  final PickAttachmentsCallback? onPickAttachments;
  final DownloadAttachmentCallback? onDownloadAttachment;
  final SendAttachmentsCallback? onSendAttachments;
  final RefreshThreadsCallback? onRefreshThreads;
  final CreateThreadCallback? onCreateThread;
  final StartThreadFromMessageCallback? onStartThreadFromMessage;
  final JoinThreadCallback? onJoinThread;
  final SetThreadArchivedCallback? onSetThreadArchived;
  final SearchMessagesCallback? onSearchMessages;
  final SelectSearchResultCallback? onSelectSearchResult;
  final VoidCallback? onClearSearch;
  final String? peopleErrorMessage;
  final RelationshipActionCallback? onOpenDirectMessage;
  final SendFriendRequestCallback? onSendFriendRequest;
  final RelationshipActionCallback? onAcceptFriendRequest;
  final RelationshipActionCallback? onBlockRelationship;
  final RelationshipActionCallback? onRemoveRelationship;
  final String? guildErrorMessage;
  final CreateGuildChannelCallback? onCreateGuildChannel;
  final UpdateGuildChannelCallback? onUpdateGuildChannel;
  final DeleteGuildChannelCallback? onDeleteGuildChannel;
  final CreateGuildRoleCallback? onCreateGuildRole;
  final UpdateGuildRoleCallback? onUpdateGuildRole;
  final UpdateGuildRolePositionsCallback? onUpdateGuildRolePositions;
  final DeleteGuildRoleCallback? onDeleteGuildRole;
  final LoadGuildInvitesCallback? onLoadGuildInvites;
  final CreateGuildInviteCallback? onCreateGuildInvite;
  final DeleteGuildInviteCallback? onDeleteGuildInvite;
  final LoadScheduledEventsCallback? onLoadScheduledEvents;
  final CreateScheduledEventCallback? onCreateScheduledEvent;
  final UpdateScheduledEventCallback? onUpdateScheduledEvent;
  final DeleteScheduledEventCallback? onDeleteScheduledEvent;
  final CreateForumPostCallback? onCreateForumPost;
  final VoidCallback onLogout;
  final VoidCallback? onOpenUserSettings;

  @override
  State<DiscordWorkspacePage> createState() => _DiscordWorkspacePageState();

  Widget buildWorkspace(
    BuildContext context, {
    required DiscordNavigationHistory history,
    required double effectiveSidebarWidth,
    required VoidCallback goBack,
    required VoidCallback goForward,
    required ValueChanged<String> selectGuild,
    required ValueChanged<String> selectChannel,
    required ValueChanged<double> resizeSidebar,
    required VoidCallback finishSidebarResize,
    required bool showDirectMessagesHome,
    required VoidCallback showFriends,
  }) {
    final guild = _selectedGuild(state.guilds, selectedGuildId);
    final directMessages = guild?.isDirectMessages == true;
    final showingDirectMessagesHome = directMessages && showDirectMessagesHome;
    final sidebarWidth = directMessages
        ? DiscordLayout.directMessagesSidebarWidth
        : effectiveSidebarWidth;
    final guildChannels = guild == null
        ? const <DiscordChannel>[]
        : state.channelsForGuild(guild.id);
    final currentMember = _currentMember(
      peopleState,
      guild: guild,
      currentUser: state.currentUser,
    );
    final channels = _visibleChannels(
      guildChannels,
      guild: guild,
      member: currentMember,
    );
    final channel = _selectedChannel(channels, selectedChannelId);
    final forumPosts = channel == null
        ? const <DiscordChannel>[]
        : guildChannels
              .where((item) => item.isThread && item.parentId == channel.id)
              .toList();
    final permissions = _channelPermissions(
      guildChannels,
      guild: guild,
      channel: channel,
      member: currentMember,
    );
    final canSendMessages =
        permissions == null ||
        (channel != null &&
            DiscordPermissions.canSend(permissions, channel: channel));
    final canManageMessages =
        permissions == null ||
        DiscordPermissions.has(permissions, DiscordPermissions.manageMessages);
    final canPinMessages =
        permissions == null ||
        DiscordPermissions.has(permissions, DiscordPermissions.pinMessages);
    final basePermissions = _basePermissions(guild, currentMember);
    final canCreateChannel =
        basePermissions != null &&
        DiscordPermissions.has(
          basePermissions,
          DiscordPermissions.manageChannels,
        );
    final canManageRoles =
        basePermissions != null &&
        DiscordPermissions.has(basePermissions, DiscordPermissions.manageRoles);
    final canManageInvites =
        basePermissions != null &&
        DiscordPermissions.has(basePermissions, DiscordPermissions.manageGuild);
    final canManageEvents =
        basePermissions != null &&
        DiscordPermissions.has(
          basePermissions,
          DiscordPermissions.manageEvents,
        );
    final manageableChannelIds = {
      for (final item in guildChannels)
        if (_canManageChannel(
          guildChannels,
          guild: guild,
          channel: item,
          member: currentMember,
        ))
          item.id,
    };
    final voiceParticipantNames = {
      for (final participant in voiceUiState.voice.participants)
        participant.userId:
            peopleState
                .memberForGuild(participant.guildId, participant.userId)
                ?.displayName ??
            participant.userId,
    };
    return Scaffold(
      backgroundColor: context.discordPalette.chat,
      body: Column(
        children: [
          DiscordTitleBar(
            onBack: history.canGoBack ? goBack : null,
            onForward: history.canGoForward ? goForward : null,
            onOpenInbox: () => _showInbox(
              context,
              channels: channels,
              readStates: readStates,
              onSelectChannel: selectChannel,
            ),
            onOpenHelp: () => _showWorkspaceHelp(context),
            onSearch: onSearchMessages == null
                ? null
                : (query) {
                    if (query.trim().isNotEmpty) {
                      unawaited(onSearchMessages!(query, false));
                    }
                  },
          ),
          if (clientApiWarning case final warning?)
            ClientApiWarning(message: warning),
          Expanded(
            child: Row(
              children: [
                GuildRail(
                  guilds: state.guilds,
                  selectedGuildId: guild?.id,
                  onSelect: selectGuild,
                  density: displayDensity,
                ),
                ResizableChannelSidebar(
                  width: sidebarWidth,
                  resizable: !directMessages,
                  onDrag: resizeSidebar,
                  onDragEnd: finishSidebarResize,
                  child: ChannelSidebar(
                    guild: guild,
                    channels: channels,
                    selectedChannelId: channel?.id,
                    currentUser: state.currentUser,
                    connectionLabel: connectionLabel,
                    readStates: readStates,
                    onSelect: selectChannel,
                    onLogout: onLogout,
                    onOpenUserSettings: onOpenUserSettings,
                    voiceUiState: voiceUiState,
                    voiceParticipantNames: voiceParticipantNames,
                    onJoinVoiceChannel: onJoinVoiceChannel,
                    onSetVoiceMuted: onSetVoiceMuted,
                    onSetVoiceDeafened: onSetVoiceDeafened,
                    onLeaveVoiceChannel: onLeaveVoiceChannel,
                    onSetVoiceInputMode: onSetVoiceInputMode,
                    onPushToTalkPressed: onPushToTalkPressed,
                    onSetVoiceUserVolume: onSetVoiceUserVolume,
                    onSetCameraEnabled: onSetCameraEnabled,
                    onSetScreenShareEnabled: onSetScreenShareEnabled,
                    onSetScreenSharePaused: onSetScreenSharePaused,
                    onWatchVoiceStream: onWatchVoiceStream,
                    onStopWatchingVoiceStream: onStopWatchingVoiceStream,
                    localVideoStream: localVideoStream,
                    localScreenStream: localScreenStream,
                    canCreateChannel: canCreateChannel,
                    manageableChannelIds: manageableChannelIds,
                    guildErrorMessage: guildErrorMessage,
                    onCreateGuildChannel: onCreateGuildChannel,
                    onUpdateGuildChannel: onUpdateGuildChannel,
                    onDeleteGuildChannel: onDeleteGuildChannel,
                    canManageRoles: canManageRoles,
                    onCreateGuildRole: onCreateGuildRole,
                    onUpdateGuildRole: onUpdateGuildRole,
                    onUpdateGuildRolePositions: onUpdateGuildRolePositions,
                    onDeleteGuildRole: onDeleteGuildRole,
                    canManageInvites: canManageInvites,
                    onLoadGuildInvites: onLoadGuildInvites,
                    onCreateGuildInvite: onCreateGuildInvite,
                    onDeleteGuildInvite: onDeleteGuildInvite,
                    canManageEvents: canManageEvents,
                    onLoadScheduledEvents: onLoadScheduledEvents,
                    onCreateScheduledEvent: onCreateScheduledEvent,
                    onUpdateScheduledEvent: onUpdateScheduledEvent,
                    onDeleteScheduledEvent: onDeleteScheduledEvent,
                    width: effectiveSidebarWidth,
                    density: displayDensity,
                    pinnedChannelIds: pinnedChannelIds,
                    onToggleChannelPinned: onToggleChannelPinned,
                    directMessagesHomeSelected: showingDirectMessagesHome,
                    onShowDirectMessagesHome: showFriends,
                  ),
                ),
                Expanded(
                  child: showingDirectMessagesHome
                      ? DirectMessagesHomePanel(
                          peopleState: peopleState,
                          onOpenDirectMessage: onOpenDirectMessage,
                        )
                      : channel?.isForum == true || channel?.isMedia == true
                      ? ForumChannelPanel(
                          channel: channel!,
                          posts: forumPosts,
                          onSelectPost: selectChannel,
                          onRefresh: onRefreshThreads == null
                              ? null
                              : () => onRefreshThreads!(channel.id),
                          onCreatePost:
                              canSendMessages && onCreateForumPost != null
                              ? onCreateForumPost
                              : null,
                        )
                      : ConversationPanel(
                          guild: guild,
                          channel: channel,
                          messageState: messageState,
                          typingUsers: typingUsers,
                          onTyping: onTyping,
                          currentUserId: state.currentUser?.id,
                          canSendMessages: canSendMessages,
                          canManageMessages: canManageMessages,
                          canPinMessages: canPinMessages,
                          onSendMessage: onSendMessage,
                          onSendPoll: onSendPoll,
                          onSendSticker: onSendSticker,
                          onLoadOlderMessages: onLoadOlderMessages,
                          onSendReply: onSendReply,
                          onToggleReaction: onToggleReaction,
                          onVotePoll: onVotePoll,
                          onEditMessage: onEditMessage,
                          onDeleteMessage: onDeleteMessage,
                          onTogglePinned: onTogglePinned,
                          onPickAttachments: onPickAttachments,
                          onDownloadAttachment: onDownloadAttachment,
                          onSendAttachments: onSendAttachments,
                          onRefreshThreads: onRefreshThreads,
                          onCreateThread: onCreateThread,
                          onStartThreadFromMessage: onStartThreadFromMessage,
                          onJoinThread: onJoinThread,
                          onSetThreadArchived: onSetThreadArchived,
                          directMessageSearchQuery: searchState.query,
                          onSearchDirectMessages:
                              channel?.isPrivate == true &&
                                  onSearchMessages != null
                              ? (query) => onSearchMessages!(query, true)
                              : null,
                          onClearDirectMessageSearch: onClearSearch,
                        ),
                ),
                WorkspaceRightPanel(
                  guild: guild,
                  channel: showingDirectMessagesHome ? null : channel,
                  currentUser: state.currentUser,
                  peopleState: peopleState,
                  searchState: searchState,
                  channels: state.channels,
                  onSearch: onSearchMessages,
                  onSelectResult: onSelectSearchResult,
                  onClear: onClearSearch,
                  onOpenDirectMessage: onOpenDirectMessage,
                  errorMessage: peopleErrorMessage,
                  onSendFriendRequest: onSendFriendRequest,
                  onAcceptFriendRequest: onAcceptFriendRequest,
                  onBlockRelationship: onBlockRelationship,
                  onRemoveRelationship: onRemoveRelationship,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showInbox(
  BuildContext context, {
  required List<DiscordChannel> channels,
  required Map<String, DiscordReadState> readStates,
  required ValueChanged<String> onSelectChannel,
}) async {
  final unreadChannels = channels
      .where((channel) => (readStates[channel.id]?.unreadCount ?? 0) > 0)
      .toList(growable: false);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('받은 편지함'),
      content: SizedBox(
        width: 420,
        child: unreadChannels.isEmpty
            ? const Text('읽지 않은 메시지가 없습니다.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: unreadChannels.length,
                itemBuilder: (context, index) {
                  final channel = unreadChannels[index];
                  final unreadCount = readStates[channel.id]!.unreadCount;
                  return ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text(channel.name),
                    trailing: Badge(label: Text('$unreadCount')),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      onSelectChannel(channel.id);
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

Future<void> _showWorkspaceHelp(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('도움말'),
      content: const SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('빠른 탐색과 음성 기능을 바로 사용할 수 있습니다.'),
            SizedBox(height: 16),
            Text('• 상단 검색: 서버 메시지 검색'),
            Text('• 뒤로/앞으로: 방문한 채널 이동'),
            Text('• 채널 우클릭: 고정 및 관리'),
            Text('• 음성 패널: 입력 모드와 화면 공유 제어'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

class _DiscordWorkspacePageState extends State<DiscordWorkspacePage> {
  late DiscordNavigationHistory _history;
  late double _sidebarWidth;
  bool _restoringHistory = false;
  bool _showDirectMessagesHome = false;

  @override
  void initState() {
    super.initState();
    _sidebarWidth = normalizeChannelSidebarWidth(widget.channelSidebarWidth);
    _history = const DiscordNavigationHistory().visit(_currentLocation);
  }

  @override
  void didUpdateWidget(covariant DiscordWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelSidebarWidth != widget.channelSidebarWidth) {
      _sidebarWidth = normalizeChannelSidebarWidth(widget.channelSidebarWidth);
    }
    if (_restoringHistory) {
      if (_currentLocation == _history.current) {
        _restoringHistory = false;
      }
      return;
    }
    _history = _history.visit(_currentLocation);
  }

  DiscordWorkspaceLocation get _currentLocation => DiscordWorkspaceLocation(
    widget.selectedGuildId,
    widget.selectedChannelId,
  );

  @override
  Widget build(BuildContext context) {
    return widget.buildWorkspace(
      context,
      history: _history,
      effectiveSidebarWidth: _sidebarWidth,
      goBack: _goBack,
      goForward: _goForward,
      selectGuild: _selectGuild,
      selectChannel: _selectChannel,
      resizeSidebar: _resizeSidebar,
      finishSidebarResize: _finishSidebarResize,
      showDirectMessagesHome: _showDirectMessagesHome,
      showFriends: _showFriends,
    );
  }

  void _goBack() => _navigate(_history.back());

  void _goForward() => _navigate(_history.forward());

  void _selectGuild(String guildId) {
    setState(() {
      _showDirectMessagesHome = guildId == discordDirectMessagesGuildId;
    });
    widget.onSelectGuild(guildId);
  }

  void _selectChannel(String channelId) {
    setState(() {
      _showDirectMessagesHome = false;
      _history = _history.visit(
        DiscordWorkspaceLocation(widget.selectedGuildId, channelId),
      );
    });
    widget.onSelectChannel(channelId);
  }

  void _showFriends() {
    setState(() => _showDirectMessagesHome = true);
  }

  void _navigate(DiscordNavigationHistory next) {
    final location = next.current;
    if (identical(next, _history) || location == null) {
      return;
    }
    setState(() {
      _history = next;
      _restoringHistory = true;
    });
    final guildId = location.guildId;
    if (guildId != null && guildId != widget.selectedGuildId) {
      widget.onSelectGuild(guildId);
    }
    final channelId = location.channelId;
    if (channelId != null && channelId != widget.selectedChannelId) {
      widget.onSelectChannel(channelId);
    }
  }

  void _resizeSidebar(double delta) {
    setState(() {
      _sidebarWidth = normalizeChannelSidebarWidth(_sidebarWidth + delta);
    });
  }

  void _finishSidebarResize() {
    widget.onChannelSidebarWidthChanged?.call(_sidebarWidth);
  }
}

DiscordGuild? _selectedGuild(
  List<DiscordGuild> guilds,
  String? selectedGuildId,
) {
  for (final guild in guilds) {
    if (guild.id == selectedGuildId) {
      return guild;
    }
  }
  return guilds.firstOrNull;
}

DiscordChannel? _selectedChannel(
  List<DiscordChannel> channels,
  String? selectedChannelId,
) {
  for (final channel in channels) {
    if (channel.id == selectedChannelId) {
      return channel;
    }
  }
  return channels.firstWhereOrNull((channel) => channel.isTextChannel) ??
      channels.firstOrNull;
}

DiscordGuildMember? _currentMember(
  DiscordPeopleState peopleState, {
  required DiscordGuild? guild,
  required DiscordUser? currentUser,
}) {
  if (guild == null || currentUser == null || guild.isDirectMessages) {
    return null;
  }
  return peopleState.memberForGuild(guild.id, currentUser.id);
}

List<DiscordChannel> _visibleChannels(
  List<DiscordChannel> channels, {
  required DiscordGuild? guild,
  required DiscordGuildMember? member,
}) {
  if (!_canCalculatePermissions(guild, member)) {
    return channels;
  }
  final viewableIds = {
    for (final channel in channels)
      if (_canViewChannel(channels, guild!, channel, member!)) channel.id,
  };
  return List.unmodifiable(
    channels.where((channel) {
      if (!channel.isCategory) {
        return viewableIds.contains(channel.id);
      }
      return viewableIds.contains(channel.id) ||
          channels.any(
            (child) =>
                child.parentId == channel.id && viewableIds.contains(child.id),
          );
    }),
  );
}

bool _canViewChannel(
  List<DiscordChannel> channels,
  DiscordGuild guild,
  DiscordChannel channel,
  DiscordGuildMember member,
) {
  final permissions = _channelPermissions(
    channels,
    guild: guild,
    channel: channel,
    member: member,
  );
  return permissions == null ||
      DiscordPermissions.has(permissions, DiscordPermissions.viewChannel);
}

BigInt? _channelPermissions(
  List<DiscordChannel> channels, {
  required DiscordGuild? guild,
  required DiscordChannel? channel,
  required DiscordGuildMember? member,
}) {
  if (channel == null || !_canCalculatePermissions(guild, member)) {
    return null;
  }
  final parent = channel.isThread
      ? channels.firstWhereOrNull((item) => item.id == channel.parentId)
      : null;
  return DiscordPermissionCalculator.compute(
    guild: guild!,
    channel: channel,
    member: member!,
    parentChannel: parent,
  );
}

bool _canCalculatePermissions(DiscordGuild? guild, DiscordGuildMember? member) {
  return guild != null &&
      !guild.isDirectMessages &&
      member != null &&
      guild.roles.any((role) => role.id == guild.id);
}

BigInt? _basePermissions(DiscordGuild? guild, DiscordGuildMember? member) {
  if (!_canCalculatePermissions(guild, member)) {
    return null;
  }
  return DiscordPermissionCalculator.computeBase(
    guild: guild!,
    member: member!,
  );
}

bool _canManageChannel(
  List<DiscordChannel> channels, {
  required DiscordGuild? guild,
  required DiscordChannel channel,
  required DiscordGuildMember? member,
}) {
  final permissions = _channelPermissions(
    channels,
    guild: guild,
    channel: channel,
    member: member,
  );
  return permissions != null &&
      DiscordPermissions.has(permissions, DiscordPermissions.manageChannels);
}
