import 'package:discord_native/features/messages/domain/discord_message_search_state.dart';
import 'package:discord_native/features/messages/domain/discord_pinned_messages_state.dart';
import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/message_search_panel.dart';
import 'package:discord_native/features/workspace/presentation/pinned_messages_panel.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:discord_native/features/workspace/presentation/discord_identity.dart';
import 'package:discord_native/features/workspace/presentation/direct_messages_components.dart';
import 'package:flutter/material.dart';

typedef SendFriendRequestCallback = Future<void> Function(String username);
typedef RelationshipActionCallback =
    Future<void> Function(DiscordRelationship relationship);

class WorkspaceRightPanel extends StatelessWidget {
  const WorkspaceRightPanel({
    required this.guild,
    required this.channel,
    required this.currentUser,
    required this.peopleState,
    required this.searchState,
    required this.channels,
    required this.onSearch,
    required this.onSelectResult,
    required this.onClear,
    required this.errorMessage,
    required this.onOpenDirectMessage,
    required this.onSendFriendRequest,
    required this.onAcceptFriendRequest,
    required this.onBlockRelationship,
    required this.onRemoveRelationship,
    this.pinnedMessagesState = const DiscordPinnedMessagesState(),
    this.onSelectPinnedMessage,
    this.onClosePinnedMessages,
    this.onLoadMorePinnedMessages,
    this.onRefreshPinnedMessages,
    this.onUnpinMessage,
    super.key,
  });

  final DiscordGuild? guild;
  final DiscordChannel? channel;
  final DiscordUser? currentUser;
  final DiscordPeopleState peopleState;
  final DiscordMessageSearchState searchState;
  final List<DiscordChannel> channels;
  final SearchMessagesCallback? onSearch;
  final SelectSearchResultCallback? onSelectResult;
  final VoidCallback? onClear;
  final String? errorMessage;
  final RelationshipActionCallback? onOpenDirectMessage;
  final SendFriendRequestCallback? onSendFriendRequest;
  final RelationshipActionCallback? onAcceptFriendRequest;
  final RelationshipActionCallback? onBlockRelationship;
  final RelationshipActionCallback? onRemoveRelationship;
  final DiscordPinnedMessagesState pinnedMessagesState;
  final PinnedMessageCallback? onSelectPinnedMessage;
  final VoidCallback? onClosePinnedMessages;
  final Future<void> Function()? onLoadMorePinnedMessages;
  final Future<void> Function()? onRefreshPinnedMessages;
  final PinnedMessageCallback? onUnpinMessage;

