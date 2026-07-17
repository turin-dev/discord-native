import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_dave_controller.dart';
import 'package:discord_native/features/voice/data/discord_dave_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordDaveController', () {
    late _FakeDiscordDaveSession session;
    late List<(int, Map<String, Object?>)> sentJson;
    late List<(int, Uint8List)> sentBinary;
    late DiscordDaveController controller;

    setUp(() {
      session = _FakeDiscordDaveSession();
      sentJson = const [];
      sentBinary = const [];
      controller = DiscordDaveController(
        session: session,
        sendJson: (opcode, data) async {
          sentJson = List.unmodifiable([...sentJson, (opcode, data)]);
        },
        sendBinary: (opcode, payload) async {
          sentBinary = List.unmodifiable([
            ...sentBinary,
            (opcode, Uint8List.fromList(payload)),
          ]);
        },
      );
    });

    test('DAVE v1 session을 초기화하고 opcode 26 key package를 보낸다', () async {
      await controller.initialize(
        protocolVersion: 1,
        groupId: 123,
        selfUserId: '456',
      );

      expect(session.initializations, [(1, 123, '456')]);
      expect(sentBinary.single.$1, 26);
      expect(sentBinary.single.$2, [1, 2, 3]);
      expect(controller.protocolVersion, 1);
    });

    test('초기 Session Description보다 먼저 온 external sender를 보존한다', () async {
      await controller.handleBinary(25, Uint8List.fromList([4, 5]));

      expect(session.externalSender, isNull);

      await controller.initialize(
        protocolVersion: 1,
        groupId: 123,
        selfUserId: '456',
      );

      expect(session.externalSender, [4, 5]);
    });

    test('초기 Session Description보다 먼저 온 참가자 목록을 보존한다', () async {
      await controller.handleJson(11, {
        'user_ids': ['7', '8'],
      });
      await controller.handleJson(13, {'user_id': '8'});

      await controller.initialize(
        protocolVersion: 1,
        groupId: 123,
        selfUserId: '456',
      );
      await controller.handleBinary(27, Uint8List.fromList([0, 6, 7]));

      expect(controller.connectedUserIds, {'7'});
      expect(session.recognizedUserIds, {'7'});
    });

    test('연결 참가자를 추적해 external sender와 proposals를 처리한다', () async {
      await controller.initialize(
        protocolVersion: 1,
        groupId: 123,
        selfUserId: '456',
      );
      await controller.handleJson(11, {
        'user_ids': ['7', '8'],
      });
      await controller.handleJson(13, {'user_id': '8'});
      await controller.handleBinary(25, Uint8List.fromList([4, 5]));
      await controller.handleBinary(27, Uint8List.fromList([0, 6, 7]));

      expect(session.externalSender, [4, 5]);
      expect(session.proposals, [0, 6, 7]);
      expect(session.recognizedUserIds, {'7'});
      expect(sentBinary.last.$1, 28);
      expect(sentBinary.last.$2, [9, 10]);
    });

    test('commit과 welcome을 적용하고 transition ready를 보낸다', () async {
      await controller.initialize(
        protocolVersion: 1,
        groupId: 123,
        selfUserId: '456',
      );

      await controller.handleBinary(29, Uint8List.fromList([0, 7, 11, 12]));
      await controller.handleBinary(30, Uint8List.fromList([0, 8, 13, 14]));

      expect(session.commits, [
        [11, 12],
      ]);
      expect(session.welcomes, [
        [13, 14],
      ]);
      expect(sentJson.map((message) => message.$1), [23, 23]);
      expect(sentJson.map((message) => message.$2), [
        {'transition_id': 7},
        {'transition_id': 8},
      ]);
    });

    test('잘못된 commit은 opcode 31과 새 key package로 복구한다', () async {
      session.commitResult = DiscordDaveGroupUpdate.failed;
      await controller.initialize(
        protocolVersion: 1,
        groupId: 123,
        selfUserId: '456',
      );
      sentBinary = const [];

      await controller.handleBinary(29, Uint8List.fromList([0, 9, 15]));

      expect(sentJson.single.$1, 31);
      expect(sentJson.single.$2, {'transition_id': 9});
      expect(session.initializations, [(1, 123, '456'), (1, 123, '456')]);
      expect(sentBinary.single.$1, 26);
      expect(sentBinary.single.$2, [1, 2, 3]);
    });

    test('prepare와 execute transition의 protocol version을 원자적으로 전환한다', () async {
      await controller.initialize(
        protocolVersion: 1,
        groupId: 123,
        selfUserId: '456',
      );

      await controller.handleJson(21, {
        'transition_id': 10,
        'protocol_version': 0,
      });
      expect(sentJson.last.$1, 23);
      expect(sentJson.last.$2, {'transition_id': 10});
      expect(session.passthroughEnabled, isTrue);
      expect(controller.protocolVersion, 1);

      await controller.handleJson(22, {'transition_id': 10});
      expect(controller.protocolVersion, 0);
    });
  });
}

