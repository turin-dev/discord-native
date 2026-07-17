import 'package:discord_native/features/workspace/data/discord_scheduled_event_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_scheduled_event.dart';
import 'package:discord_native/features/workspace/presentation/guild_event_editor.dart';
import 'package:flutter/material.dart';

typedef LoadScheduledEventsCallback =
    Future<List<DiscordScheduledEvent>> Function();
typedef CreateScheduledEventCallback =
    Future<DiscordScheduledEvent?> Function(
      DiscordExternalEventRequest request,
    );
typedef UpdateScheduledEventCallback =
    Future<DiscordScheduledEvent?> Function(
      String eventId,
      DiscordExternalEventRequest request, {
      DiscordScheduledEventStatus? status,
    });
typedef DeleteScheduledEventCallback = Future<void> Function(String eventId);

class GuildEventSection extends StatefulWidget {
  const GuildEventSection({
    required this.onLoad,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
    super.key,
  });

  final LoadScheduledEventsCallback onLoad;
  final CreateScheduledEventCallback onCreate;
  final UpdateScheduledEventCallback onUpdate;
  final DeleteScheduledEventCallback onDelete;

  @override
  State<GuildEventSection> createState() => _GuildEventSectionState();
}

class _GuildEventSectionState extends State<GuildEventSection> {
  List<DiscordScheduledEvent> _events = const [];
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final events = await widget.onLoad();
      if (mounted) {
        setState(() {
          _events = List.unmodifiable(events);
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  Future<void> _create() async {
    final draft = await showGuildEventEditor(context);
    if (draft == null) {
      return;
    }
    try {
      final event = await widget.onCreate(draft.request);
      if (mounted && event != null) {
        setState(() {
          _events = List.unmodifiable([
            event,
            ..._events.where((item) => item.id != event.id),
          ]);
          _errorMessage = null;
        });
      }
    } on Object catch (error) {
      _setError(error);
    }
  }

  Future<void> _update(DiscordScheduledEvent event) async {
    final draft = await showGuildEventEditor(context, event: event);
    if (draft == null) {
      return;
    }
    try {
      final updated = await widget.onUpdate(
        event.id,
        draft.request,
        status: draft.status,
      );
      if (mounted && updated != null) {
        setState(() {
          _events = List.unmodifiable([
            for (final item in _events)
              if (item.id == updated.id) updated else item,
          ]);
          _errorMessage = null;
        });
      }
    } on Object catch (error) {
      _setError(error);
    }
  }

  Future<void> _delete(DiscordScheduledEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('예약 이벤트 삭제'),
        content: Text('${event.name} 이벤트를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.onDelete(event.id);
      if (mounted) {
        setState(() {
          _events = List.unmodifiable(
            _events.where((item) => item.id != event.id),
          );
          _errorMessage = null;
        });
      }
    } on Object catch (error) {
      _setError(error);
    }
  }

  void _setError(Object error) {
    if (mounted) {
      setState(() => _errorMessage = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Row(
          children: [
            if (_errorMessage case final message?)
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Color(0xFFF23F42)),
                ),
              )
            else
              const Spacer(),
            IconButton(
              tooltip: '예약 이벤트 새로고침',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: '예약 이벤트 만들기',
              onPressed: _create,
              icon: const Icon(Icons.event_available),
            ),
          ],
        ),
        Expanded(
          child: _events.isEmpty
              ? const Center(child: Text('예약 이벤트가 없습니다.'))
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return ListTile(
                      title: Text(event.name),
                      subtitle: Text(_eventDescription(event)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (event.entityType ==
                              DiscordScheduledEventEntityType.external)
                            IconButton(
                              tooltip: '${event.name} 이벤트 설정',
                              onPressed: () => _update(event),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          IconButton(
                            tooltip: '${event.name} 이벤트 삭제',
                            onPressed: () => _delete(event),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

String _eventDescription(DiscordScheduledEvent event) {
  final location = event.location ?? 'Discord';
  final start = event.scheduledStartTime.toLocal();
  return '$location · $start · ${_statusLabel(event.status)}';
}

String _statusLabel(DiscordScheduledEventStatus status) {
  return switch (status) {
    DiscordScheduledEventStatus.scheduled => '예정',
    DiscordScheduledEventStatus.active => '진행 중',
    DiscordScheduledEventStatus.completed => '완료',
    DiscordScheduledEventStatus.canceled => '취소됨',
  };
}
