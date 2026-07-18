import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/messages/domain/discord_pinned_messages_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pin 페이지를 불변 목록으로 병합하고 message ID 중복을 제거한다', () {
    final first = _pin('message-1', DateTime.utc(2026, 7, 18, 11));
    final duplicate = _pin('message-1', DateTime.utc(2026, 7, 18, 10));
    final second = _pin('message-2', DateTime.utc(2026, 7, 18, 9));
    final state = DiscordPinnedMessagesState.loaded(
      channelId: 'channel-1',
      pins: [first],
      hasMore: true,
    );

    final loading = state.loadingMore();
    final appended = loading.appendPage(
      DiscordMessagePinsPage(pins: [duplicate, second], hasMore: false),
    );

    expect(loading.isLoadingMore, isTrue);
    expect(appended.pins.map((pin) => pin.message.id), [
      'message-1',
      'message-2',
    ]);
    expect(appended.hasMore, isFalse);
    expect(appended.isLoadingMore, isFalse);
    expect(() => appended.pins.add(second), throwsUnsupportedError);
  });

  test('실패는 기존 pin을 보존하고 다시 시도 가능한 오류를 노출한다', () {
    final pin = _pin('message-1', DateTime.utc(2026, 7, 18, 11));
    final state = DiscordPinnedMessagesState.loaded(
      channelId: 'channel-1',
      pins: [pin],
      hasMore: true,
    );

    final failed = state.loadingMore().failed('고정 메시지를 불러오지 못했습니다.');

    expect(failed.pins, [pin]);
    expect(failed.isLoading, isFalse);
    expect(failed.isLoadingMore, isFalse);
    expect(failed.errorMessage, '고정 메시지를 불러오지 못했습니다.');
  });
}

DiscordMessagePin _pin(String id, DateTime pinnedAt) {
  return DiscordMessagePin(
    pinnedAt: pinnedAt,
    message: DiscordMessage(
      id: id,
      channelId: 'channel-1',
      content: id,
      authorId: 'user-1',
      authorName: 'alice',
      timestamp: DateTime.utc(2026, 7, 18, 8),
      pinned: true,
    ),
  );
}
