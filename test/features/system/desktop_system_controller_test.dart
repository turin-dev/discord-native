import 'package:discord_native/features/system/data/desktop_settings_repository.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/system/domain/desktop_system_bridge.dart';
import 'package:discord_native/features/system/presentation/desktop_system_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopSystemController', () {
    test('저장 설정을 로드한 뒤 네이티브 브리지를 초기화한다', () async {
      const stored = DesktopSettings(
        themeMode: DesktopThemeMode.light,
        accentColorValue: 0xFF00A8FC,
        minimizeToTray: false,
        notificationsEnabled: true,
        globalShortcutEnabled: false,
        autoUpdateEnabled: false,
      );
      final repository = _MemorySettingsRepository(stored);
      final bridge = _FakeDesktopSystemBridge();
      final controller = DesktopSystemController(repository, bridge);
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.state.isInitialized, isTrue);
      expect(controller.state.settings, stored);
      expect(bridge.initializedWith, stored);
    });

    test('새 설정을 저장하고 네이티브 브리지에 적용한다', () async {
      final repository = _MemorySettingsRepository();
      final bridge = _FakeDesktopSystemBridge();
      final controller = DesktopSystemController(repository, bridge);
      addTearDown(controller.dispose);
      await controller.initialize();
      final changed = controller.state.settings.copyWith(
        themeMode: DesktopThemeMode.dark,
        notificationsEnabled: false,
      );

      await controller.updateSettings(changed);

      expect(repository.saved, changed);
      expect(bridge.appliedWith, changed);
      expect(controller.state.settings, changed);
    });

    test('알림을 끄면 네이티브 알림을 표시하지 않는다', () async {
      final repository = _MemorySettingsRepository(
        const DesktopSettings.defaults().copyWith(notificationsEnabled: false),
      );
      final bridge = _FakeDesktopSystemBridge();
      final controller = DesktopSystemController(repository, bridge);
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.showMessageNotification(title: 'alice', body: '새 메시지');

      expect(bridge.notifications, isEmpty);
    });

    test('네이티브 적용 실패를 사용자용 오류 상태로 노출한다', () async {
      final repository = _MemorySettingsRepository();
      final bridge = _FakeDesktopSystemBridge()..applyError = StateError('실패');
      final controller = DesktopSystemController(repository, bridge);
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.updateSettings(
        controller.state.settings.copyWith(minimizeToTray: false),
      );

      expect(controller.state.errorMessage, contains('데스크톱 설정'));
    });

    test('활성화된 메시지 알림과 창 복원을 브리지에 위임한다', () async {
      final repository = _MemorySettingsRepository();
      final bridge = _FakeDesktopSystemBridge();
      final controller = DesktopSystemController(repository, bridge);
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.showMessageNotification(title: 'Alice', body: '안녕');
      await controller.showWindow();

      expect(bridge.notifications.single.title, 'Alice');
      expect(bridge.notifications.single.body, '안녕');
      expect(bridge.showWindowCount, 1);
    });

    test('브리지 초기화·알림·창 복원 실패를 각각 상태로 노출한다', () async {
      final repository = _MemorySettingsRepository();
      final bridge = _FakeDesktopSystemBridge()
        ..initializeError = StateError('init');
      final controller = DesktopSystemController(repository, bridge);
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.state.errorMessage, contains('초기화'));

      bridge
        ..initializeError = null
        ..notificationError = StateError('notification');
      await controller.showMessageNotification(title: 'Alice', body: '안녕');
      expect(controller.state.errorMessage, contains('알림'));

      bridge
        ..notificationError = null
        ..showWindowError = StateError('window');
      await controller.showWindow();
      expect(controller.state.errorMessage, contains('창'));
    });

    test('dispose 이후 작업은 명시적으로 거부한다', () async {
      final controller = DesktopSystemController(
        _MemorySettingsRepository(),
        _FakeDesktopSystemBridge(),
      );
      await controller.dispose();

      expect(controller.initialize, throwsStateError);
    });
  });
}

final class _MemorySettingsRepository implements DesktopSettingsRepository {
  _MemorySettingsRepository([this.saved = const DesktopSettings.defaults()]);

  DesktopSettings saved;

  @override
  Future<DesktopSettings> load() async => saved;

  @override
  Future<void> save(DesktopSettings settings) async {
    saved = settings;
  }
}

final class _FakeDesktopSystemBridge implements DesktopSystemBridge {
  DesktopSettings? initializedWith;
  DesktopSettings? appliedWith;
  Object? applyError;
  Object? initializeError;
  Object? notificationError;
  Object? showWindowError;
  int showWindowCount = 0;
  final List<DesktopNotification> notifications = [];

  @override
  Future<void> apply(DesktopSettings settings) async {
    final error = applyError;
    if (error != null) {
      throw error;
    }
    appliedWith = settings;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize(DesktopSettings settings) async {
    final error = initializeError;
    if (error != null) {
      throw error;
    }
    initializedWith = settings;
  }

  @override
  Future<void> showNotification(DesktopNotification notification) async {
    final error = notificationError;
    if (error != null) {
      throw error;
    }
    notifications.add(notification);
  }

  @override
  Future<void> showWindow() async {
    final error = showWindowError;
    if (error != null) {
      throw error;
    }
    showWindowCount += 1;
  }
}
