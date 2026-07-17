enum DesktopThemeMode { system, light, dark }

final class DesktopSettings {
  const DesktopSettings({
    required this.themeMode,
    required this.accentColorValue,
    required this.minimizeToTray,
    required this.notificationsEnabled,
    required this.globalShortcutEnabled,
    required this.autoUpdateEnabled,
  });

  const DesktopSettings.defaults()
    : themeMode = DesktopThemeMode.system,
      accentColorValue = 0xFF5865F2,
      minimizeToTray = true,
      notificationsEnabled = true,
      globalShortcutEnabled = true,
      autoUpdateEnabled = true;

  final DesktopThemeMode themeMode;
  final int accentColorValue;
  final bool minimizeToTray;
  final bool notificationsEnabled;
  final bool globalShortcutEnabled;
  final bool autoUpdateEnabled;

  DesktopSettings copyWith({
    DesktopThemeMode? themeMode,
    int? accentColorValue,
    bool? minimizeToTray,
    bool? notificationsEnabled,
    bool? globalShortcutEnabled,
    bool? autoUpdateEnabled,
  }) {
    return DesktopSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      globalShortcutEnabled:
          globalShortcutEnabled ?? this.globalShortcutEnabled,
      autoUpdateEnabled: autoUpdateEnabled ?? this.autoUpdateEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DesktopSettings &&
        other.themeMode == themeMode &&
        other.accentColorValue == accentColorValue &&
        other.minimizeToTray == minimizeToTray &&
        other.notificationsEnabled == notificationsEnabled &&
        other.globalShortcutEnabled == globalShortcutEnabled &&
        other.autoUpdateEnabled == autoUpdateEnabled;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    accentColorValue,
    minimizeToTray,
    notificationsEnabled,
    globalShortcutEnabled,
    autoUpdateEnabled,
  );
}
