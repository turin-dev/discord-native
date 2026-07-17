import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/system/presentation/desktop_theme.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('데스크톱 테마 모드를 Material ThemeMode로 변환한다', () {
    expect(materialThemeMode(DesktopThemeMode.system), ThemeMode.system);
    expect(materialThemeMode(DesktopThemeMode.light), ThemeMode.light);
    expect(materialThemeMode(DesktopThemeMode.ash), ThemeMode.dark);
    expect(materialThemeMode(DesktopThemeMode.dark), ThemeMode.dark);
    expect(materialThemeMode(DesktopThemeMode.onyx), ThemeMode.dark);
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

  test('Discord 네 가지 테마마다 고유 surface palette를 사용한다', () {
    const base = DesktopSettings.defaults();
    final light = createDesktopTheme(
      base.copyWith(themeMode: DesktopThemeMode.light),
      Brightness.light,
    );
    final ash = createDesktopTheme(
      base.copyWith(themeMode: DesktopThemeMode.ash),
      Brightness.dark,
    );
    final dark = createDesktopTheme(
      base.copyWith(themeMode: DesktopThemeMode.dark),
      Brightness.dark,
    );
    final onyx = createDesktopTheme(
      base.copyWith(themeMode: DesktopThemeMode.onyx),
      Brightness.dark,
    );

    expect(discordPalette(light).chat, const Color(0xFFFFFFFF));
    expect(discordPalette(ash).chat, isNot(discordPalette(dark).chat));
    expect(discordPalette(dark).chat, const Color(0xFF313338));
    expect(discordPalette(onyx).chat, const Color(0xFF070709));
  });
}
