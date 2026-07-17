import 'package:discord_native/features/system/data/desktop_settings_repository.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopSettings', () {
    test('기본값은 시스템 테마와 안전한 데스크톱 동작을 사용한다', () {
      const settings = DesktopSettings.defaults();

      expect(settings.themeMode, DesktopThemeMode.system);
      expect(settings.accentColorValue, 0xFF5865F2);
      expect(settings.minimizeToTray, isTrue);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.globalShortcutEnabled, isTrue);
      expect(settings.autoUpdateEnabled, isTrue);
    });

    test('copyWith는 원본을 변경하지 않고 새 설정을 만든다', () {
      const original = DesktopSettings.defaults();

      final changed = original.copyWith(
        themeMode: DesktopThemeMode.light,
        accentColorValue: 0xFF00A8FC,
        minimizeToTray: false,
      );

      expect(original, const DesktopSettings.defaults());
      expect(changed.themeMode, DesktopThemeMode.light);
      expect(changed.accentColorValue, 0xFF00A8FC);
      expect(changed.minimizeToTray, isFalse);
    });
  });

  group('JsonDesktopSettingsRepository', () {
    test('저장된 JSON을 다시 불러온다', () async {
      final storage = _MemorySettingsStorage();
      final repository = JsonDesktopSettingsRepository(storage);
      const settings = DesktopSettings(
        themeMode: DesktopThemeMode.dark,
        accentColorValue: 0xFFEB459E,
        minimizeToTray: false,
        notificationsEnabled: false,
        globalShortcutEnabled: true,
        autoUpdateEnabled: false,
      );

      await repository.save(settings);

      expect(await repository.load(), settings);
    });

    test('손상된 저장값은 기본값으로 복구한다', () async {
      final storage = _MemorySettingsStorage('{not-json');
      final repository = JsonDesktopSettingsRepository(storage);

      expect(await repository.load(), const DesktopSettings.defaults());
    });

    test('알 수 없는 필드와 테마 값은 안전하게 기본값을 사용한다', () async {
      final storage = _MemorySettingsStorage(
        '{"themeMode":"future","accentColorValue":3,"extra":true}',
      );
      final repository = JsonDesktopSettingsRepository(storage);

      final settings = await repository.load();

      expect(settings.themeMode, DesktopThemeMode.system);
      expect(settings.accentColorValue, 0xFF5865F2);
    });
  });
}

final class _MemorySettingsStorage implements DesktopSettingsStorage {
  _MemorySettingsStorage([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
