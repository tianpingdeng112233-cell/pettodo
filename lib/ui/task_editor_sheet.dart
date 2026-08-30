import 'package:flutter/material.dart';

import '../domain/app_state.dart';
import 'pet_date_format.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';
import 'widgets/pixel_components.dart';
import 'widgets/pixel_icon.dart';

class TaskEditDraft {
  const TaskEditDraft({
    required this.title,
    required this.kind,
    required this.note,
    required this.reminderEnabled,
    required this.reminderTime,
    required this.reminderScheduledAt,
  });

  final String title;
  final TaskKind kind;
  final String? note;
  final bool reminderEnabled;
  final TimeOfDay reminderTime;
  final DateTime? reminderScheduledAt;
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
  late DateTime _reminderDate;
  String? _reminderError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task?.title ?? '');
    _note = TextEditingController(text: widget.task?.note ?? '');
    _kind = widget.task?.kind ?? widget.initialKind;
    final now = DateTime.now();
    final existingReminder = widget.task?.reminder;
    _reminderEnabled =
        existingReminder?.enabled == true &&
        !(existingReminder?.isTimed == true &&
            !existingReminder!.scheduledAt!.isAfter(now));
    final nextDailyAt = _nextDailyAt(
      now,
      existingReminder?.hour ?? 9,
      existingReminder?.minute ?? 0,
    );
    final initialAt = existingReminder?.scheduledAt ?? nextDailyAt;
    _reminderTime = TimeOfDay(hour: initialAt.hour, minute: initialAt.minute);
    _reminderDate = DateTime(initialAt.year, initialAt.month, initialAt.day);
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
      helpText: _kind == TaskKind.oneOff
          ? 'When should your pet send this invitation?'
          : 'When should your pet give one gentle nudge?',
      cancelText: 'Not now',
      confirmText: 'Use this time',
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
        _reminderError = null;
      });
    }
  }

  Future<void> _pickReminderDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _reminderDate.isBefore(today) ? today : _reminderDate,
      firstDate: today,
      lastDate: DateTime(today.year + 10, today.month, today.day),
      helpText: 'Which day should your pet send this invitation?',
      cancelText: 'Not now',
      confirmText: 'Use this day',
    );
    if (picked != null) {
      setState(() {
        _reminderDate = picked;
        _reminderError = null;
      });
    }
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final note = _note.text.trim();
    final scheduledAt = DateTime(
      _reminderDate.year,
      _reminderDate.month,
      _reminderDate.day,
      _reminderTime.hour,
      _reminderTime.minute,
    );
    if (_kind == TaskKind.oneOff &&
        _reminderEnabled &&
        !widget.notificationDenied &&
        !scheduledAt.isAfter(DateTime.now())) {
      setState(() {
        _reminderError = 'Choose a moment that is still ahead.';
      });
      return;
    }
    Navigator.of(context).pop(
      TaskEditDraft(
        title: title,
        kind: _kind,
        note: note.isEmpty ? null : note,
        reminderEnabled: _reminderEnabled && !widget.notificationDenied,
        reminderTime: _reminderTime,
        reminderScheduledAt: _kind == TaskKind.oneOff ? scheduledAt : null,
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
            style: PetTextStyles.display24,
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
                icon: PxIcon(PxIconData.sun, size: 18),
              ),
              ButtonSegment<TaskKind>(
                value: TaskKind.oneOff,
                enabled: widget.allowOneOff,
                label: const Text('Just once'),
                icon: const PxIcon(PxIconData.bolt, size: 18),
              ),
            ],
            selected: <TaskKind>{_kind},
            onSelectionChanged: (value) => setState(() => _kind = value.first),
          ),
          const SizedBox(height: 12),
          if (_kind == TaskKind.oneOff)
            _buildTimedReminder(context)
          else
            _buildDailyReminder(context),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save this thing')),
        ],
      ),
    ),
  );

  Widget _buildTimedReminder(BuildContext context) => PxCard(
    padding: const EdgeInsets.all(PetSpacing.s16),
    fillColor: PetColors.theaterText,
    borderColor: PetColors.primary,
    borderWidth: 2,
    shadows: const <BoxShadow>[],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _reminderToggleRow(
          icon: PxIconData.calendar,
          title: 'Remind me once',
          caption: widget.notificationDenied
              ? 'Notifications are staying quiet on this device.'
              : 'One invitation at that moment, never repeated.',
        ),
        if (_reminderEnabled && !widget.notificationDenied) ...<Widget>[
          const SizedBox(height: PetSpacing.s12),
          Row(
            children: <Widget>[
              Expanded(
                child: PxChip(
                  onTap: _pickReminderDate,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const PxIcon(PxIconData.calendar, size: 16),
                      const SizedBox(width: PetSpacing.s6),
                      Flexible(child: Text(formatShortDate(_reminderDate))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: PetSpacing.s8),
              Expanded(
                child: PxChip(
                  onTap: _pickReminderTime,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const PxIcon(PxIconData.clock, size: 16),
                      const SizedBox(width: PetSpacing.s6),
                      Text(
                        format24Hour(_reminderTime.hour, _reminderTime.minute),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_reminderError != null) ...<Widget>[
            const SizedBox(height: PetSpacing.s8),
            Text(
              _reminderError!,
              style: PetTextStyles.captionSoft.copyWith(
                color: PetColors.accentText,
              ),
            ),
          ],
        ],
      ],
    ),
  );

  Widget _buildDailyReminder(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _reminderToggleRow(
        icon: PxIconData.clock,
        title: 'One gentle reminder',
        caption: widget.notificationDenied
            ? 'Notifications are staying quiet on this device.'
            : 'Optional — your pet will not nag.',
      ),
      if (_reminderEnabled && !widget.notificationDenied) ...<Widget>[
        const SizedBox(height: PetSpacing.s8),
        PxChip(
          onTap: _pickReminderTime,
          child: Row(
            children: <Widget>[
              const PxIcon(PxIconData.clock, size: 18),
              const SizedBox(width: PetSpacing.s8),
              Expanded(
                child: Text('Every day at ${_reminderTime.format(context)}'),
              ),
              const PxIcon(PxIconData.chevronRight, size: 16),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _reminderToggleRow({
    required PxIconData icon,
    required String title,
    required String caption,
  }) => MergeSemantics(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.notificationDenied
          ? null
          : () => setState(() {
              _reminderEnabled = !_reminderEnabled;
              _reminderError = null;
            }),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PxIcon(icon, size: PetSpacing.s20, color: PetColors.accentText),
          const SizedBox(width: PetSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: PetTextStyles.body16Strong),
                const SizedBox(height: PetSpacing.xs),
                Text(caption, style: PetTextStyles.captionSoft),
              ],
            ),
          ),
          const SizedBox(width: PetSpacing.s14),
          PxToggle(
            value: _reminderEnabled && !widget.notificationDenied,
            enabled: !widget.notificationDenied,
            onChanged: (value) => setState(() {
              _reminderEnabled = value;
              _reminderError = null;
            }),
          ),
        ],
      ),
    ),
  );
}

DateTime _nextDailyAt(DateTime now, int hour, int minute) {
  var candidate = DateTime(now.year, now.month, now.day, hour, minute);
  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}
