import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

ThemeMode materialThemeMode(DesktopThemeMode mode) {
  return switch (mode) {
    DesktopThemeMode.system => ThemeMode.system,
    DesktopThemeMode.light => ThemeMode.light,
    DesktopThemeMode.dark => ThemeMode.dark,
  };
}

ThemeData createDesktopTheme(DesktopSettings settings, Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Color(settings.accentColorValue),
    brightness: brightness,
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: 'Segoe UI',
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? DiscordColors.window
        : const Color(0xFFF2F3F5),
    dialogTheme: DialogThemeData(
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF1E1F22)
          : Colors.white,
    ),
    dividerColor: brightness == Brightness.dark
        ? DiscordColors.divider
        : const Color(0xFFD4D7DC),
    iconTheme: const IconThemeData(color: DiscordColors.textMuted, size: 20),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: brightness == Brightness.dark
          ? DiscordColors.textNormal
          : const Color(0xFF313338),
      displayColor: brightness == Brightness.dark
          ? DiscordColors.text
          : const Color(0xFF060607),
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
    useMaterial3: true,
  );
}
