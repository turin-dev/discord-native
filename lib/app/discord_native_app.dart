import 'dart:async';

import 'package:discord_native/app/discord_app_controller.dart';
import 'package:discord_native/app/providers.dart';
import 'package:discord_native/core/auth/discord_account_repository.dart';
import 'package:discord_native/features/auth/presentation/login_page.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/system/presentation/desktop_settings_dialog.dart';
import 'package:discord_native/features/system/presentation/desktop_theme.dart';
import 'package:discord_native/features/workspace/presentation/discord_workspace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscordNativeApp extends ConsumerWidget {
  const DiscordNativeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final settings = ref
        .watch(desktopSystemStateProvider)
        .when(
          data: (value) => value.settings,
          error: (_, _) => const DesktopSettings.defaults(),
          loading: DesktopSettings.defaults,
        );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Discord Native',
      themeMode: materialThemeMode(settings.themeMode),
      theme: createDesktopTheme(settings, Brightness.light),
      darkTheme: createDesktopTheme(settings, Brightness.dark),
      home: state.when(
        data: (value) => _AppHome(state: value),
        loading: () => const _StartupPage(),
        error: (_, _) => const _StartupPage(),
      ),
    );
  }
}

class _AppHome extends ConsumerWidget {
  const _AppHome({required this.state});

