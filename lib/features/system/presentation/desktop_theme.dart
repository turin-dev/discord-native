import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

ThemeMode materialThemeMode(DesktopThemeMode mode) {
  return switch (mode) {
    DesktopThemeMode.system => ThemeMode.system,
    DesktopThemeMode.light => ThemeMode.light,
    DesktopThemeMode.ash => ThemeMode.dark,
    DesktopThemeMode.dark => ThemeMode.dark,
    DesktopThemeMode.onyx => ThemeMode.dark,
  };
}

ThemeData createDesktopTheme(DesktopSettings settings, Brightness brightness) {
  final palette = _palette(
    settings.themeMode,
    brightness,
  ).copyWith(brand: Color(settings.accentColorValue));
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: Color(settings.accentColorValue),
        brightness: brightness,
      ).copyWith(
        surface: palette.chat,
        onSurface: palette.textNormal,
        error: palette.danger,
      );
  return ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: 'Segoe UI',
    scaffoldBackgroundColor: palette.window,
    dialogTheme: DialogThemeData(backgroundColor: palette.chat),
    dividerColor: palette.divider,
    iconTheme: IconThemeData(color: palette.textMuted, size: 20),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: palette.textNormal,
      displayColor: palette.text,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: Color(0xFF111214),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      textStyle: TextStyle(
        color: DiscordColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    extensions: [palette],
    useMaterial3: true,
  );
}

DiscordPalette _palette(DesktopThemeMode mode, Brightness brightness) {
  return switch (mode) {
    DesktopThemeMode.system =>
      brightness == Brightness.light
          ? DiscordPalette.light
          : DiscordPalette.onyx,
    DesktopThemeMode.light => DiscordPalette.light,
    DesktopThemeMode.ash => DiscordPalette.ash,
    DesktopThemeMode.dark => DiscordPalette.dark,
    DesktopThemeMode.onyx => DiscordPalette.onyx,
  };
}
