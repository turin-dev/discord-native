import 'dart:async';

import 'package:discord_native/app/discord_app_controller.dart';
import 'package:discord_native/app/discord_native_app.dart';
import 'package:discord_native/app/providers.dart';
import 'package:discord_native/core/auth/secure_token_repository.dart';
import 'package:discord_native/core/gateway/discord_gateway_client.dart';
import 'package:discord_native/core/gateway/gateway_session_state.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/system/presentation/desktop_system_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('로그아웃 상태에서는 로그인 화면을 표시한다', (tester) async {
    final controller = DiscordAppController(
      tokenRepository: _EmptyTokenRepository(),
      gateway: _IdleGatewayConnection(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWithValue(controller),
          desktopSystemStateProvider.overrideWith(
            (_) => Stream.value(const DesktopSystemState(isInitialized: true)),
          ),
        ],
        child: const DiscordNativeApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Discord Native'), findsOneWidget);
    expect(find.text('연결'), findsOneWidget);
  });

  testWidgets('저장된 라이트 테마를 MaterialApp에 적용한다', (tester) async {
    final controller = DiscordAppController(
      tokenRepository: _EmptyTokenRepository(),
      gateway: _IdleGatewayConnection(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    const settings = DesktopSettings(
      themeMode: DesktopThemeMode.light,
      accentColorValue: 0xFFEB459E,
      minimizeToTray: true,
      notificationsEnabled: true,
      globalShortcutEnabled: true,
      autoUpdateEnabled: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWithValue(controller),
          desktopSystemStateProvider.overrideWith(
            (_) => Stream.value(
              const DesktopSystemState(settings: settings, isInitialized: true),
            ),
          ),
        ],
        child: const DiscordNativeApp(),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme?.brightness, Brightness.light);
  });
}

final class _EmptyTokenRepository implements TokenRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String input) async {}
}

final class _IdleGatewayConnection implements DiscordGatewayConnection {
  final StreamController<GatewaySessionState> _states =
      StreamController.broadcast();
  final StreamController<Map<String, Object?>> _events =
      StreamController.broadcast();

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  GatewaySessionState get state => const GatewaySessionState.disconnected();

  @override
  Stream<GatewaySessionState> get states => _states.stream;

  @override
  Future<void> connect(String input) async {}

  @override
  Future<void> updateVoiceState({
    required String guildId,
    required String? channelId,
    required bool selfMute,
    required bool selfDeaf,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    await _states.close();
    await _events.close();
  }
}