  final DiscordAppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appControllerProvider);
    final accounts = ref
        .watch(accountSessionStateProvider)
        .when(
          data: (value) => value.accounts,
          error: (_, _) => const <SavedDiscordAccount>[],
          loading: () => const <SavedDiscordAccount>[],
        );
    final videoCapture = ref.read(videoCaptureProvider);
    final screenCapture = ref.read(screenCaptureProvider);
    final settings = ref
        .watch(desktopSystemStateProvider)
        .when(
          data: (value) => value.settings,
          error: (_, _) => const DesktopSettings.defaults(),
          loading: DesktopSettings.defaults,
        );
    return switch (state.phase) {
      DiscordAppPhase.booting => const _StartupPage(),
      DiscordAppPhase.signedOut || DiscordAppPhase.failure => LoginPage(
        errorMessage: state.errorMessage,
        onConnect: controller.connect,
        savedAccounts: accounts,
        onSelectAccount: controller.switchAccount,
      ),
      _ => DiscordWorkspacePage(
        state: state.workspace,
        peopleState: state.peopleState,
        peopleErrorMessage: state.peopleErrorMessage,
        guildErrorMessage: state.guildErrorMessage,
        messageState: state.messageState,
        typingUsers: state.typingState.usersForChannel(state.selectedChannelId),
        searchState: state.searchState,
        readStates: state.readStates,
        selectedGuildId: state.selectedGuildId,
        selectedChannelId: state.selectedChannelId,
        connectionLabel: state.connectionLabel,
        voiceUiState: state.voiceUiState,
        localVideoStream: videoCapture.previewStream,
        localScreenStream: screenCapture.previewStream,
        displayDensity: settings.displayDensity,
        channelSidebarWidth: settings.channelSidebarWidth,
        pinnedChannelIds: Set.unmodifiable(settings.pinnedChannelIds),
        onToggleChannelPinned: (channelId) {
          final pinned = settings.pinnedChannelIds.contains(channelId);
          final nextIds = pinned
              ? settings.pinnedChannelIds
                    .where((id) => id != channelId)
                    .toList()
              : [...settings.pinnedChannelIds, channelId];
          unawaited(
            ref
                .read(desktopSystemControllerProvider)
                .updateSettings(settings.copyWith(pinnedChannelIds: nextIds)),
          );
        },
        onChannelSidebarWidthChanged: (width) {
          unawaited(
            ref
                .read(desktopSystemControllerProvider)
                .updateSettings(settings.copyWith(channelSidebarWidth: width)),
          );
        },
        onSelectGuild: controller.selectGuild,
        onSelectChannel: controller.selectChannel,
        onJoinVoiceChannel: (channelId) {
          unawaited(controller.joinVoiceChannel(channelId));
        },
        onSetVoiceMuted: (muted) {
          unawaited(controller.setVoiceMuted(muted));
        },
        onSetVoiceDeafened: (deafened) {
          unawaited(controller.setVoiceDeafened(deafened));
        },
        onLeaveVoiceChannel: () {
          unawaited(controller.leaveVoiceChannel());
        },
        onSetVoiceInputMode: (inputMode) {
          unawaited(controller.setVoiceInputMode(inputMode));
        },
        onPushToTalkPressed: (pressed) {
          unawaited(controller.setPushToTalkPressed(pressed));
        },
        onSetVoiceUserVolume: controller.setVoiceUserVolume,
        onSetCameraEnabled: (enabled) {
          unawaited(controller.setCameraEnabled(enabled));
        },
        onSetScreenShareEnabled: (enabled) {
          unawaited(controller.setScreenShareEnabled(enabled));
        },
        onSetScreenSharePaused: (paused) {
          unawaited(controller.setScreenSharePaused(paused));
        },
        onWatchVoiceStream: (streamKey) {
          unawaited(controller.watchVoiceStream(streamKey));
        },
        onStopWatchingVoiceStream: () {
          unawaited(controller.stopWatchingVoiceStream());
        },
        onSendMessage: controller.sendMessage,
        onSendPoll: controller.sendPoll,
        onSendSticker: controller.sendSticker,
        onTyping: () => unawaited(controller.triggerTyping()),
        onLoadOlderMessages: controller.loadOlderMessages,
        onSendReply: controller.sendReply,
        onToggleReaction: controller.toggleReaction,
        onEditMessage: controller.editMessage,
        onDeleteMessage: controller.deleteMessage,
        onTogglePinned: controller.togglePinned,
        onPickAttachments: ref.read(attachmentPickerProvider).pick,
        onDownloadAttachment: controller.downloadAttachment,
        onSendAttachments: controller.sendAttachments,
        onRefreshThreads: controller.refreshThreads,
        onCreateThread: controller.createThread,
        onStartThreadFromMessage: controller.startThreadFromMessage,
        onJoinThread: controller.joinThread,
        onSetThreadArchived: controller.setThreadArchived,
        onSearchMessages: (query, currentChannelOnly) {
          return controller.searchMessages(
            query,
            currentChannelOnly: currentChannelOnly,
          );
        },
        onSelectSearchResult: controller.selectSearchResult,
        onClearSearch: controller.clearSearch,
        onOpenDirectMessage: controller.openDirectMessage,
        onSendFriendRequest: controller.sendFriendRequest,
        onAcceptFriendRequest: controller.acceptFriendRequest,
        onBlockRelationship: controller.blockRelationship,
        onRemoveRelationship: controller.removeRelationship,
        onCreateGuildChannel: controller.createGuildChannel,
        onUpdateGuildChannel: controller.updateGuildChannel,
        onDeleteGuildChannel: controller.deleteGuildChannel,
        onCreateGuildRole: controller.createGuildRole,
        onUpdateGuildRole: controller.updateGuildRole,
        onUpdateGuildRolePositions: controller.updateGuildRolePositions,
        onDeleteGuildRole: controller.deleteGuildRole,
        onLoadGuildInvites: controller.loadGuildInvites,
        onCreateGuildInvite: controller.createGuildInvite,
        onDeleteGuildInvite: controller.deleteGuildInvite,
        onLoadScheduledEvents: controller.loadScheduledEvents,
        onCreateScheduledEvent: controller.createScheduledEvent,
        onUpdateScheduledEvent: controller.updateScheduledEvent,
        onDeleteScheduledEvent: controller.deleteScheduledEvent,
        onCreateForumPost: controller.createForumPost,
        onOpenUserSettings: () {
          unawaited(
            showDialog<void>(
              context: context,
              builder: (_) => const DesktopSettingsDialog(),
            ),
          );
        },
        onLogout: () => unawaited(controller.logout()),
      ),
    };
  }
}

class _StartupPage extends StatelessWidget {
  const _StartupPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF111214),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.discord, size: 64, color: Color(0xFF5865F2)),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Discord Native 시작 중'),
          ],
        ),
      ),
    );
  }
}
