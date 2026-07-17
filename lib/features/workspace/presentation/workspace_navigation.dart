import 'package:collection/collection.dart';
import 'package:discord_native/features/workspace/data/read_state_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/guild_channel_controls.dart';
import 'package:discord_native/features/workspace/presentation/guild_event_controls.dart';
import 'package:discord_native/features/workspace/presentation/guild_role_controls.dart';
import 'package:discord_native/features/workspace/presentation/guild_invite_controls.dart';
import 'package:discord_native/features/voice/domain/discord_voice_ui_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';
import 'package:discord_native/features/workspace/presentation/workspace_voice_controls.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:discord_native/features/workspace/presentation/discord_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class GuildRail extends StatelessWidget {
  const GuildRail({
    required this.guilds,
    required this.selectedGuildId,
    required this.onSelect,
    super.key,
  });

  final List<DiscordGuild> guilds;
  final String? selectedGuildId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DiscordColors.guildRail,
      child: SizedBox(
        width: DiscordLayout.guildRailWidth,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: guilds.length,
          itemBuilder: (context, index) {
            final guild = guilds[index];
            final selected = guild.id == selectedGuildId;
            return _GuildRailItem(
              guild: guild,
              selected: selected,
              onTap: () => onSelect(guild.id),
            );
          },
        ),
      ),
    );
  }
}

class _GuildRailItem extends StatelessWidget {
  const _GuildRailItem({
    required this.guild,
    required this.selected,
    required this.onTap,
  });

  final DiscordGuild guild;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('guild-rail-${guild.id}'),
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 4,
              height: selected ? 40 : 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(4),
                ),
              ),
            ),
          ),
          Tooltip(
            message: guild.name,
            preferBelow: false,
            child: InkWell(
              borderRadius: BorderRadius.circular(selected ? 16 : 24),
              onTap: onTap,
              child: guild.isDirectMessages
                  ? _DirectMessagesIcon(selected: selected)
                  : DiscordGuildIcon(guild: guild, selected: selected),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectMessagesIcon extends StatelessWidget {
  const _DirectMessagesIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: DiscordLayout.guildIconSize,
      height: DiscordLayout.guildIconSize,
      decoration: BoxDecoration(
        color: selected ? DiscordColors.brand : DiscordColors.chat,
        borderRadius: BorderRadius.circular(selected ? 16 : 24),
      ),
      child: const Icon(Icons.discord, color: Colors.white, size: 26),
    );
  }
}

class ChannelSidebar extends StatelessWidget {
  const ChannelSidebar({
    required this.guild,
    required this.channels,
    required this.selectedChannelId,
    required this.currentUser,
    required this.connectionLabel,
    required this.readStates,
    required this.onSelect,
    required this.onLogout,
    this.onOpenUserSettings,
    this.voiceUiState = const DiscordVoiceUiState(),
    this.voiceParticipantNames = const {},
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
    this.canCreateChannel = false,
    this.manageableChannelIds = const {},
    this.guildErrorMessage,
    this.onCreateGuildChannel,
    this.onUpdateGuildChannel,
    this.onDeleteGuildChannel,
    this.canManageRoles = false,
    this.onCreateGuildRole,
    this.onUpdateGuildRole,
    this.onUpdateGuildRolePositions,
    this.onDeleteGuildRole,
    this.canManageInvites = false,
    this.onLoadGuildInvites,
    this.onCreateGuildInvite,
    this.onDeleteGuildInvite,
    this.canManageEvents = false,
    this.onLoadScheduledEvents,
    this.onCreateScheduledEvent,
    this.onUpdateScheduledEvent,
    this.onDeleteScheduledEvent,
    super.key,
  });

