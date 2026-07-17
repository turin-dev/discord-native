import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:discord_native/app/discord_app_controller.dart';
import 'package:discord_native/core/auth/discord_account_repository.dart';
import 'package:discord_native/core/auth/discord_account_session_controller.dart';
import 'package:discord_native/core/auth/secure_token_repository.dart';
import 'package:discord_native/core/gateway/discord_gateway_client.dart';
import 'package:discord_native/core/gateway/web_socket_gateway_transport.dart';
import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/messages/data/attachment_download_service.dart';
import 'package:discord_native/features/messages/data/attachment_picker.dart';
import 'package:discord_native/features/messages/data/discord_message_repository.dart';
import 'package:discord_native/features/messages/data/message_cache_repository.dart';
import 'package:discord_native/features/system/data/desktop_settings_repository.dart';
import 'package:discord_native/features/system/data/windows_desktop_system_bridge.dart';
import 'package:discord_native/features/system/domain/desktop_system_bridge.dart';
import 'package:discord_native/features/system/presentation/desktop_system_controller.dart';
import 'package:discord_native/features/voice/data/discord_dave_session.dart';
import 'package:discord_native/features/voice/data/discord_audio_device_catalog.dart';
import 'package:discord_native/features/voice/data/discord_opus_codec.dart';
import 'package:discord_native/features/voice/data/discord_voice_coordinator.dart';
import 'package:discord_native/features/voice/data/discord_voice_gateway_client.dart';
import 'package:discord_native/features/voice/data/discord_voice_media_engine.dart';
import 'package:discord_native/features/voice/data/native_voice_transports.dart';
import 'package:discord_native/features/voice/data/record_discord_microphone_capture.dart';
import 'package:discord_native/features/voice/data/soloud_discord_voice_playback.dart';
import 'package:discord_native/features/video/data/flutter_discord_video_capture.dart';
import 'package:discord_native/features/video/data/native_discord_voice_rtc_transport.dart';
import 'package:discord_native/features/voice/domain/discord_audio_device.dart';
import 'package:discord_native/features/workspace/data/discord_direct_message_repository.dart';
import 'package:discord_native/features/workspace/data/discord_channel_management_repository.dart';
import 'package:discord_native/features/workspace/data/discord_client_sync_repository.dart';
import 'package:discord_native/features/workspace/data/discord_relationship_repository.dart';
import 'package:discord_native/features/workspace/data/discord_role_repository.dart';
import 'package:discord_native/features/workspace/data/discord_invite_repository.dart';
import 'package:discord_native/features/workspace/data/discord_scheduled_event_repository.dart';
import 'package:discord_native/features/workspace/data/read_state_repository.dart';
import 'package:discord_native/features/workspace/data/discord_thread_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final secretStorageProvider = Provider<SecretStorage>((ref) {
  return FlutterSecretStorage.platformDefault();
});

final tokenRepositoryProvider = Provider<TokenRepository>((ref) {
  return SecureTokenRepository(ref.watch(secretStorageProvider));
});

final accountRepositoryProvider = Provider<DiscordAccountRepository>((ref) {
  return SecureDiscordAccountRepository(ref.watch(secretStorageProvider));
});

