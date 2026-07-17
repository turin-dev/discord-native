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
      color: const Color(0xFF1E1F22),
      child: SizedBox(
        width: 96,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: guilds.length,
          itemBuilder: (context, index) {
            final guild = guilds[index];
            final selected = guild.id == selectedGuildId;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(guild.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF5865F2)
                        : const Color(0xFF313338),
                    borderRadius: BorderRadius.circular(selected ? 16 : 24),
                  ),
                  child: Text(
                    selected ? '✓' : guild.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
      color: const Color(0xFF2B2D31),
      child: SizedBox(
        width: 260,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
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
      height: 52,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1F2023))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
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
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF949BA4),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(
        left: channel.isThread ? 28 : 12,
        right: 8,
      ),
      selected: selected,
      selectedTileColor: const Color(0xFF404249),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      leading: Icon(
        channel.isThread
            ? Icons.forum_outlined
            : channel.type == 1
            ? Icons.person
            : channel.type == 3
            ? Icons.group
            : Icons.tag,
        size: channel.isThread ? 17 : 20,
        color: const Color(0xFF949BA4),
      ),
      title: Text(
        channel.isArchived ? '${channel.name} · 보관됨' : channel.name,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFFB5BAC1),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unreadCount != 0)
            SizedBox(
              key: ValueKey('unread-${channel.id}'),
              width: 32,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF23F42),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ?actions,
        ],
      ),
      onTap: onTap,
    );
  }
}

enum _ChannelAction { edit, delete }

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
    return PopupMenuButton<_ChannelAction>(
      tooltip: '${channel.name} 채널 설정',
      onSelected: (action) {
        switch (action) {
          case _ChannelAction.edit:
            onEdit();
          case _ChannelAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: _ChannelAction.edit, child: Text('채널 편집')),
        PopupMenuItem(value: _ChannelAction.delete, child: Text('채널 삭제')),
      ],
      icon: const Icon(Icons.settings, size: 16),
    );
  }
}

class _UserPanel extends StatelessWidget {
  const _UserPanel({
    required this.user,
    required this.connectionLabel,
    required this.onLogout,
    this.onOpenSettings,
  });

  final DiscordUser? user;
  final String connectionLabel;
  final VoidCallback onLogout;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF232428),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF5865F2),
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? user?.username ?? '연결 중',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  Text(
                    connectionLabel,
                    style: const TextStyle(
                      color: Color(0xFF23A55A),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '사용자 설정',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings, color: Color(0xFFB5BAC1)),
            ),
            IconButton(
              tooltip: '로그아웃',
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: Color(0xFFB5BAC1)),
            ),
          ],
        ),
      ),
    );
  }
}