  final DiscordGuild? guild;
  final List<DiscordChannel> channels;
  final String? selectedChannelId;
  final DiscordUser? currentUser;
  final String connectionLabel;
  final Map<String, DiscordReadState> readStates;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;
  final VoidCallback? onOpenUserSettings;
  final DiscordVoiceUiState voiceUiState;
  final Map<String, String> voiceParticipantNames;
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
  final bool canCreateChannel;
  final Set<String> manageableChannelIds;
  final String? guildErrorMessage;
  final CreateGuildChannelCallback? onCreateGuildChannel;
  final UpdateGuildChannelCallback? onUpdateGuildChannel;
  final DeleteGuildChannelCallback? onDeleteGuildChannel;
  final bool canManageRoles;
  final CreateGuildRoleCallback? onCreateGuildRole;
  final UpdateGuildRoleCallback? onUpdateGuildRole;
  final UpdateGuildRolePositionsCallback? onUpdateGuildRolePositions;
  final DeleteGuildRoleCallback? onDeleteGuildRole;
  final bool canManageInvites;
  final LoadGuildInvitesCallback? onLoadGuildInvites;
  final CreateGuildInviteCallback? onCreateGuildInvite;
  final DeleteGuildInviteCallback? onDeleteGuildInvite;
  final bool canManageEvents;
  final LoadScheduledEventsCallback? onLoadScheduledEvents;
  final CreateScheduledEventCallback? onCreateScheduledEvent;
  final UpdateScheduledEventCallback? onUpdateScheduledEvent;
  final DeleteScheduledEventCallback? onDeleteScheduledEvent;

  Future<void> _createChannel(BuildContext context) async {
    final callback = onCreateGuildChannel;
    if (callback == null) {
      return;
    }
    final request = await showCreateGuildChannelDialog(
      context,
      categories: channels.where((channel) => channel.isCategory).toList(),
    );
    if (request != null) {
      await callback(request);
    }
  }

  Future<void> _editChannel(
    BuildContext context,
    DiscordChannel channel,
  ) async {
    final callback = onUpdateGuildChannel;
    if (callback == null) {
      return;
    }
    final request = await showUpdateGuildChannelDialog(context, channel);
    if (request != null) {
      await callback(channel.id, request);
    }
  }

  Future<void> _deleteChannel(
    BuildContext context,
    DiscordChannel channel,
  ) async {
    final callback = onDeleteGuildChannel;
    if (callback != null &&
        await showDeleteGuildChannelDialog(context, channel)) {
      await callback(channel.id);
    }
  }

