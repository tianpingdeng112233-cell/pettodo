import 'package:flutter/material.dart';

import '../domain/app_state.dart';

class TaskEditDraft {
  const TaskEditDraft({
    required this.title,
    required this.kind,
    required this.note,
    required this.reminderEnabled,
    required this.reminderTime,
  });

  final String title;
  final TaskKind kind;
  final String? note;
  final bool reminderEnabled;
  final TimeOfDay reminderTime;
}

Future<TaskEditDraft?> showTaskEditorSheet({
  required BuildContext context,
  TodoTask? task,
  TaskKind initialKind = TaskKind.daily,
  bool allowOneOff = true,
  bool notificationDenied = false,
}) => showModalBottomSheet<TaskEditDraft>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _TaskEditor(
    task: task,
    initialKind: initialKind,
    allowOneOff: allowOneOff,
    notificationDenied: notificationDenied,
  ),
);

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({
    required this.task,
    required this.initialKind,
    required this.allowOneOff,
    required this.notificationDenied,
  });

  final TodoTask? task;
  final TaskKind initialKind;
  final bool allowOneOff;
  final bool notificationDenied;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late TaskKind _kind;
  late bool _reminderEnabled;
  late TimeOfDay _reminderTime;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task?.title ?? '');
    _note = TextEditingController(text: widget.task?.note ?? '');
    _kind = widget.task?.kind ?? widget.initialKind;
    _reminderEnabled = widget.task?.reminder?.enabled ?? false;
    _reminderTime = TimeOfDay(
      hour: widget.task?.reminder?.hour ?? 9,
      minute: widget.task?.reminder?.minute ?? 0,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'When should your pet give one gentle nudge?',
      cancelText: 'Not now',
      confirmText: 'Use this time',
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final note = _note.text.trim();
    Navigator.of(context).pop(
      TaskEditDraft(
        title: title,
        kind: _kind,
        note: note.isEmpty ? null : note,
        reminderEnabled: _reminderEnabled && !widget.notificationDenied,
        reminderTime: _reminderTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      16,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.task == null
                ? 'Add one little thing'
                : 'Keep it easy to see',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: widget.task == null,
            maxLength: 60,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'What would feel good to remember?',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLength: 100,
            maxLines: 1,
            decoration: const InputDecoration(
              labelText: 'Tiny note (optional)',
              hintText: 'One helpful detail',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<TaskKind>(
            segments: <ButtonSegment<TaskKind>>[
              const ButtonSegment<TaskKind>(
                value: TaskKind.daily,
                label: Text('Every day'),
                icon: Icon(Icons.wb_sunny_outlined),
              ),
              ButtonSegment<TaskKind>(
                value: TaskKind.oneOff,
                enabled: widget.allowOneOff,
                label: const Text('Just once'),
                icon: const Icon(Icons.bolt_rounded),
              ),
            ],
            selected: <TaskKind>{_kind},
            onSelectionChanged: (value) => setState(() => _kind = value.first),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('One gentle reminder'),
            subtitle: Text(
              widget.notificationDenied
                  ? 'Notifications are staying quiet on this device.'
                  : _reminderEnabled
                  ? 'One invitation at ${_reminderTime.format(context)}, never repeated.'
                  : 'Optional — your pet will not nag.',
            ),
            value: _reminderEnabled && !widget.notificationDenied,
            onChanged: widget.notificationDenied
                ? null
                : (value) => setState(() => _reminderEnabled = value),
          ),
          if (_reminderEnabled && !widget.notificationDenied)
            TextButton.icon(
              onPressed: _pickReminderTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text('At ${_reminderTime.format(context)}'),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save this thing')),
        ],
      ),
    ),
  );
}
