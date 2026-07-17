import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:flutter/material.dart';

Future<DiscordPollDraft?> showPollComposerDialog(BuildContext context) {
  return showDialog<DiscordPollDraft>(
    context: context,
    builder: (_) => const PollComposerDialog(),
  );
}

class PollComposerDialog extends StatefulWidget {
  const PollComposerDialog({super.key});

  @override
  State<PollComposerDialog> createState() => _PollComposerDialogState();
}

class _PollComposerDialogState extends State<PollComposerDialog> {
  final TextEditingController _question = TextEditingController();
  List<TextEditingController> _answers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _durationHours = 24;
  bool _allowMultiselect = false;
  String? _errorMessage;

  @override
  void dispose() {
    _question.dispose();
    for (final answer in _answers) {
      answer.dispose();
    }
    super.dispose();
  }

  void _addAnswer() {
    if (_answers.length >= 10) {
      return;
    }
    setState(() {
      _answers = List.unmodifiable([..._answers, TextEditingController()]);
    });
  }

  void _removeAnswer(int index) {
    if (_answers.length <= 2) {
      return;
    }
    final removed = _answers[index];
    setState(() {
      _answers = List.unmodifiable([
        for (var current = 0; current < _answers.length; current += 1)
          if (current != index) _answers[current],
      ]);
    });
    removed.dispose();
  }

  void _submit() {
    final question = _question.text.trim();
    final answers = List<String>.unmodifiable(
      _answers.map((answer) => answer.text.trim()),
    );
    final error = _validate(question, answers);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    Navigator.of(context).pop(
      DiscordPollDraft(
        question: question,
        answers: answers,
        durationHours: _durationHours,
        allowMultiselect: _allowMultiselect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('투표 만들기'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('poll-question-field'),
                controller: _question,
                autofocus: true,
                maxLength: 300,
                decoration: const InputDecoration(labelText: '질문'),
              ),
              for (var index = 0; index < _answers.length; index += 1)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey('poll-answer-$index'),
                        controller: _answers[index],
                        maxLength: 55,
                        decoration: InputDecoration(
                          labelText: '답변 ${index + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '답변 삭제',
                      onPressed: _answers.length > 2
                          ? () => _removeAnswer(index)
                          : null,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _answers.length < 10 ? _addAnswer : null,
                  icon: const Icon(Icons.add),
                  label: const Text('답변 추가'),
                ),
              ),
              DropdownButtonFormField<int>(
                key: const ValueKey('poll-duration-field'),
                initialValue: _durationHours,
                decoration: const InputDecoration(labelText: '투표 기간'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1시간')),
                  DropdownMenuItem(value: 4, child: Text('4시간')),
                  DropdownMenuItem(value: 8, child: Text('8시간')),
                  DropdownMenuItem(value: 24, child: Text('1일')),
                  DropdownMenuItem(value: 72, child: Text('3일')),
                  DropdownMenuItem(value: 168, child: Text('1주')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _durationHours = value);
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('여러 답변 선택 허용'),
                value: _allowMultiselect,
                onChanged: (value) {
                  setState(() => _allowMultiselect = value);
                },
              ),
              if (_errorMessage case final error?)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('투표 게시')),
      ],
    );
  }
}

String? _validate(String question, List<String> answers) {
  if (question.isEmpty) {
    return '질문을 입력해 주세요.';
  }
  if (answers.length < 2 || answers.any((answer) => answer.isEmpty)) {
    return '두 개 이상의 답변을 입력해 주세요.';
  }
  return null;
}
