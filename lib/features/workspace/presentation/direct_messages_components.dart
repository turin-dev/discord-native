import 'dart:async';

import 'package:collection/collection.dart';
import 'package:discord_native/features/workspace/data/read_state_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:discord_native/features/workspace/presentation/discord_identity.dart';
import 'package:flutter/material.dart';

typedef DirectMessageRelationshipCallback =
    Future<void> Function(DiscordRelationship relationship);
typedef DirectMessageSearchCallback = Future<void> Function(String query);

class DirectMessagesNavigation extends StatefulWidget {
  const DirectMessagesNavigation({
    required this.channels,
    required this.selectedChannelId,
    required this.readStates,
    required this.friendsSelected,
    required this.onSelectChannel,
    required this.onShowFriends,
    super.key,
  });

  final List<DiscordChannel> channels;
  final String? selectedChannelId;
  final Map<String, DiscordReadState> readStates;
  final bool friendsSelected;
  final ValueChanged<String> onSelectChannel;
  final VoidCallback? onShowFriends;

  @override
  State<DirectMessagesNavigation> createState() =>
      _DirectMessagesNavigationState();
}

class _DirectMessagesNavigationState extends State<DirectMessagesNavigation> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final channels = widget.channels
        .where(
          (channel) =>
              normalized.isEmpty ||
              channel.name.toLowerCase().contains(normalized),
        )
        .toList();
    return Column(
      key: const ValueKey('direct-messages-navigation'),
      children: [
        _DirectMessagesSearch(
          onChanged: (value) => setState(() => _query = value),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            children: [
              _DirectMessagesAction(
                key: const ValueKey('direct-messages-friends'),
                icon: Icons.people_alt,
                label: '친구',
                selected: widget.friendsSelected,
                onTap: widget.onShowFriends,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 18, 8, 6),
                child: Text('다이렉트 메시지'),
              ),
              for (final channel in channels)
                _DirectMessageChannelTile(
                  channel: channel,
                  selected:
                      !widget.friendsSelected &&
                      channel.id == widget.selectedChannelId,
                  unreadCount: widget.readStates[channel.id]?.unreadCount ?? 0,
                  onTap: () => widget.onSelectChannel(channel.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DirectMessagesSearch extends StatelessWidget {
  const _DirectMessagesSearch({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DiscordLayout.channelHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.discordPalette.divider),
        ),
      ),
      child: TextField(
        key: const ValueKey('direct-messages-search'),
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: '대화 찾기 또는 시작하기',
          hintStyle: TextStyle(color: context.discordPalette.textFaint),
          filled: true,
          fillColor: context.discordPalette.input,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          border: const OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
    );
  }
}

class _DirectMessagesAction extends StatelessWidget {
  const _DirectMessagesAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Material(
        color: selected ? context.discordPalette.selected : Colors.transparent,
        borderRadius: const BorderRadius.all(DiscordRadius.small),
        child: InkWell(
          onTap: onTap,
          hoverColor: context.discordPalette.hover,
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(icon, size: 24, color: context.discordPalette.textMuted),
              const SizedBox(width: 14),
              Text(label, style: DiscordTextStyles.channel(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectMessageChannelTile extends StatelessWidget {
  const _DirectMessageChannelTile({
    required this.channel,
    required this.selected,
    required this.unreadCount,
    required this.onTap,
  });

  final DiscordChannel channel;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recipient = channel.recipients.firstOrNull;
    return SizedBox(
      key: ValueKey('direct-message-channel-${channel.id}'),
      height: 44,
      child: Material(
        color: selected ? context.discordPalette.selected : Colors.transparent,
        borderRadius: const BorderRadius.all(DiscordRadius.small),
        child: InkWell(
          onTap: onTap,
          hoverColor: context.discordPalette.hover,
          child: Row(
            children: [
              const SizedBox(width: 8),
              if (channel.type == 1)
                DiscordUserAvatar(user: recipient, radius: 16)
              else
                DiscordInitialAvatar(
                  id: channel.id,
                  label: channel.name,
                  radius: 16,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DiscordTextStyles.channel(context).copyWith(
                    color: selected || unreadCount > 0
                        ? context.discordPalette.textNormal
                        : context.discordPalette.textMuted,
                    fontWeight: unreadCount > 0
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (unreadCount > 0) _DirectMessageUnreadBadge(unreadCount),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectMessageUnreadBadge extends StatelessWidget {
  const _DirectMessageUnreadBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.discordPalette.danger,
        borderRadius: const BorderRadius.all(Radius.circular(9)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class DirectMessageHeader extends StatelessWidget {
  const DirectMessageHeader({
    required this.channel,
    this.searchQuery = '',
    this.onSearch,
    this.onClearSearch,
    super.key,
  });

  final DiscordChannel? channel;
  final String searchQuery;
  final DirectMessageSearchCallback? onSearch;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final selected = channel;
    return Container(
      key: const ValueKey('direct-message-header'),
      height: DiscordLayout.channelHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.discordPalette.chat,
        border: Border(
          bottom: BorderSide(color: context.discordPalette.divider),
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected?.type == 3 ? Icons.group : Icons.person,
            size: 22,
            color: context.discordPalette.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selected?.name ?? '다이렉트 메시지',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DiscordTextStyles.heading(context),
            ),
          ),
          if (onSearch != null)
            SizedBox(
              width: 220,
              child: _DirectMessageSearchBox(
                query: searchQuery,
                onSearch: onSearch!,
                onClear: onClearSearch,
              ),
            ),
        ],
      ),
    );
  }
}

class _DirectMessageSearchBox extends StatefulWidget {
  const _DirectMessageSearchBox({
    required this.query,
    required this.onSearch,
    required this.onClear,
  });

  final String query;
  final DirectMessageSearchCallback onSearch;
  final VoidCallback? onClear;

  @override
  State<_DirectMessageSearchBox> createState() =>
      _DirectMessageSearchBoxState();
}

class _DirectMessageSearchBoxState extends State<_DirectMessageSearchBox> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(_DirectMessageSearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _controller.text != widget.query) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      await widget.onSearch(query);
    }
  }

  void _clear() {
    _controller.clear();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('direct-message-header-search'),
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => unawaited(_submit()),
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: '검색하기',
        isDense: true,
        filled: true,
        fillColor: context.discordPalette.input,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        suffixIcon: IconButton(
          tooltip: widget.query.isEmpty ? 'DM 메시지 검색' : 'DM 검색 지우기',
          onPressed: widget.query.isEmpty ? _submit : _clear,
          icon: Icon(widget.query.isEmpty ? Icons.search : Icons.close),
          iconSize: 17,
        ),
      ),
    );
  }
}

class DirectMessagesHomePanel extends StatelessWidget {
  const DirectMessagesHomePanel({
    required this.peopleState,
    this.onOpenDirectMessage,
    super.key,
  });

  final DiscordPeopleState peopleState;
  final DirectMessageRelationshipCallback? onOpenDirectMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('direct-messages-home'),
      children: [
        const DirectMessageHeader(channel: null),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('모든 친구', style: DiscordTextStyles.heading(context)),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final relationship in peopleState.friends)
                _DirectMessagePersonRow(
                  user: relationship.user,
                  label: relationship.displayName,
                  subtitle: relationship.status == DiscordPresenceStatus.offline
                      ? '오프라인'
                      : '온라인',
                  onTap: onOpenDirectMessage == null
                      ? null
                      : () => unawaited(onOpenDirectMessage!(relationship)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class DirectMessageMembersPanel extends StatelessWidget {
  const DirectMessageMembersPanel({
    required this.channel,
    required this.currentUser,
    required this.peopleState,
    super.key,
  });

  final DiscordChannel channel;
  final DiscordUser? currentUser;
  final DiscordPeopleState peopleState;

  @override
  Widget build(BuildContext context) {
    final users = _uniqueUsers([?currentUser, ...channel.recipients]);
    return ColoredBox(
      color: context.discordPalette.chat,
      child: SizedBox(
        width: DiscordLayout.rightPanelWidth,
        child: Column(
          children: [
            SizedBox(
              height: DiscordLayout.channelHeaderHeight,
              child: Center(
                child: Text(
                  '멤버 — ${users.length}',
                  style: DiscordTextStyles.label(context),
                ),
              ),
            ),
            Divider(height: 1, color: context.discordPalette.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final user in users)
                    _DirectMessagePersonRow(
                      user: user,
                      label: _directMessageDisplayName(peopleState, user),
                      subtitle: _directMessageStatus(peopleState, user.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectMessagePersonRow extends StatelessWidget {
  const _DirectMessagePersonRow({
    required this.user,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  final DiscordUser user;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 48,
      dense: true,
      leading: DiscordUserAvatar(user: user, radius: 16),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.discordPalette.textFaint, fontSize: 11),
      ),
      onTap: onTap,
    );
  }
}

List<DiscordUser> _uniqueUsers(List<DiscordUser> users) {
  final ids = <String>{};
  return List.unmodifiable(users.where((user) => ids.add(user.id)));
}

String _directMessageStatus(DiscordPeopleState peopleState, String userId) {
  final relationship = [
    ...peopleState.friends,
    ...peopleState.incomingRequests,
    ...peopleState.outgoingRequests,
  ].firstWhereOrNull((item) => item.user.id == userId);
  if (relationship == null ||
      relationship.status == DiscordPresenceStatus.offline) {
    return '오프라인';
  }
  return relationship.activityName ?? '온라인';
}

String _directMessageDisplayName(
  DiscordPeopleState peopleState,
  DiscordUser user,
) {
  final relationship = [
    ...peopleState.friends,
    ...peopleState.incomingRequests,
    ...peopleState.outgoingRequests,
    ...peopleState.blocked,
  ].firstWhereOrNull((item) => item.user.id == user.id);
  return relationship?.displayName ?? user.displayName ?? user.username;
}
