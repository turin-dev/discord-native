import 'package:discord_native/features/workspace/domain/workspace_navigation_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('뒤로와 앞으로 이동해도 방문 순서를 보존한다', () {
    const first = DiscordWorkspaceLocation('guild-1', 'channel-1');
    const second = DiscordWorkspaceLocation('guild-1', 'channel-2');
    const third = DiscordWorkspaceLocation('guild-2', 'channel-3');

    final history = const DiscordNavigationHistory()
        .visit(first)
        .visit(second)
        .visit(third);
    final backed = history.back();

    expect(backed.current, second);
    expect(backed.canGoBack, isTrue);
    expect(backed.canGoForward, isTrue);
    expect(backed.forward().current, third);
  });

  test('뒤로 이동한 뒤 새 위치를 열면 앞으로 기록을 버린다', () {
    const first = DiscordWorkspaceLocation('guild-1', 'channel-1');
    const second = DiscordWorkspaceLocation('guild-1', 'channel-2');
    const replacement = DiscordWorkspaceLocation('guild-3', 'channel-4');

    final history = const DiscordNavigationHistory()
        .visit(first)
        .visit(second)
        .back()
        .visit(replacement);

    expect(history.current, replacement);
    expect(history.canGoForward, isFalse);
    expect(history.entries, [first, replacement]);
  });

  test('현재 위치 재방문과 빈 위치는 기록하지 않는다', () {
    const location = DiscordWorkspaceLocation('guild-1', 'channel-1');
    final history = const DiscordNavigationHistory()
        .visit(const DiscordWorkspaceLocation(null, null))
        .visit(location)
        .visit(location);

    expect(history.entries, [location]);
  });
}