  @override
  Widget build(BuildContext context) {
    final directMessages = guild?.isDirectMessages == true;
    final directMessageChannel = channel;
    final hasActiveSearch = searchState.query.trim().isNotEmpty;
    final pinnedMessagesOpen =
        pinnedMessagesState.isOpen &&
        pinnedMessagesState.channelId == directMessageChannel?.id;
    if (pinnedMessagesOpen) {
      return PinnedMessagesPanel(
        state: pinnedMessagesState,
        onSelect: onSelectPinnedMessage,
        onClose: onClosePinnedMessages,
        onLoadMore: onLoadMorePinnedMessages,
        onRetry: onRefreshPinnedMessages,
        onUnpin: onUnpinMessage,
      );
    }
    if (directMessages && hasActiveSearch) {
      return MessageSearchPanel(
        state: searchState,
        channels: channels,
        onSearch: onSearch,
        onSelectResult: onSelectResult,
        onClear: onClear,
        showChannelFilter: false,
      );
    }
    if (directMessages && directMessageChannel?.type == 3) {
      return DirectMessageMembersPanel(
        channel: directMessageChannel!,
        currentUser: currentUser,
        peopleState: peopleState,
      );
    }
    if (directMessages && directMessageChannel?.type == 1) {
      return const SizedBox.shrink();
    }
    return DefaultTabController(
      key: ValueKey(
        'right-panel-${guild?.id}-${hasActiveSearch ? 'search' : 'default'}',
      ),
      length: 2,
      initialIndex: directMessages || hasActiveSearch ? 0 : 1,
      child: ColoredBox(
        color: context.discordPalette.sidebar,
        child: SizedBox(
          width: DiscordLayout.rightPanelWidth,
          child: Column(
            children: [
              SizedBox(
                height: DiscordLayout.channelHeaderHeight,
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: context.discordPalette.divider,
                  tabs: directMessages
                      ? const [
                          Tab(icon: Icon(Icons.people_alt), text: '친구'),
                          Tab(icon: Icon(Icons.person_add), text: '요청'),
                        ]
                      : const [
                          Tab(icon: Icon(Icons.search), text: '검색'),
                          Tab(icon: Icon(Icons.group), text: '멤버'),
                        ],
                ),
              ),
              if (errorMessage case final message?)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    message,
                    style: const TextStyle(color: Color(0xFFF23F42)),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: directMessages
                      ? [
                          _RelationshipsPanel(
                            relationships: peopleState.friends,
                            emptyMessage: '친구가 없습니다.',
                            onOpenDirectMessage: onOpenDirectMessage,
                            onAddFriend: onSendFriendRequest,
                            onBlock: onBlockRelationship,
                            onRemove: onRemoveRelationship,
                          ),
                          _RequestsPanel(
                            state: peopleState,
                            onAccept: onAcceptFriendRequest,
                            onRemove: onRemoveRelationship,
                          ),
                        ]
                      : [
                          MessageSearchPanel(
                            state: searchState,
                            channels: channels,
                            onSearch: onSearch,
                            onSelectResult: onSelectResult,
                            onClear: onClear,
                          ),
                          _GuildMembersPanel(
                            members: peopleState.membersForGuild(guild?.id),
                          ),
                        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuildMembersPanel extends StatelessWidget {
  const _GuildMembersPanel({required this.members});

  final List<DiscordGuildMember> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(
        child: Text(
          '동기화된 멤버가 없습니다.',
          style: TextStyle(color: context.discordPalette.textFaint),
        ),
      );
    }
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return ListTile(
          dense: true,
          leading: _PresenceAvatar(user: member.user, status: member.status),
          title: Text(
            member.displayName,
            style: TextStyle(
              color: context.discordPalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            _presenceLine(member.status, member.activityName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.discordPalette.textFaint,
              fontSize: 11,
            ),
          ),
          onTap: () => _showProfile(
            context,
            user: member.user,
            displayName: member.displayName,
            status: member.status,
            activityName: member.activityName,
            detail: '역할 ${member.roleIds.length}개',
          ),
        );
      },
    );
  }
}

class _RelationshipsPanel extends StatelessWidget {
  const _RelationshipsPanel({
    required this.relationships,
    required this.emptyMessage,
    this.onOpenDirectMessage,
    this.onAddFriend,
    this.onBlock,
    this.onRemove,
  });

  final List<DiscordRelationship> relationships;
  final String emptyMessage;
  final RelationshipActionCallback? onOpenDirectMessage;
  final SendFriendRequestCallback? onAddFriend;
  final RelationshipActionCallback? onBlock;
  final RelationshipActionCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (onAddFriend != null)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: '친구 추가',
              onPressed: () => _requestFriend(context, onAddFriend!),
              icon: const Icon(Icons.person_add),
            ),
          ),
        Expanded(
          child: relationships.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage,
                    style: TextStyle(color: context.discordPalette.textFaint),
                  ),
                )
              : ListView.builder(
                  itemCount: relationships.length,
                  itemBuilder: (context, index) {
                    final relationship = relationships[index];
                    return _RelationshipTile(
                      relationship: relationship,
                      onOpenDirectMessage: onOpenDirectMessage,
                      onBlock: onBlock,
                      onRemove: onRemove,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RequestsPanel extends StatelessWidget {
  const _RequestsPanel({
    required this.state,
    required this.onAccept,
    required this.onRemove,
  });

  final DiscordPeopleState state;
  final RelationshipActionCallback? onAccept;
  final RelationshipActionCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final sections = [
      ('받은 친구 요청', state.incomingRequests),
      ('보낸 친구 요청', state.outgoingRequests),
      ('차단한 사용자', state.blocked),
    ];
    if (sections.every((section) => section.$2.isEmpty)) {
      return Center(
        child: Text(
          '요청이나 차단된 사용자가 없습니다.',
          style: TextStyle(color: context.discordPalette.textFaint),
        ),
      );
    }
    return ListView(
      children: [
        for (final section in sections)
          if (section.$2.isNotEmpty) ...[
            _PeopleSectionLabel(section.$1),
            for (final relationship in section.$2)
              _RelationshipTile(
                relationship: relationship,
                onAccept: onAccept,
                onRemove: onRemove,
              ),
          ],
      ],
    );
  }
}

class _RelationshipTile extends StatelessWidget {
  const _RelationshipTile({
    required this.relationship,
    this.onOpenDirectMessage,
    this.onAccept,
    this.onBlock,
    this.onRemove,
  });

  final DiscordRelationship relationship;
  final RelationshipActionCallback? onOpenDirectMessage;
  final RelationshipActionCallback? onAccept;
  final RelationshipActionCallback? onBlock;
  final RelationshipActionCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: _PresenceAvatar(
        user: relationship.user,
        status: relationship.status,
      ),
      title: Text(relationship.displayName),
      subtitle: Text(
        _presenceLine(relationship.status, relationship.activityName),
      ),
      trailing: _buildActions(context),
      onTap: () => _showProfile(
        context,
        user: relationship.user,
        displayName: relationship.displayName,
        status: relationship.status,
        activityName: relationship.activityName,
        detail: _relationshipLabel(relationship.type),
      ),
    );
  }

  Widget? _buildActions(BuildContext context) {
    return switch (relationship.type) {
      DiscordRelationshipType.incomingRequest => _incomingActions(context),
      DiscordRelationshipType.outgoingRequest => _removeAction(
        context,
        tooltip: '친구 요청 취소',
        message: '${relationship.displayName}님에게 보낸 요청을 취소할까요?',
        icon: Icons.close,
      ),
      DiscordRelationshipType.blocked => _removeAction(
        context,
        tooltip: '차단 해제',
        message: '${relationship.displayName} 사용자의 차단을 해제할까요?',
        icon: Icons.lock_open,
      ),
      DiscordRelationshipType.friend => _friendActions(context),
      DiscordRelationshipType.none || DiscordRelationshipType.implicit => null,
    };
  }

  Widget _incomingActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '친구 요청 수락',
          onPressed: onAccept == null ? null : () => onAccept!(relationship),
          icon: const Icon(Icons.check),
        ),
        _removeAction(
          context,
          tooltip: '친구 요청 거절',
          message: '${relationship.displayName}님의 친구 요청을 거절할까요?',
          icon: Icons.close,
        ),
      ],
    );
  }

  Widget _removeAction(
    BuildContext context, {
    required String tooltip,
    required String message,
    required IconData icon,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onRemove == null
          ? null
          : () => _removeWithConfirmation(context, message),
      icon: Icon(icon),
    );
  }

  Widget _friendActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '메시지 보내기',
          onPressed: onOpenDirectMessage == null
              ? null
              : () => onOpenDirectMessage!(relationship),
          icon: const Icon(Icons.chat_bubble_outline),
        ),
        PopupMenuButton<_RelationshipAction>(
          tooltip: '친구 작업',
          onSelected: (action) => _handleFriendAction(context, action),
          itemBuilder: (context) => const [
            PopupMenuItem(value: _RelationshipAction.block, child: Text('차단')),
            PopupMenuItem(
              value: _RelationshipAction.remove,
              child: Text('친구 삭제'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleFriendAction(
    BuildContext context,
    _RelationshipAction action,
  ) async {
    final confirmed = await _confirmRelationshipAction(
      context,
      action == _RelationshipAction.block
          ? '${relationship.displayName} 사용자를 차단할까요?'
          : '${relationship.displayName} 사용자를 친구에서 삭제할까요?',
    );
    if (!confirmed) {
      return;
    }
    if (action == _RelationshipAction.block) {
      await onBlock?.call(relationship);
    } else {
      await onRemove?.call(relationship);
    }
  }

  Future<void> _removeWithConfirmation(
    BuildContext context,
    String message,
  ) async {
    if (await _confirmRelationshipAction(context, message)) {
      await onRemove?.call(relationship);
    }
  }
}

enum _RelationshipAction { block, remove }

class _PresenceAvatar extends StatelessWidget {
  const _PresenceAvatar({required this.user, required this.status});

  final DiscordUser user;
  final DiscordPresenceStatus status;

  @override
  Widget build(BuildContext context) {
    return DiscordUserAvatar(
      user: user,
      radius: 16,
      statusColor: _statusColor(status),
    );
  }
}

class _PeopleSectionLabel extends StatelessWidget {
  const _PeopleSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          color: context.discordPalette.textFaint,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> _showProfile(
  BuildContext context, {
  required DiscordUser user,
  required String displayName,
  required DiscordPresenceStatus status,
  required String? activityName,
  required String detail,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('사용자 프로필'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PresenceAvatar(user: user, status: status),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text('@${user.username}'),
          const SizedBox(height: 8),
          Text(_presenceLine(status, activityName)),
          Text(
            detail,
            style: TextStyle(color: context.discordPalette.textFaint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

Future<void> _requestFriend(
  BuildContext context,
  SendFriendRequestCallback callback,
) async {
  var username = '';
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('친구 추가'),
      content: TextFormField(
        key: const ValueKey('friend-request-field'),
        autofocus: true,
        maxLength: 32,
        decoration: const InputDecoration(labelText: 'Discord username'),
        onChanged: (value) => username = value,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('요청 보내기'),
        ),
      ],
    ),
  );
  final normalized = username.trim();
  if (submitted == true && normalized.isNotEmpty) {
    await callback(normalized);
  }
}

Future<bool> _confirmRelationshipAction(
  BuildContext context,
  String message,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('관계 변경 확인'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

String _presenceLine(DiscordPresenceStatus status, String? activityName) {
  final statusLabel = switch (status) {
    DiscordPresenceStatus.online => '온라인',
    DiscordPresenceStatus.idle => '자리 비움',
    DiscordPresenceStatus.dnd => '방해 금지',
    DiscordPresenceStatus.offline => '오프라인',
  };
  return activityName == null ? statusLabel : '$statusLabel · $activityName';
}

String _relationshipLabel(DiscordRelationshipType type) {
  return switch (type) {
    DiscordRelationshipType.friend => '친구',
    DiscordRelationshipType.blocked => '차단됨',
    DiscordRelationshipType.incomingRequest => '받은 친구 요청',
    DiscordRelationshipType.outgoingRequest => '보낸 친구 요청',
    DiscordRelationshipType.implicit => '암묵적 관계',
    DiscordRelationshipType.none => '관계 없음',
  };
}

Color _statusColor(DiscordPresenceStatus status) {
  return switch (status) {
    DiscordPresenceStatus.online => const Color(0xFF23A55A),
    DiscordPresenceStatus.idle => const Color(0xFFF0B232),
    DiscordPresenceStatus.dnd => const Color(0xFFF23F42),
    DiscordPresenceStatus.offline => const Color(0xFF80848E),
  };
}
