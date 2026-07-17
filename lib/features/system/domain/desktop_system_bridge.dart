import 'package:discord_native/features/system/domain/desktop_settings.dart';

final class DesktopNotification {
  const DesktopNotification({required this.title, required this.body});

  final String title;
  final String body;
}

abstract interface class DesktopSystemBridge {
  Stream<bool> get pushToTalkPressed;

  Future<void> setPushToTalkSessionActive(bool active);

  Future<void> initialize(DesktopSettings settings);

  Future<void> apply(DesktopSettings settings);

  Future<void> showNotification(DesktopNotification notification);

  Future<void> showWindow();

  Future<void> dispose();
}

final class NoopDesktopSystemBridge implements DesktopSystemBridge {
  const NoopDesktopSystemBridge();

  @override
  Stream<bool> get pushToTalkPressed => const Stream.empty();

  @override
  Future<void> setPushToTalkSessionActive(bool active) async {}

  @override
  Future<void> apply(DesktopSettings settings) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize(DesktopSettings settings) async {}

  @override
  Future<void> showNotification(DesktopNotification notification) async {}

  @override
  Future<void> showWindow() async {}
}
