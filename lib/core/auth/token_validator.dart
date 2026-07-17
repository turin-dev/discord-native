final class InvalidTokenException implements Exception {
  const InvalidTokenException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class TokenValidator {
  static String validate(String input) {
    final token = input.trim();
    if (token.isEmpty) {
      throw const InvalidTokenException('Discord 토큰을 입력해 주세요.');
    }
    if (RegExp(r'\s').hasMatch(token)) {
      throw const InvalidTokenException('토큰에는 공백을 포함할 수 없습니다.');
    }
    return token;
  }
}