final class _FakeDiscordDaveSession implements DiscordDaveSession {
  @override
  int get maxSupportedProtocolVersion => 1;

  @override
  int protocolVersion = 0;

  List<(int, int, String)> initializations = const [];
  Uint8List? externalSender;
  Uint8List? proposals;
  Set<String> recognizedUserIds = const {};
  List<Uint8List> commits = const [];
  List<Uint8List> welcomes = const [];
  DiscordDaveGroupUpdate commitResult = DiscordDaveGroupUpdate.applied;
  DiscordDaveGroupUpdate welcomeResult = DiscordDaveGroupUpdate.applied;
  bool passthroughEnabled = false;

  @override
  void initialize({
    required int protocolVersion,
    required int groupId,
    required String selfUserId,
  }) {
    this.protocolVersion = protocolVersion;
    initializations = List.unmodifiable([
      ...initializations,
      (protocolVersion, groupId, selfUserId),
    ]);
  }

  @override
  Uint8List createKeyPackage() => Uint8List.fromList([1, 2, 3]);

  @override
  void setExternalSender(Uint8List payload) {
    externalSender = Uint8List.fromList(payload);
  }

  @override
  Uint8List? processProposals(
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  }) {
    proposals = Uint8List.fromList(payload);
    this.recognizedUserIds = Set.unmodifiable(recognizedUserIds);
    return Uint8List.fromList([9, 10]);
  }

  @override
  DiscordDaveGroupUpdate processCommit(Uint8List payload) {
    commits = List.unmodifiable([...commits, Uint8List.fromList(payload)]);
    return commitResult;
  }

  @override
  DiscordDaveGroupUpdate processWelcome(
    Uint8List payload, {
    required Set<String> recognizedUserIds,
  }) {
    welcomes = List.unmodifiable([...welcomes, Uint8List.fromList(payload)]);
    this.recognizedUserIds = Set.unmodifiable(recognizedUserIds);
    return welcomeResult;
  }

  @override
  void setPassthroughMode({
    required bool enabled,
    required Iterable<String> remoteUserIds,
  }) {
    passthroughEnabled = enabled;
  }

  @override
  void assignLocalAudioSsrc(int ssrc) {}

  @override
  void assignLocalVideoSsrc(int ssrc, {required DiscordDaveVideoCodec codec}) {}

  @override
  Uint8List decryptAudio(Uint8List frame, {required String remoteUserId}) =>
      Uint8List.fromList(frame);

  @override
  Uint8List decryptVideo(Uint8List frame, {required String remoteUserId}) =>
      Uint8List.fromList(frame);

  @override
  Uint8List encryptAudio(Uint8List frame, {required int ssrc}) {
    return Uint8List.fromList(frame);
  }

  @override
  Uint8List encryptVideo(Uint8List frame, {required int ssrc}) {
    return Uint8List.fromList(frame);
  }

  @override
  void close() {}
}
