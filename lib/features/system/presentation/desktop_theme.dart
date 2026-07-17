import 'package:discord_native/features/system/domain/desktop_settings.dart';
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
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF111214)
        : const Color(0xFFF2F3F5),
    dialogTheme: DialogThemeData(
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF1E1F22)
          : Colors.white,
    ),
    dividerColor: brightness == Brightness.dark
        ? const Color(0xFF3F4147)
        : const Color(0xFFD4D7DC),
    useMaterial3: true,
  );
}