final accountSessionProvider = Provider<DiscordAccountSessionController>((ref) {
  final controller = DiscordAccountSessionController(
    ref.watch(accountRepositoryProvider),
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});

final accountSessionStateProvider = StreamProvider<DiscordAccountSessionState>((
  ref,
) {
  return ref.watch(accountSessionProvider).states;
});

final desktopSettingsRepositoryProvider = Provider<DesktopSettingsRepository>((
  ref,
) {
  return JsonDesktopSettingsRepository(
    SecureDesktopSettingsStorage(ref.watch(secretStorageProvider)),
  );
});

final desktopSystemBridgeProvider = Provider<DesktopSystemBridge>((ref) {
  if (Platform.isWindows) {
    return WindowsDesktopSystemBridge();
  }
  return const NoopDesktopSystemBridge();
});

final desktopSystemControllerProvider = Provider<DesktopSystemController>((
  ref,
) {
  final controller = DesktopSystemController(
    ref.watch(desktopSettingsRepositoryProvider),
    ref.watch(desktopSystemBridgeProvider),
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  unawaited(controller.initialize());
  return controller;
});

final desktopSystemStateProvider = StreamProvider<DesktopSystemState>((ref) {
  return ref.watch(desktopSystemControllerProvider).states;
});

final audioDeviceCatalogProvider = FutureProvider<DiscordAudioDeviceCatalog>((
  ref,
) {
  return loadDiscordAudioDeviceCatalog();
});

final gatewayConnectionProvider = Provider<DiscordGatewayConnection>((ref) {
  return DiscordGatewayClient(transport: WebSocketGatewayTransport());
});

final attachmentPickerProvider = Provider<AttachmentPicker>((ref) {
  return const FilePickerAttachmentPicker();
});

final readStateRepositoryProvider = Provider<ReadStateRepository>((ref) {
  sqfliteFfiInit();
  return SqliteReadStateRepository(
    databaseFactory: databaseFactoryFfi,
    databasePath: () async {
      final directory = await getApplicationSupportDirectory();
      return path.join(directory.path, 'discord_native.db');
    },
  );
});

final messageCacheRepositoryProvider = Provider<MessageCacheRepository>((ref) {
  sqfliteFfiInit();
  return SqliteMessageCacheRepository(
    databaseFactory: databaseFactoryFfi,
    databasePath: () async {
      final directory = await getApplicationSupportDirectory();
      return path.join(directory.path, 'discord_native_message_cache.db');
    },
  );
});

final appControllerProvider = Provider<DiscordAppController>((ref) {
  final gateway = ref.watch(gatewayConnectionProvider);
  final desktopSystem = ref.watch(desktopSystemControllerProvider);
  final videoCapture = ref.watch(videoCaptureProvider);
  final screenCapture = ref.watch(screenCaptureProvider);
  final controller = DiscordAppController(
    tokenRepository: ref.watch(tokenRepositoryProvider),
    gateway: gateway,
    accountSession: ref.watch(accountSessionProvider),
    messageNotificationCallback: (notification) {
      return desktopSystem.showMessageNotification(
        title: notification.title,
        body: notification.body,
      );
    },
    voiceCoordinator: _createVoiceCoordinator(
      gateway,
      videoCapture,
      screenCapture,
      desktopSystem,
    ),
    attachmentDownloadService:
        DiscordAttachmentDownloadService.platformDefault(),
    messageRepositoryFactory: (token) {
      return DiscordMessageRepository(
        DiscordRestClient(token: token, executor: DioDiscordRequestExecutor()),
      );
    },
    threadRepositoryFactory: (token) {
      return DiscordThreadRepository(
        DiscordRestClient(token: token, executor: DioDiscordRequestExecutor()),
      );
    },
    directMessageRepositoryFactory: (token) {
      return DiscordDirectMessageRepository(
        DiscordRestClient(token: token, executor: DioDiscordRequestExecutor()),
      );
    },
    relationshipRepositoryFactory: (token) {
      return DiscordRelationshipRepository(
        DiscordRestClient(token: token, executor: DioDiscordRequestExecutor()),
      );
    },
    channelManagementRepositoryFactory: (token) {
      return DiscordChannelManagementRepository(
        DiscordRestClient(token: token, executor: DioDiscordRequestExecutor()),
      );
    },
    roleRepositoryFactory: (token) {
      return DiscordRoleRepository(
        DiscordRestClient(token: token, executor: DioDiscordRequestExecutor()),
      );
    },
    inviteRepositoryFactory: (token) {
      return DiscordInviteRepository(
        DiscordRestClient(token: token, executor: DioDiscordRequestExecutor()),
      );
    },
    scheduledEventRepositoryFactory: (token) {
      return DiscordScheduledEventRepository(
        DiscordRestClient(token: token, executor: DioDiscordRequestExecutor()),
      );
    },
    clientSyncRepositoryFactory: (token) {
      return DiscordClientSyncRepository(
        DiscordRestClient(token: token, executor: DioDiscordRequestExecutor()),
      );
    },
    readStateRepository: ref.watch(readStateRepositoryProvider),
    messageCacheRepository: ref.watch(messageCacheRepositoryProvider),
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  unawaited(controller.initialize());
  return controller;
});

final videoCaptureProvider = Provider<FlutterDiscordVideoCapture>((ref) {
  final capture = FlutterDiscordVideoCapture();
  ref.onDispose(() => unawaited(capture.stop()));
  return capture;
});

final screenCaptureProvider = Provider<FlutterDiscordVideoCapture>((ref) {
  final capture = FlutterDiscordVideoCapture();
  ref.onDispose(() => unawaited(capture.stop()));
  return capture;
});

final appStateProvider = StreamProvider<DiscordAppState>((ref) {
  return ref.watch(appControllerProvider).states;
});

DiscordVoiceCoordinator _createVoiceCoordinator(
  DiscordGatewayConnection gateway,
  FlutterDiscordVideoCapture videoCapture,
  FlutterDiscordVideoCapture screenCapture,
  DesktopSystemController desktopSystem,
) {
  return DiscordVoiceCoordinator(
    mainGateway: gateway,
    networkFactory: _createVoiceNetworkConnection,
    streamNetworkFactory: _createVoiceNetworkConnection,
    videoCapture: videoCapture,
    screenCapture: screenCapture,
    mediaFactory: (network) => _createVoiceMediaConnection(
      network,
      inputDeviceId: desktopSystem.state.settings.inputDeviceId,
      outputDeviceId: desktopSystem.state.settings.outputDeviceId,
    ),
    streamMediaFactory: (network) => _createVoiceMediaConnection(
      network,
      captureInput: false,
      inputDeviceId: desktopSystem.state.settings.inputDeviceId,
      outputDeviceId: desktopSystem.state.settings.outputDeviceId,
    ),
  );
}

DiscordVoiceNetworkConnection _createVoiceNetworkConnection() {
  final daveSession = NativeDiscordDaveSession.open(libraryPath: 'libdave.dll');
  try {
    final client = DiscordVoiceGatewayClient(
      transport: WebSocketVoiceGatewayTransport(),
      udp: NativeVoiceUdpTransport(),
      daveSession: daveSession,
      rtcTransport: NativeDiscordVoiceRtcTransport(),
      maxDaveProtocolVersion: daveSession.maxSupportedProtocolVersion,
    );
    return GatewayDiscordVoiceNetworkConnection(client);
  } on Object {
    daveSession.close();
    rethrow;
  }
}

DiscordVoiceMediaConnection _createVoiceMediaConnection(
  DiscordVoiceMediaNetwork network, {
  bool captureInput = true,
  String inputDeviceId = '',
  String outputDeviceId = '',
}) {
  final opus = NativeDiscordOpusCodec.open(libraryPath: 'opus.dll');
  final random = Random.secure();
  return DiscordVoiceMediaEngine(
    network: network,
    microphone: RecordDiscordMicrophoneCapture(inputDeviceId: inputDeviceId),
    opus: opus,
    playback: SoloudDiscordVoicePlayback(outputDeviceId: outputDeviceId),
    captureInput: captureInput,
    initialSequence: random.nextInt(0x10000),
    initialTimestamp: _nextUint32(random),
    initialNonce: _nextUint32(random),
  );
}

int _nextUint32(Random random) {
  return (random.nextInt(0x10000) << 16) | random.nextInt(0x10000);
}
