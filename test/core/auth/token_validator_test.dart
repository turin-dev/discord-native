import 'package:discord_native/core/auth/token_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TokenValidator', () {
    test('앞뒤 공백을 제거한 토큰을 반환한다', () {
      expect(TokenValidator.validate('  abc.def.ghi  '), 'abc.def.ghi');
    });

    test('빈 토큰은 명확한 오류로 거부한다', () {
      expect(
        () => TokenValidator.validate('   '),
        throwsA(
          isA<InvalidTokenException>().having(
            (error) => error.message,
            'message',
            'Discord 토큰을 입력해 주세요.',
          ),
        ),
      );
    });

    test('토큰 내부 공백을 거부한다', () {
      expect(
        () => TokenValidator.validate('abc def'),
        throwsA(isA<InvalidTokenException>()),
      );
    });
  });
}
