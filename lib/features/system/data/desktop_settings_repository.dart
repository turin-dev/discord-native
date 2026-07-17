import 'dart:convert';

import 'package:discord_native/core/auth/secure_token_repository.dart';
import 'package:discord_native/features/system/domain/desktop_push_to_talk.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';

abstract interface class DesktopSettingsStorage {
  Future<String?> read();

  Future<void> write(String value);
}

abstract interface class DesktopSettingsRepository {
  Future<DesktopSettings> load();

  Future<void> save(DesktopSettings settings);
}

final class SecureDesktopSettingsStorage implements DesktopSettingsStorage {
  const SecureDesktopSettingsStorage(this._storage);

  static const _key = 'discord_desktop_settings';

  final SecretStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

final class JsonDesktopSettingsRepository implements DesktopSettingsRepository {
  const JsonDesktopSettingsRepository(this._storage);

  final DesktopSettingsStorage _storage;

  @override
  Future<DesktopSettings> load() async {
    final encoded = await _storage.read();
    if (encoded == null || encoded.isEmpty) {
      return const DesktopSettings.defaults();
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return const DesktopSettings.defaults();
      }
      return _fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on FormatException {
      return const DesktopSettings.defaults();
    }
  }

  @override
  Future<void> save(DesktopSettings settings) {
    return _storage.write(jsonEncode(_toJson(settings)));
  }
}

DesktopSettings _fromJson(Map<String, Object?> json) {
  const defaults = DesktopSettings.defaults();
  final accent = json['accentColorValue'];
  return DesktopSettings(
    themeMode: DesktopThemeMode.values.firstWhere(
      (value) => value.name == json['themeMode'],
      orElse: () => DesktopThemeMode.system,
    ),
    accentColorValue: accent is int && accent >= 0xFF000000
        ? accent
        : defaults.accentColorValue,
    minimizeToTray: _boolean(json['minimizeToTray'], defaults.minimizeToTray),
    notificationsEnabled: _boolean(
      json['notificationsEnabled'],
      defaults.notificationsEnabled,
    ),
    globalShortcutEnabled: _boolean(
      json['globalShortcutEnabled'],
      defaults.globalShortcutEnabled,
    ),
    autoUpdateEnabled: _boolean(
      json['autoUpdateEnabled'],
      defaults.autoUpdateEnabled,
    ),
    displayDensity: DesktopDisplayDensity.values.firstWhere(
      (value) => value.name == json['displayDensity'],
      orElse: () => DesktopDisplayDensity.defaultMode,
    ),
    channelSidebarWidth: normalizeChannelSidebarWidth(
      _number(json['channelSidebarWidth']) ?? defaults.channelSidebarWidth,
    ),
    pinnedChannelIds: List.unmodifiable(
      _readStrings(json['pinnedChannelIds']).toSet(),
    ),
    inputDeviceId: _string(json['inputDeviceId']),
    outputDeviceId: _string(json['outputDeviceId']),
    globalPushToTalkEnabled: _boolean(
      json['globalPushToTalkEnabled'],
      defaults.globalPushToTalkEnabled,
    ),
    pushToTalkKey: DesktopPushToTalkKey.values.firstWhere(
      (value) => value.name == json['pushToTalkKey'],
      orElse: () => DesktopPushToTalkKey.f8,
    ),
    pushToTalkReleaseDelayMs: normalizePushToTalkReleaseDelay(
      _integer(json['pushToTalkReleaseDelayMs']) ??
          defaults.pushToTalkReleaseDelayMs,
    ),
  );
}

Map<String, Object> _toJson(DesktopSettings settings) {
  return {
    'themeMode': settings.themeMode.name,
    'accentColorValue': settings.accentColorValue,
    'minimizeToTray': settings.minimizeToTray,
    'notificationsEnabled': settings.notificationsEnabled,
    'globalShortcutEnabled': settings.globalShortcutEnabled,
    'autoUpdateEnabled': settings.autoUpdateEnabled,
    'displayDensity': settings.displayDensity.name,
    'channelSidebarWidth': normalizeChannelSidebarWidth(
      settings.channelSidebarWidth,
    ),
    'pinnedChannelIds': settings.pinnedChannelIds,
    'inputDeviceId': settings.inputDeviceId,
    'outputDeviceId': settings.outputDeviceId,
    'globalPushToTalkEnabled': settings.globalPushToTalkEnabled,
    'pushToTalkKey': settings.pushToTalkKey.name,
    'pushToTalkReleaseDelayMs': normalizePushToTalkReleaseDelay(
      settings.pushToTalkReleaseDelayMs,
    ),
  };
}

bool _boolean(Object? value, bool fallback) {
  return value is bool ? value : fallback;
}

double? _number(Object? value) {
  return value is num ? value.toDouble() : null;
}

int? _integer(Object? value) {
  return value is int ? value : null;
}

Iterable<String> _readStrings(Object? value) sync* {
  if (value is! List) {
    return;
  }
  for (final item in value) {
    if (item is String && item.isNotEmpty) {
      yield item;
    }
  }
}

String _string(Object? value) {
  return value is String ? value : '';
}
