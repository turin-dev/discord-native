import 'package:discord_native/app/providers.dart';
import 'package:discord_native/core/auth/discord_account_repository.dart';
import 'package:discord_native/core/auth/discord_account_session_controller.dart';
import 'package:discord_native/features/system/presentation/desktop_settings_dialog.dart';
import 'package:discord_native/features/system/presentation/desktop_system_controller.dart';
import 'package:discord_native/features/voice/domain/discord_audio_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Windows 설정과 저장 계정을 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioDeviceCatalogProvider.overrideWith(
            (_) async => const DiscordAudioDeviceCatalog(
              inputDevices: [DiscordAudioDevice(id: 'mic-1', label: 'USB 마이크')],
              outputDevices: [DiscordAudioDevice(id: '7', label: 'USB 헤드셋')],
            ),
          ),
          desktopSystemStateProvider.overrideWith(
            (_) => Stream.value(const DesktopSystemState(isInitialized: true)),
          ),
          accountSessionStateProvider.overrideWith(
            (_) => Stream.value(
              const DiscordAccountSessionState(
                accounts: [
                  SavedDiscordAccount(id: 'user-1', username: 'alice'),
                ],
                selectedAccountId: 'user-1',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DesktopSettingsDialog())),
      ),
    );
    await tester.pump();

    expect(find.text('사용자 설정'), findsOneWidget);
    expect(find.text('닫을 때 트레이로 최소화'), findsOneWidget);
    expect(find.text('새 메시지 알림 및 소리'), findsOneWidget);
    expect(find.text('전역 단축키 Ctrl+Shift+D'), findsOneWidget);
    expect(find.text('자동 업데이트'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Ash'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Onyx'), findsOneWidget);
    expect(find.text('Compact'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Spacious'), findsOneWidget);
    expect(find.text('입력 장치'), findsOneWidget);
    expect(find.text('출력 장치'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
  });

  testWidgets('설정과 계정 로드 오류를 사용자에게 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioDeviceCatalogProvider.overrideWith(
            (_) async => const DiscordAudioDeviceCatalog(),
          ),
          desktopSystemStateProvider.overrideWith(
            (_) => Stream<DesktopSystemState>.error(StateError('settings')),
          ),
          accountSessionStateProvider.overrideWith(
            (_) => Stream<DiscordAccountSessionState>.error(
              StateError('accounts'),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DesktopSettingsDialog())),
      ),
    );
    await tester.pump();

    expect(find.text('설정을 불러오지 못했습니다.'), findsOneWidget);
    expect(find.text('READY가 완료된 계정이 여기에 안전하게 저장됩니다.'), findsOneWidget);
  });
}
