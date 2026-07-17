import 'package:discord_native/core/auth/discord_account_repository.dart';
import 'package:discord_native/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('위험 고지와 토큰 입력 폼을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(onConnect: (_) async {})),
    );

    expect(find.text('계정 정지 위험'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('연결'), findsOneWidget);
  });

  testWidgets('공백을 제거한 토큰을 제출한다', (tester) async {
    String? submittedToken;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onConnect: (token) async {
            submittedToken = token;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '  abc.def.ghi  ');
    await tester.tap(find.text('연결'));
    await tester.pump();

    expect(submittedToken, 'abc.def.ghi');
  });

  testWidgets('잘못된 토큰은 사용자 친화적 오류를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(onConnect: (_) async {})),
    );

    await tester.enterText(find.byType(TextField), 'abc def');
    await tester.tap(find.text('연결'));
    await tester.pump();

    expect(find.text('토큰에는 공백을 포함할 수 없습니다.'), findsOneWidget);
  });

  testWidgets('저장 계정을 토큰 없이 빠르게 선택한다', (tester) async {
    String? selectedAccountId;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onConnect: (_) async {},
          savedAccounts: const [
            SavedDiscordAccount(
              id: 'user-1',
              username: 'alice',
              displayName: 'Alice',
            ),
          ],
          onSelectAccount: (accountId) async {
            selectedAccountId = accountId;
          },
        ),
      ),
    );

    await tester.tap(find.text('Alice'));
    await tester.pump();

    expect(selectedAccountId, 'user-1');
  });
}
