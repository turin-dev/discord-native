import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_permissions.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/discord_workspace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('composer에서 standard·custom emoji를 삽입하고 sticker를 전송한다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? sentStickerId;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: [
        DiscordGuild(
          id: 'guild-1',
          name: '개발 서버',
          roles: [
            DiscordRole(
              id: 'guild-1',
              name: '@everyone',
              position: 0,
              permissions:
                  DiscordPermissions.viewChannel |
                  DiscordPermissions.sendMessages,
            ),
          ],
          emojis: const [
            DiscordGuildEmoji(id: 'emoji-1', name: 'party', animated: true),
          ],
          stickers: const [
            DiscordGuildSticker(id: 'sticker-1', name: 'Wumpus', formatType: 1),
          ],
        ),
      ],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
      currentUser: const DiscordUser(id: 'user-1', username: 'alice'),
    );
    final peopleState = const DiscordPeopleState().payloadReceived({
      'op': 0,
      't': 'GUILD_CREATE',
      'd': {
        'id': 'guild-1',
        'members': [
          {
            'roles': [],
            'user': {'id': 'user-1', 'username': 'alice'},
          },
        ],
        'presences': [],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          peopleState: peopleState,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onSendMessage: (_) async {},
          onSendSticker: (stickerId) async {
            sentStickerId = stickerId;
          },
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('이모지·스티커'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('standard-emoji-😀')));
    await tester.pumpAndSettle();

    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('message-composer-field')),
    );
    expect(composer.controller?.text, '😀');

    await tester.tap(find.byTooltip('이모지·스티커'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guild-emoji-emoji-1')));
    await tester.pumpAndSettle();

    expect(composer.controller?.text, '😀<a:party:emoji-1>');

    await tester.tap(find.byTooltip('이모지·스티커'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('스티커'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guild-sticker-sticker-1')));
    await tester.pumpAndSettle();

    expect(sentStickerId, 'sticker-1');
  });
}
