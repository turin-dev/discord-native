import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/presentation/message_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('video attachment는 주입된 player와 파일 정보를 함께 표시한다', (tester) async {
    const attachment = DiscordAttachment(
      id: 'video-1',
      filename: 'demo.mp4',
      url: 'https://cdn.discordapp.com/attachments/demo.mp4',
      proxyUrl: 'https://media.discordapp.net/attachments/demo.mp4',
      size: 2 * 1024 * 1024,
      contentType: 'video/mp4',
      width: 1280,
      height: 720,
    );
    DiscordAttachment? renderedAttachment;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageAttachmentCard(
            attachment: attachment,
            onDownload: null,
            videoBuilder: (value) {
              renderedAttachment = value;
              return const SizedBox(
                key: ValueKey('fake-video-player'),
                width: 420,
                height: 236,
              );
            },
          ),
        ),
      ),
    );

    expect(attachment.isVideo, isTrue);
    expect(renderedAttachment, same(attachment));
    expect(find.byKey(const ValueKey('fake-video-player')), findsOneWidget);
    expect(find.text('demo.mp4'), findsOneWidget);
    expect(find.text('2.0 MB'), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });
}
