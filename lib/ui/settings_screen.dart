import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../data/event_log_store.dart';
import '../data/export_service.dart';
import '../domain/app_state.dart';
import '../domain/unlocks.dart';
import 'collection_screen.dart';
import 'history_screen.dart';
import 'task_editor_sheet.dart';
import 'theme/app_theme.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_effects.dart';
import 'theme/pet_motion.dart';
import 'theme/pet_radii.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.eventLog,
  });

  final AppController controller;
  final EventLogStore eventLog;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.controller.state.petName);
    widget.controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _name.dispose();
    super.dispose();
  }

  Future<void> _editTask(TodoTask task) async {
    final state = widget.controller.state;
    final draft = await showTaskEditorSheet(
      context: context,
      task: task,
      allowOneOff: task.kind == TaskKind.oneOff || state.dailyTasks.length > 1,
      notificationDenied:
          state.notificationPermission == NotificationPermissionState.denied,
    );
    if (draft == null) return;
    final saved = await widget.controller.editTask(
      taskId: task.id,
      title: draft.title,
      kind: draft.kind,
      note: draft.note,
    );
    if (!saved) return;
    final reminderSaved = await widget.controller.setTaskReminder(
      taskId: task.id,
      enabled: draft.reminderEnabled,
      hour: draft.reminderTime.hour,
      minute: draft.reminderTime.minute,
    );
    if (!reminderSaved && draft.reminderEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The task is safe. Notifications will stay quiet.'),
        ),
      );
    }
  }

  Future<void> _addTask() async {
    final draft = await showTaskEditorSheet(
      context: context,
      initialKind: TaskKind.daily,
      notificationDenied:
          widget.controller.state.notificationPermission ==
          NotificationPermissionState.denied,
    );
    if (draft == null) return;
    final added = await widget.controller.addTask(
      title: draft.title,
      kind: draft.kind,
      note: draft.note,
    );
    if (!added) return;
    final task = widget.controller.state.tasks.last;
    await widget.controller.setTaskReminder(
      taskId: task.id,
      enabled: draft.reminderEnabled,
      hour: draft.reminderTime.hour,
      minute: draft.reminderTime.minute,
    );
  }

  Future<void> _removeTask(TodoTask task) async {
    final removed = await widget.controller.removeTask(task.id);
    if (!removed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep one daily thing as a gentle home base.'),
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final state = widget.controller.state;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: state.notificationHour,
        minute: state.notificationMinute,
      ),
      helpText: 'When should the evening hello arrive?',
      cancelText: 'Not now',
      confirmText: 'Save time',
    );
    if (result != null) {
      await widget.controller.updateNotificationTime(
        result.hour,
        result.minute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: PetColors.transparent,
        systemNavigationBarColor: PetColors.screenBottom,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppTheme.screenGradient),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: PetSpacing.s44),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PetSpacing.s28,
                  PetSpacing.s8,
                  PetSpacing.s28,
                  PetSpacing.s12,
                ),
                child: Semantics(
                  container: true,
                  header: true,
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if ((details.primaryVelocity ?? PetSpacing.zero) >
                          PetSpacing.zero) {
                        Navigator.of(context).maybePop();
                      }
                    },
                    child: const Text(
                      'Settings',
                      style: PetTextStyles.display24,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    PetSpacing.s20,
                    PetSpacing.zero,
                    PetSpacing.s20,
                    PetSpacing.s24,
                  ),
                  children: <Widget>[
                    _SettingsPanel(
                      children: <Widget>[
                        const Text('Pet name', style: PetTextStyles.caption),
                        const SizedBox(height: PetSpacing.s10),
                        TextField(
                          controller: _name,
                          maxLength: 20,
                          style: PetTextStyles.body16,
                          decoration: const InputDecoration(
                            hintText: 'Choco',
                            counterText: '',
                          ),
                          onChanged: widget.controller.updatePetName,
                        ),
                      ],
                    ),
                    const SizedBox(height: PetSpacing.s14),
                    _SettingsPanel(
                      children: <Widget>[
                        const Text(
                          'Your little things',
                          style: PetTextStyles.caption,
                        ),
                        const SizedBox(height: PetSpacing.s10),
                        for (final task
                            in widget.controller.state.tasks) ...<Widget>[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              task.title,
                              style: PetTextStyles.body16Strong,
                            ),
                            subtitle: Text(
                              <String>[
                                task.kind == TaskKind.daily
                                    ? 'Every day'
                                    : 'Just once',
                                if (task.note != null) task.note!,
                                if (task.reminder?.enabled ?? false)
                                  'One reminder at ${_formatTime(TimeOfDay(hour: task.reminder!.hour, minute: task.reminder!.minute))}',
                              ].join(' · '),
                              style: PetTextStyles.captionSoft,
                            ),
                            onTap: () => _editTask(task),
                            trailing: IconButton(
                              tooltip: 'Remove ${task.title}',
                              onPressed: () => _removeTask(task),
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: PetSpacing.s8),
                        OutlinedButton.icon(
                          onPressed: widget.controller.state.canAddTask
                              ? _addTask
                              : null,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(
                            widget.controller.state.canAddTask
                                ? 'Add one little thing'
                                : 'Seven little things are plenty for now',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PetSpacing.s14),
                    _NotificationPanel(
                      controller: widget.controller,
                      onPickTime: _pickTime,
                    ),
                    const SizedBox(height: PetSpacing.s14),
                    _CollectionPanel(controller: widget.controller),
                    const SizedBox(height: PetSpacing.s14),
                    _SettingsPanel(
                      compact: true,
                      children: <Widget>[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.favorite_outline_rounded),
                          title: const Text(
                            'Things we did together',
                            style: PetTextStyles.body15Strong,
                          ),
                          subtitle: const Text(
                            'Only warm memories — no streaks or missed days',
                            style: PetTextStyles.captionSoft,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => HistoryScreen(
                                eventLog: widget.eventLog,
                                petName: widget.controller.state.petName,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PetSpacing.s14),
                    _SettingsPanel(
                      compact: true,
                      children: <Widget>[
                        Semantics(
                          container: true,
                          button: true,
                          child: Builder(
                            builder: (buttonContext) => InkWell(
                              onTap: () async {
                                final box =
                                    buttonContext.findRenderObject()!
                                        as RenderBox;
                                await ExportService(
                                  widget.eventLog,
                                ).shareEvents(
                                  sharePositionOrigin:
                                      box.localToGlobal(Offset.zero) & box.size,
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: PetSpacing.s14,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        'Export our story',
                                        style: PetTextStyles.body15Strong,
                                      ),
                                    ),
                                    ExcludeSemantics(
                                      child: Text(
                                        '›',
                                        style: PetTextStyles.chevron,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Divider(
                          height: PetSpacing.xxs,
                          thickness: PetSpacing.xxs / 2,
                          color: PetColors.cardDivider,
                        ),
                        Semantics(
                          container: true,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: PetSpacing.s14,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    'Version',
                                    style: PetTextStyles.body15Soft,
                                  ),
                                ),
                                Text(
                                  'PetTodo v1.0.0',
                                  style: PetTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.children, this.compact = false});

  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: PetSpacing.s20,
      vertical: compact ? PetSpacing.s6 : PetSpacing.s18,
    ),
    decoration: const BoxDecoration(
      color: PetColors.white,
      borderRadius: PetRadii.cardBorder,
      boxShadow: PetShadows.panel,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({
    required this.controller,
    required this.onPickTime,
  });

  final AppController controller;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final time = TimeOfDay(
      hour: state.notificationHour,
      minute: state.notificationMinute,
    );
    final denied =
        state.notificationPermission == NotificationPermissionState.denied;
    final subtitle = state.notificationEnabled
        ? '${state.petName} will say a soft hello at ${_formatTime(time)}'
        : 'All quiet — ${state.petName} is home, waiting for you';
    return _SettingsPanel(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                child: InkWell(
                  onTap: onPickTime,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Evening hello',
                        style: PetTextStyles.body16Strong,
                      ),
                      const SizedBox(height: PetSpacing.xs),
                      Text(subtitle, style: PetTextStyles.captionSoft),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: PetSpacing.s14),
            _PetToggle(
              value: state.notificationEnabled,
              enabled: !denied,
              onChanged: controller.setNotificationEnabled,
            ),
          ],
        ),
        const SizedBox(height: PetSpacing.s14),
        Wrap(
          spacing: PetSpacing.s10,
          children: <Widget>[
            for (final hour in <int>[19, 20, 21])
              _SettingsTimeChip(
                value: TimeOfDay(hour: hour, minute: 0),
                selected:
                    state.notificationHour == hour &&
                    state.notificationMinute == 0,
                onTap: (value) =>
                    controller.updateNotificationTime(value.hour, value.minute),
              ),
          ],
        ),
      ],
    );
  }
}

class _PetToggle extends StatelessWidget {
  const _PetToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    toggled: value,
    enabled: enabled,
    label: 'Evening hello',
    child: GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Opacity(
        opacity: enabled
            ? PetEffects.fullOpacity
            : PetEffects.disabledToggleOpacity,
        child: AnimatedContainer(
          duration: PetMotion.quick,
          width: PetSpacing.s58,
          height: PetSpacing.s38,
          padding: const EdgeInsets.all(PetSpacing.xs),
          decoration: BoxDecoration(
            color: value ? PetColors.primary : PetColors.disabledBorder,
            borderRadius: PetRadii.pillBorder,
          ),
          child: AnimatedAlign(
            duration: PetMotion.quick,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: PetColors.white,
                shape: BoxShape.circle,
                boxShadow: PetShadows.toggleKnob,
              ),
              child: SizedBox.square(dimension: PetSpacing.s26),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SettingsTimeChip extends StatelessWidget {
  const _SettingsTimeChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final TimeOfDay value;
  final bool selected;
  final ValueChanged<TimeOfDay> onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    checked: selected,
    child: InkWell(
      borderRadius: PetRadii.pillBorder,
      onTap: () => onTap(value),
      child: Container(
        height: PetSpacing.s40,
        padding: const EdgeInsets.symmetric(
          horizontal: PetSpacing.s16,
          vertical: PetSpacing.s9,
        ),
        decoration: BoxDecoration(
          color: selected ? PetColors.primary : PetColors.white,
          borderRadius: PetRadii.pillBorder,
          border: Border.all(
            color: selected ? PetColors.primary : PetColors.stroke,
            width: PetSpacing.xxs,
          ),
        ),
        child: Text(
          _formatTime(value),
          style: selected
              ? PetTextStyles.chip.copyWith(color: PetColors.white)
              : PetTextStyles.chip,
        ),
      ),
    ),
  );
}

class _CollectionPanel extends StatelessWidget {
  const _CollectionPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final next = nextUnlock(state.lifetimeCompletions);
    return _SettingsPanel(
      children: <Widget>[
        Semantics(
          container: true,
          button: true,
          child: InkWell(
            borderRadius: PetRadii.cardSmallBorder,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CollectionScreen(controller: controller),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PetSpacing.s8),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: PetColors.primary,
                  ),
                  const SizedBox(width: PetSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "${state.petName}'s little collection",
                          style: PetTextStyles.body16Strong,
                        ),
                        const SizedBox(height: PetSpacing.xs),
                        Text(
                          next == null
                              ? 'Every keepsake has found a home'
                              : 'Next keepsake arrives after ${next.threshold - state.lifetimeCompletions} more together',
                          style: PetTextStyles.captionSoft,
                        ),
                      ],
                    ),
                  ),
                  const Text('›', style: PetTextStyles.chevron),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}