  Future<void> _openServerSettings(BuildContext context) async {
    final currentGuild = guild;
    if (currentGuild == null) {
      return;
    }
    await showGuildRoleManagementDialog(
      context,
      guild: currentGuild,
      channels: channels
          .where((channel) => !channel.isCategory && !channel.isPrivate)
          .toList(),
      onCreate: canManageRoles ? onCreateGuildRole : null,
      onUpdate: canManageRoles ? onUpdateGuildRole : null,
      onUpdatePositions: canManageRoles ? onUpdateGuildRolePositions : null,
      onDelete: canManageRoles ? onDeleteGuildRole : null,
      onLoadInvites: canManageInvites ? onLoadGuildInvites : null,
      onCreateInvite: canManageInvites ? onCreateGuildInvite : null,
      onDeleteInvite: canManageInvites ? onDeleteGuildInvite : null,
      onLoadEvents: canManageEvents ? onLoadScheduledEvents : null,
      onCreateEvent: canManageEvents ? onCreateScheduledEvent : null,
      onUpdateEvent: canManageEvents ? onUpdateScheduledEvent : null,
      onDeleteEvent: canManageEvents ? onDeleteScheduledEvent : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DiscordColors.sidebar,
      child: SizedBox(
        width: DiscordLayout.channelSidebarWidth,
        child: Column(
          children: [
            _ServerHeader(
              name: guild?.name ?? '서버를 기다리는 중',
              onCreateChannel: canCreateChannel && onCreateGuildChannel != null
                  ? () => _createChannel(context)
                  : null,
              onOpenSettings:
                  canManageRoles || canManageInvites || canManageEvents
                  ? () => _openServerSettings(context)
                  : null,
            ),
            if (guildErrorMessage case final message?)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFF23F42),
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  _SectionLabel(
                    guild?.isDirectMessages == true ? '다이렉트 메시지' : '채널',
                  ),
                  for (final channel in channels)
                    if (channel.isCategory)
                      _SectionLabel(
                        channel.name,
                        key: ValueKey('category-${channel.id}'),
                        actions: _channelActions(context, channel),
                      )
                    else if (channel.isTextChannel)
                      _ChannelTile(
                        channel: channel,
                        selected: channel.id == selectedChannelId,
                        unreadCount: readStates[channel.id]?.unreadCount ?? 0,
                        onTap: () => onSelect(channel.id),
                        actions: _channelActions(context, channel),
                      )
                    else if (channel.isVoiceChannel &&
                        onJoinVoiceChannel != null)
                      VoiceChannelTile(
                        channel: channel,
                        active: voiceUiState.voice.channelId == channel.id,
                        participants: voiceUiState.voice.participantsForChannel(
                          channel.id,
                        ),
                        participantNames: voiceParticipantNames,
                        onJoin: onJoinVoiceChannel!,
                        onSetUserVolume: onSetVoiceUserVolume,
                        watchingStreamKey: voiceUiState.video.watchingStreamKey,
                        onWatchStream: onWatchVoiceStream,
                        onStopWatchingStream: onStopWatchingVoiceStream,
                      ),
                ],
              ),
            ),
            if (voiceUiState.voice.channelId case final channelId?)
              VoiceConnectionPanel(
                state: voiceUiState,
                channelName:
                    channels
                        .where((channel) => channel.id == channelId)
                        .map((channel) => channel.name)
                        .firstOrNull ??
                    channelId,
                onSetMuted: onSetVoiceMuted ?? (_) {},
                onSetDeafened: onSetVoiceDeafened ?? (_) {},
                onSetInputMode: onSetVoiceInputMode ?? (_) {},
                onPushToTalkPressed: onPushToTalkPressed ?? (_) {},
                onSetCameraEnabled: onSetCameraEnabled ?? (_) {},
                onSetScreenShareEnabled: onSetScreenShareEnabled,
                onSetScreenSharePaused: onSetScreenSharePaused,
                localVideoStream: localVideoStream,
                localScreenStream: localScreenStream,
                onLeave: onLeaveVoiceChannel ?? () {},
              ),
            _UserPanel(
              user: currentUser,
              connectionLabel: connectionLabel,
              voiceUiState: voiceUiState,
              onSetMuted: onSetVoiceMuted,
              onSetDeafened: onSetVoiceDeafened,
              onLogout: onLogout,
              onOpenSettings: onOpenUserSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _channelActions(BuildContext context, DiscordChannel channel) {
    if (!manageableChannelIds.contains(channel.id)) {
      return null;
    }
    return _ChannelActionsButton(
      channel: channel,
      onEdit: () => _editChannel(context, channel),
      onDelete: () => _deleteChannel(context, channel),
    );
  }
}

class _ServerHeader extends StatelessWidget {
  const _ServerHeader({
    required this.name,
    this.onCreateChannel,
    this.onOpenSettings,
  });

  final String name;
  final VoidCallback? onCreateChannel;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DiscordLayout.channelHeaderHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DiscordColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DiscordTextStyles.heading,
            ),
          ),
          if (onCreateChannel != null)
            IconButton(
              tooltip: '채널 만들기',
              onPressed: onCreateChannel,
              icon: const Icon(Icons.add, size: 20),
            ),
          if (onOpenSettings != null)
            IconButton(
              tooltip: '서버 설정',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune, size: 20),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.actions, super.key});

  final String label;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label.toUpperCase(), style: DiscordTextStyles.label),
          ),
          ?actions,
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.selected,
    required this.unreadCount,
    required this.onTap,
    this.actions,
  });

  final DiscordChannel channel;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DiscordLayout.channelTileHeight,
      child: Material(
        color: selected ? DiscordColors.selected : Colors.transparent,
        borderRadius: const BorderRadius.all(DiscordRadius.small),
        child: InkWell(
          borderRadius: const BorderRadius.all(DiscordRadius.small),
          onTap: onTap,
          hoverColor: DiscordColors.hover,
          child: Padding(
            padding: EdgeInsets.only(left: channel.isThread ? 26 : 6, right: 4),
            child: Row(
              children: [
                Icon(
                  _channelIcon(channel),
                  size: channel.isThread ? 16 : 20,
                  color: selected
                      ? DiscordColors.text
                      : DiscordColors.textFaint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    channel.isArchived ? '${channel.name} · 보관됨' : channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DiscordTextStyles.channel.copyWith(
                      color: selected
                          ? DiscordColors.text
                          : unreadCount > 0
                          ? DiscordColors.textNormal
                          : DiscordColors.textMuted,
                      fontWeight: unreadCount > 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (unreadCount != 0)
                  _UnreadBadge(channelId: channel.id, count: unreadCount),
                ?actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _channelIcon(DiscordChannel channel) {
  if (channel.isThread) {
    return Icons.forum_outlined;
  }
  return switch (channel.type) {
    1 => Icons.person,
    3 => Icons.group,
    5 => Icons.campaign,
    15 || 16 => Icons.forum,
    _ => Icons.tag,
  };
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.channelId, required this.count});

  final String channelId;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('unread-$channelId'),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: const BoxDecoration(
        color: DiscordColors.danger,
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChannelActionsButton extends StatelessWidget {
  const _ChannelActionsButton({
    required this.channel,
    required this.onEdit,
    required this.onDelete,
  });

  final DiscordChannel channel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(DiscordColors.sidebar),
      ),
      menuChildren: [
        MenuItemButton(onPressed: onEdit, child: const Text('채널 편집')),
        MenuItemButton(onPressed: onDelete, child: const Text('채널 삭제')),
      ],
      builder: (context, controller, _) => IconButton(
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        padding: EdgeInsets.zero,
        tooltip: '${channel.name} 채널 설정',
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: const Icon(Icons.edit_outlined, size: 15),
      ),
    );
  }
}

class _UserPanel extends StatelessWidget {
  const _UserPanel({
    required this.user,
    required this.connectionLabel,
    required this.voiceUiState,
    required this.onLogout,
    this.onSetMuted,
    this.onSetDeafened,
    this.onOpenSettings,
  });

  final DiscordUser? user;
  final String connectionLabel;
  final DiscordVoiceUiState voiceUiState;
  final VoidCallback onLogout;
  final ValueChanged<bool>? onSetMuted;
  final ValueChanged<bool>? onSetDeafened;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DiscordColors.sidebarFooter,
      child: SizedBox(
        height: DiscordLayout.userPanelHeight,
        child: Row(
          children: [
            const SizedBox(width: 8),
            DiscordUserAvatar(
              user: user,
              radius: 16,
              statusColor: DiscordColors.positive,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? user?.username ?? '연결 중',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DiscordColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    connectionLabel,
                    style: const TextStyle(
                      color: DiscordColors.textFaint,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            _UserActionButton(
              tooltip: voiceUiState.voice.selfMute ? '음소거 해제' : '음소거',
              onPressed: onSetMuted == null
                  ? null
                  : () => onSetMuted!(!voiceUiState.voice.selfMute),
              icon: voiceUiState.voice.selfMute ? Icons.mic_off : Icons.mic,
            ),
            _UserActionButton(
              tooltip: voiceUiState.voice.selfDeaf ? '듣기 활성화' : '듣기 끄기',
              onPressed: onSetDeafened == null
                  ? null
                  : () => onSetDeafened!(!voiceUiState.voice.selfDeaf),
              icon: voiceUiState.voice.selfDeaf
                  ? Icons.headset_off
                  : Icons.headphones,
            ),
            _UserMenu(onOpenSettings: onOpenSettings, onLogout: onLogout),
          ],
        ),
      ),
    );
  }
}

class _UserActionButton extends StatelessWidget {
  const _UserActionButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: DiscordColors.textMuted),
    );
  }
}

enum _UserMenuAction { settings, logout }

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.onOpenSettings, required this.onLogout});

  final VoidCallback? onOpenSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_UserMenuAction>(
      tooltip: '사용자 메뉴',
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.settings,
        size: 18,
        color: DiscordColors.textMuted,
      ),
      onSelected: (action) {
        switch (action) {
          case _UserMenuAction.settings:
            onOpenSettings?.call();
          case _UserMenuAction.logout:
            onLogout();
        }
      },
      itemBuilder: (_) => [
        if (onOpenSettings != null)
          const PopupMenuItem(
            value: _UserMenuAction.settings,
            child: Text('사용자 설정'),
          ),
        const PopupMenuItem(value: _UserMenuAction.logout, child: Text('로그아웃')),
      ],
    );
  }
}
