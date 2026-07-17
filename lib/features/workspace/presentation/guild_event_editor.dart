import 'package:discord_native/features/workspace/data/discord_scheduled_event_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_scheduled_event.dart';
import 'package:flutter/material.dart';

final class GuildEventDraft {
  const GuildEventDraft({required this.request, required this.status});

  final DiscordExternalEventRequest request;
  final DiscordScheduledEventStatus status;
}

Future<GuildEventDraft?> showGuildEventEditor(
  BuildContext context, {
  DiscordScheduledEvent? event,
}) {
  return showDialog<GuildEventDraft>(
    context: context,
    builder: (context) => _EventEditorDialog(event: event),
  );
}

class _EventEditorDialog extends StatefulWidget {
  const _EventEditorDialog({this.event});

  final DiscordScheduledEvent? event;

  @override
  State<_EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends State<_EventEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late DiscordScheduledEventStatus _status;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _name = TextEditingController(text: event?.name ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _location = TextEditingController(text: event?.location ?? '');
    _start = TextEditingController(
      text: event?.scheduledStartTime.toUtc().toIso8601String() ?? '',
    );
    _end = TextEditingController(
      text: event?.scheduledEndTime?.toUtc().toIso8601String() ?? '',
    );
    _status = event?.status ?? DiscordScheduledEventStatus.scheduled;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final location = _location.text.trim();
    final start = DateTime.tryParse(_start.text.trim())?.toUtc();
    final end = DateTime.tryParse(_end.text.trim())?.toUtc();
    final error = _validate(name, location, start, end);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    Navigator.pop(
      context,
      GuildEventDraft(
        request: DiscordExternalEventRequest(
          name: name,
          description: _description.text.trim(),
          location: location,
          scheduledStartTime: start!,
          scheduledEndTime: end!,
        ),
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? '예약 이벤트 만들기' : '예약 이벤트 설정'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildFields(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }

  List<Widget> _buildFields() {
    return [
      _textField('event-name-field', _name, '이름'),
      TextField(
        controller: _description,
        decoration: const InputDecoration(labelText: '설명'),
        maxLines: 3,
      ),
      _textField('event-location-field', _location, '위치'),
      _textField(
        'event-start-field',
        _start,
        '시작 시각',
        hintText: '2030-01-01T10:00:00Z',
      ),
      _textField(
        'event-end-field',
        _end,
        '종료 시각',
        hintText: '2030-01-01T11:00:00Z',
      ),
      if (widget.event != null) _statusField(),
      if (_errorMessage case final message?) _errorText(message),
    ];
  }

  Widget _statusField() {
    return DropdownButtonFormField<DiscordScheduledEventStatus>(
      key: const ValueKey('event-status-field'),
      initialValue: _status,
      decoration: const InputDecoration(labelText: '상태'),
      items: [
        for (final status in DiscordScheduledEventStatus.values)
          DropdownMenuItem(value: status, child: Text(_statusLabel(status))),
      ],
      onChanged: (status) {
        if (status != null) {
          setState(() => _status = status);
        }
      },
    );
  }
}

Widget _textField(
  String key,
  TextEditingController controller,
  String label, {
  String? hintText,
}) {
  return TextField(
    key: ValueKey(key),
    controller: controller,
    decoration: InputDecoration(labelText: label, hintText: hintText),
  );
}

Widget _errorText(String message) {
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(message, style: const TextStyle(color: Color(0xFFF23F42))),
  );
}

String? _validate(
  String name,
  String location,
  DateTime? start,
  DateTime? end,
) {
  if (name.isEmpty || name.length > 100) {
    return '이벤트 이름은 1~100자여야 합니다.';
  }
  if (location.isEmpty || location.length > 100) {
    return '이벤트 위치는 1~100자여야 합니다.';
  }
  if (start == null || end == null) {
    return '시작과 종료 시각을 ISO 8601 형식으로 입력하세요.';
  }
  if (!end.isAfter(start)) {
    return '이벤트 종료 시각은 시작 이후여야 합니다.';
  }
  return null;
}

String _statusLabel(DiscordScheduledEventStatus status) {
  return switch (status) {
    DiscordScheduledEventStatus.scheduled => '예정',
    DiscordScheduledEventStatus.active => '진행 중',
    DiscordScheduledEventStatus.completed => '완료',
    DiscordScheduledEventStatus.canceled => '취소됨',
  };
}
