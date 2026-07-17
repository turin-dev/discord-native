import '../../tool/release_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLcovCoverage', () {
    test('여러 source record의 line coverage를 합산한다', () {
      const lcov = '''
SF:lib/a.dart
LF:3
LH:2
end_of_record
SF:lib/b.dart
LF:2
LH:2
end_of_record
''';

      final coverage = parseLcovCoverage(lcov);

      expect(coverage.hitLines, 4);
      expect(coverage.foundLines, 5);
      expect(coverage.percent, 80);
      expect(coverage.meets(80), isTrue);
      expect(coverage.meets(80.01), isFalse);
    });

    test('line summary가 없거나 전체 line이 0이면 거부한다', () {
      expect(() => parseLcovCoverage(''), throwsFormatException);
      expect(() => parseLcovCoverage('LF:0\nLH:0\n'), throwsFormatException);
    });
  });

  group('renderWindowsAppcast', () {
    test('서명된 HTTPS Windows enclosure를 생성한다', () {
      final xml = renderWindowsAppcast(
        WindowsAppcastEntry(
          version: '1.2.3+7',
          downloadUrl: Uri.parse(
            'https://updates.example.com/discord-native-1.2.3.exe',
          ),
          dsaSignature: 'signed-value',
          length: 1234,
          publishedAt: DateTime.utc(2026, 7, 17, 12),
          releaseNotesUrl: Uri.parse(
            'https://updates.example.com/notes?channel=stable&lang=ko',
          ),
        ),
      );

      expect(xml, contains('sparkle:dsaSignature="signed-value"'));
      expect(xml, contains('sparkle:version="1.2.3+7"'));
      expect(xml, contains('length="1234"'));
      expect(xml, contains('sparkle:os="windows"'));
      expect(xml, contains('channel=stable&amp;lang=ko'));
      expect(xml, contains('Fri, 17 Jul 2026 12:00:00 GMT'));
    });

    test('비 HTTPS URL과 빈 서명을 거부한다', () {
      expect(
        () => WindowsAppcastEntry(
          version: '1.0.0',
          downloadUrl: Uri.parse('http://updates.example.com/setup.exe'),
          dsaSignature: 'signature',
          length: 1,
          publishedAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
      expect(
        () => WindowsAppcastEntry(
          version: '1.0.0',
          downloadUrl: Uri.parse('https://updates.example.com/setup.exe'),
          dsaSignature: '',
          length: 1,
          publishedAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
    });
  });
}
