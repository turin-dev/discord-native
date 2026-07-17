import 'package:collection/collection.dart';

enum DesktopThemeMode { system, light, ash, dark, onyx }

enum DesktopDisplayDensity { compact, defaultMode, spacious }

final class DesktopSettings {
  const DesktopSettings({
    required this.themeMode,
    required this.accentColorValue,
    required this.minimizeToTray,
    required this.notificationsEnabled,
    required this.globalShortcutEnabled,
    required this.autoUpdateEnabled,
    this.displayDensity = DesktopDisplayDensity.defaultMode,
    this.channelSidebarWidth = defaultChannelSidebarWidth,
    this.pinnedChannelIds = const [],
    this.inputDeviceId = '',
    this.outputDeviceId = '',
  });

  static const minChannelSidebarWidth = 220.0;
  static const defaultChannelSidebarWidth = 240.0;
  static const maxChannelSidebarWidth = 360.0;

  const DesktopSettings.defaults()
    : themeMode = DesktopThemeMode.system,
      accentColorValue = 0xFF5865F2,
      minimizeToTray = true,
      notificationsEnabled = true,
      globalShortcutEnabled = true,
      autoUpdateEnabled = true,
      displayDensity = DesktopDisplayDensity.defaultMode,
      channelSidebarWidth = defaultChannelSidebarWidth,
      pinnedChannelIds = const [],
      inputDeviceId = '',
      outputDeviceId = '';

  final DesktopThemeMode themeMode;
  final int accentColorValue;
  final bool minimizeToTray;
  final bool notificationsEnabled;
  final bool globalShortcutEnabled;
  final bool autoUpdateEnabled;
  final DesktopDisplayDensity displayDensity;
  final double channelSidebarWidth;
  final List<String> pinnedChannelIds;
  final String inputDeviceId;
  final String outputDeviceId;

  DesktopSettings copyWith({
    DesktopThemeMode? themeMode,
    int? accentColorValue,
    bool? minimizeToTray,
    bool? notificationsEnabled,
    bool? globalShortcutEnabled,
    bool? autoUpdateEnabled,
    DesktopDisplayDensity? displayDensity,
    double? channelSidebarWidth,
    List<String>? pinnedChannelIds,
    String? inputDeviceId,
    String? outputDeviceId,
  }) {
    return DesktopSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      globalShortcutEnabled:
          globalShortcutEnabled ?? this.globalShortcutEnabled,
      autoUpdateEnabled: autoUpdateEnabled ?? this.autoUpdateEnabled,
      displayDensity: displayDensity ?? this.displayDensity,
      channelSidebarWidth: channelSidebarWidth ?? this.channelSidebarWidth,
      pinnedChannelIds: pinnedChannelIds == null
          ? this.pinnedChannelIds
          : List.unmodifiable(pinnedChannelIds),
      inputDeviceId: inputDeviceId ?? this.inputDeviceId,
      outputDeviceId: outputDeviceId ?? this.outputDeviceId,
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
        other.autoUpdateEnabled == autoUpdateEnabled &&
        other.displayDensity == displayDensity &&
        other.channelSidebarWidth == channelSidebarWidth &&
        const ListEquality<String>().equals(
          other.pinnedChannelIds,
          pinnedChannelIds,
        ) &&
        other.inputDeviceId == inputDeviceId &&
        other.outputDeviceId == outputDeviceId;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    accentColorValue,
    minimizeToTray,
    notificationsEnabled,
    globalShortcutEnabled,
    autoUpdateEnabled,
    displayDensity,
    channelSidebarWidth,
    const ListEquality<String>().hash(pinnedChannelIds),
    inputDeviceId,
    outputDeviceId,
  );
}

double normalizeChannelSidebarWidth(double value) {
  return value.clamp(
    DesktopSettings.minChannelSidebarWidth,
    DesktopSettings.maxChannelSidebarWidth,
  );
}
