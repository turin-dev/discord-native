import 'package:discord_native/features/system/domain/desktop_push_to_talk.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/system/presentation/desktop_voice_settings_section.dart';
import 'package:discord_native/features/voice/domain/discord_audio_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('전역 PTT 스위치와 단축키 선택을 설정 변경으로 전달한다', (tester) async {
    final changes = <DesktopSettings>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopVoiceSettingsSection(
            settings: const DesktopSettings.defaults(),
            devices: const DiscordAudioDeviceCatalog(),
            enabled: true,
            onChanged: changes.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('전역 Push-to-Talk'));
    expect(changes.last.globalPushToTalkEnabled, isFalse);

    await tester.tap(find.text('F8'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('F10').last);
    await tester.pumpAndSettle();

    expect(changes.last.pushToTalkKey, DesktopPushToTalkKey.f10);
  });

  testWidgets('release delay slider를 움직이면 정규화된 값을 전달한다', (tester) async {
    final changes = <DesktopSettings>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopVoiceSettingsSection(
            settings: const DesktopSettings.defaults(),
            devices: const DiscordAudioDeviceCatalog(),
            enabled: true,
            onChanged: changes.add,
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('push-to-talk-release-delay')),
      const Offset(180, 0),
    );

    expect(changes.last.pushToTalkReleaseDelayMs, inInclusiveRange(0, 2000));
    expect(changes.last.pushToTalkReleaseDelayMs, greaterThan(20));
  });
}
