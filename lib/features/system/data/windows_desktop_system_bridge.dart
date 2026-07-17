// coverage:ignore-file

import 'dart:async';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/system/domain/desktop_system_bridge.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

final class WindowsDesktopSystemBridge
    with WindowListener, TrayListener
    implements DesktopSystemBridge {
  WindowsDesktopSystemBridge({
    this.updateFeedUrl = const String.fromEnvironment(
      'DISCORD_NATIVE_UPDATE_FEED',
    ),
  });

  static final _logger = Logger('WindowsDesktopSystemBridge');
  static const _appName = 'Discord Native';
  static const _updateIntervalSeconds = 86400;

  final String updateFeedUrl;
  DesktopSettings _settings = const DesktopSettings.defaults();
  bool _initialized = false;
  bool _quitting = false;

  @override
  Future<void> initialize(DesktopSettings settings) async {
    if (_initialized) {
      await apply(settings);
      return;
    }
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    trayManager.addListener(this);
    await localNotifier.setup(
      appName: _appName,
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
    await _initializeTray();
    _initialized = true;
    await apply(settings);
  }

  @override
  Future<void> apply(DesktopSettings settings) async {
    _settings = settings;
    await windowManager.setPreventClose(settings.minimizeToTray);
    await _configureHotKey(settings.globalShortcutEnabled);
    await _configureUpdater(settings.autoUpdateEnabled);
  }

  @override
  Future<void> showNotification(DesktopNotification notification) async {
    final localNotification = LocalNotification(
      title: notification.title,
      body: notification.body,
      silent: false,
    );
    localNotification.onClick = () => _runGuarded(showWindow);
    await localNotification.show();
  }

  @override
  Future<void> showWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> dispose() async {
    if (!_initialized) {
      return;
    }
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    await hotKeyManager.unregisterAll();
    await trayManager.destroy();
    _initialized = false;
  }

  @override
  void onWindowClose() {
    if (!_settings.minimizeToTray || _quitting) {
      return;
    }
    _runGuarded(() async {
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
    });
  }

  @override
  void onTrayIconMouseDown() {
    _runGuarded(showWindow);
  }

  Future<void> _initializeTray() async {
    await trayManager.setIcon(_trayIconPath());
    await trayManager.setToolTip(_appName);
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Discord Native 열기',
            onClick: (_) => _runGuarded(showWindow),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: '종료',
            onClick: (_) => _runGuarded(_exitApp),
          ),
        ],
      ),
    );
  }

  Future<void> _configureHotKey(bool enabled) async {
    await hotKeyManager.unregisterAll();
    if (!enabled) {
      return;
    }
    final hotKey = HotKey(
      identifier: 'discord_native_show_window',
      key: PhysicalKeyboardKey.keyD,
      modifiers: const [HotKeyModifier.control, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) => _runGuarded(showWindow),
    );
  }

  Future<void> _configureUpdater(bool enabled) async {
    if (!enabled || updateFeedUrl.isEmpty) {
      await autoUpdater.setScheduledCheckInterval(0);
      return;
    }
    final uri = Uri.tryParse(updateFeedUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException(
        'DISCORD_NATIVE_UPDATE_FEED는 HTTPS URL이어야 합니다.',
      );
    }
    await autoUpdater.setFeedURL(updateFeedUrl);
    await autoUpdater.setScheduledCheckInterval(_updateIntervalSeconds);
    await autoUpdater.checkForUpdates(inBackground: true);
  }

  Future<void> _exitApp() async {
    _quitting = true;
    await windowManager.setPreventClose(false);
    await trayManager.destroy();
    await windowManager.destroy();
  }

  String _trayIconPath() {
    final executableDirectory = path.dirname(Platform.resolvedExecutable);
    return path.join(
      executableDirectory,
      'data',
      'flutter_assets',
      'windows',
      'runner',
      'resources',
      'app_icon.ico',
    );
  }

  void _runGuarded(Future<void> Function() operation) {
    unawaited(
      operation().onError((error, stackTrace) {
        _logger.severe('Windows 시스템 작업에 실패했습니다.', error, stackTrace);
      }),
    );
  }
}
