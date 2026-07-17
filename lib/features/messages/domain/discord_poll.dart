part of 'discord_message_state.dart';

final class DiscordPollDraft {
  const DiscordPollDraft({
    required this.question,
    required this.answers,
    required this.durationHours,
    required this.allowMultiselect,
  });

  final String question;
  final List<String> answers;
  final int durationHours;
  final bool allowMultiselect;
}

final class DiscordPollAnswer {
  const DiscordPollAnswer({
    required this.id,
    required this.text,
    required this.voteCount,
    required this.meVoted,
    this.emojiName,
    this.emojiId,
  });

  final int id;
  final String text;
  final int voteCount;
  final bool meVoted;
  final String? emojiName;
  final String? emojiId;

  DiscordPollAnswer copyWith({int? voteCount, bool? meVoted}) {
    return DiscordPollAnswer(
      id: id,
      text: text,
      voteCount: voteCount ?? this.voteCount,
      meVoted: meVoted ?? this.meVoted,
      emojiName: emojiName,
      emojiId: emojiId,
    );
  }
}

final class DiscordPoll {
  const DiscordPoll({
    required this.question,
    required this.answers,
    required this.allowMultiselect,
    required this.finalized,
    this.expiry,
  });

  factory DiscordPoll.fromJson(Map<String, Object?> json) {
    final question = _readMap(json['question'], 'poll.question');
    final results = _optionalMap(json['results']);
    final counts = Map<int, Map<String, Object?>>.fromEntries(
      _readList(results?['answer_counts']).map(_readPollCountEntry).nonNulls,
    );
    return DiscordPoll(
      question: _requiredString(question['text'], 'poll.question.text'),
      answers: List.unmodifiable([
        for (final item in _readList(json['answers']))
          _readPollAnswer(_readMap(item, 'poll.answer'), counts),
      ]),
      allowMultiselect: json['allow_multiselect'] == true,
      finalized: results?['is_finalized'] == true,
      expiry: _optionalDate(json['expiry']),
    );
  }

  final String question;
  final List<DiscordPollAnswer> answers;
  final bool allowMultiselect;
  final bool finalized;
  final DateTime? expiry;

  int get totalVotes =>
      answers.fold(0, (total, answer) => total + answer.voteCount);

  DiscordPoll applySelection(Set<int> answerIds) {
    final validIds = {
      for (final answer in answers)
        if (answerIds.contains(answer.id)) answer.id,
    };
    return _copyWithAnswers([
      for (final answer in answers)
        _applyOwnVote(answer, validIds.contains(answer.id)),
    ]);
  }

  DiscordPoll applyVoteEvent(
    int answerId, {
    required bool voted,
    required bool isCurrentUser,
  }) {
    return _copyWithAnswers([
      for (final answer in answers)
        if (answer.id == answerId)
          _applyVoteEvent(answer, voted, isCurrentUser)
        else
          answer,
    ]);
  }

  DiscordPoll _copyWithAnswers(List<DiscordPollAnswer> nextAnswers) {
    return DiscordPoll(
      question: question,
      answers: List.unmodifiable(nextAnswers),
      allowMultiselect: allowMultiselect,
      finalized: finalized,
      expiry: expiry,
    );
  }
}

DiscordPollAnswer _applyOwnVote(DiscordPollAnswer answer, bool voted) {
  if (answer.meVoted == voted) {
    return answer;
  }
  final nextCount = answer.voteCount + (voted ? 1 : -1);
  return answer.copyWith(
    voteCount: nextCount < 0 ? 0 : nextCount,
    meVoted: voted,
  );
}

DiscordPollAnswer _applyVoteEvent(
  DiscordPollAnswer answer,
  bool voted,
  bool isCurrentUser,
) {
  if (isCurrentUser) {
    return _applyOwnVote(answer, voted);
  }
  final nextCount = answer.voteCount + (voted ? 1 : -1);
  return answer.copyWith(voteCount: nextCount < 0 ? 0 : nextCount);
}

MapEntry<int, Map<String, Object?>>? _readPollCountEntry(Object? value) {
  final count = _optionalMap(value);
  final id = _optionalInt(count?['id']);
  return count == null || id == null ? null : MapEntry(id, count);
}

DiscordPollAnswer _readPollAnswer(
  Map<String, Object?> json,
  Map<int, Map<String, Object?>> counts,
) {
  final id = _requiredInt(json['answer_id'], 'poll.answer.id');
  final media = _readMap(json['poll_media'], 'poll.answer.media');
  final emoji = _optionalMap(media['emoji']);
  final count = counts[id];
  return DiscordPollAnswer(
    id: id,
    text: _requiredString(media['text'], 'poll.answer.text'),
    voteCount: _optionalInt(count?['count']) ?? 0,
    meVoted: count?['me_voted'] == true,
    emojiName: _optionalString(emoji?['name']),
    emojiId: _optionalString(emoji?['id']),
  );
}

DiscordPoll? _optionalPoll(Object? value) {
  final json = _optionalMap(value);
  return json == null ? null : DiscordPoll.fromJson(json);
}
