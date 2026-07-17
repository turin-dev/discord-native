import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/system/presentation/desktop_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('데스크톱 테마 모드를 Material ThemeMode로 변환한다', () {
    expect(materialThemeMode(DesktopThemeMode.system), ThemeMode.system);
    expect(materialThemeMode(DesktopThemeMode.light), ThemeMode.light);
    expect(materialThemeMode(DesktopThemeMode.dark), ThemeMode.dark);
  });

  test('사용자 accent와 brightness를 ThemeData에 적용한다', () {
    const settings = DesktopSettings(
      themeMode: DesktopThemeMode.light,
      accentColorValue: 0xFFEB459E,
      minimizeToTray: true,
      notificationsEnabled: true,
      globalShortcutEnabled: true,
      autoUpdateEnabled: true,
    );

    final theme = createDesktopTheme(settings, Brightness.light);
    final defaultTheme = createDesktopTheme(
      const DesktopSettings.defaults(),
      Brightness.light,
    );

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, isNot(defaultTheme.colorScheme.primary));
    expect(theme.useMaterial3, isTrue);
  });
}
