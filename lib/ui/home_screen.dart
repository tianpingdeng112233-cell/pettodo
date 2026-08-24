import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../data/event_log_store.dart';
import '../domain/app_state.dart';
import '../sprite/pet_sprite.dart';
import 'collection_screen.dart';
import 'history_screen.dart';
import 'hatch_request_screen.dart';
import 'settings_screen.dart';
import 'task_editor_sheet.dart';
import 'theme/app_theme.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_effects.dart';
import 'theme/pet_motion.dart';
import 'theme/pet_radii.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_stage_theme.dart';
import 'theme/pet_text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.eventLog,
  });

  final AppController controller;
  final EventLogStore eventLog;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: PetColors.transparent,
      systemNavigationBarColor: PetColors.screenBottom,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.screenGradient),
        child: Stack(
          children: <Widget>[
            const _SunHalo(),
            Positioned.fill(
              child: _HomeContent(controller: controller, eventLog: eventLog),
            ),
            _UnlockBanner(controller: controller),
            if (controller.theaterVisible)
              _LittleTheater(controller: controller),
          ],
        ),
      ),
    ),
  );
}

class _HomeContent extends StatefulWidget {
  const _HomeContent({required this.controller, required this.eventLog});

  final AppController controller;
  final EventLogStore eventLog;

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  bool _editing = false;

  AppController get controller => widget.controller;
  EventLogStore get eventLog => widget.eventLog;

  Future<void> _quickAdd() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _QuickAddDialog(),
    );
    if (title != null && title.isNotEmpty) {
      await controller.addTask(title: title);
    }
  }

  Future<void> _addFromEditor() async {
    final draft = await showTaskEditorSheet(
      context: context,
      initialKind: TaskKind.daily,
      notificationDenied:
          controller.state.notificationPermission ==
          NotificationPermissionState.denied,
    );
    if (draft == null) return;
    final added = await controller.addTask(
      title: draft.title,
      kind: draft.kind,
      note: draft.note,
    );
    if (!added) return;
    final task = controller.state.tasks.last;
    await controller.setTaskReminder(
      taskId: task.id,
      enabled: draft.reminderEnabled,
      hour: draft.reminderTime.hour,
      minute: draft.reminderTime.minute,
    );
  }

  Future<void> _editTask(TodoTask task) async {
    final draft = await showTaskEditorSheet(
      context: context,
      task: task,
      allowOneOff:
          task.kind == TaskKind.oneOff ||
          controller.state.dailyTasks.length > 1,
      notificationDenied:
          controller.state.notificationPermission ==
          NotificationPermissionState.denied,
    );
    if (draft == null) return;
    final edited = await controller.editTask(
      taskId: task.id,
      title: draft.title,
      kind: draft.kind,
      note: draft.note,
    );
    if (!edited || !mounted) return;
    final reminderSaved = await controller.setTaskReminder(
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

  Future<void> _removeTask(TodoTask task) async {
    final removed = await controller.removeTask(task.id);
    if (!removed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep one daily thing as a gentle home base.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      const SizedBox(height: PetSpacing.s44),
      SizedBox(
        height: PetSpacing.s30,
        child: Padding(
          padding: const EdgeInsets.only(
            left: PetSpacing.s28,
            right: PetSpacing.s20,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _dateGreeting(DateTime.now()),
                  style: PetTextStyles.status,
                ),
              ),
              Semantics(
                container: true,
                button: true,
                label: 'Settings',
                child: InkResponse(
                  radius: PetSpacing.s22,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(
                        controller: controller,
                        eventLog: eventLog,
                      ),
                    ),
                  ),
                  child: const SizedBox(
                    width: PetSpacing.s44,
                    height: PetSpacing.s44,
                    child: Icon(
                      Icons.tune_rounded,
                      size: PetSpacing.s20,
                      color: PetColors.caption,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Flexible(flex: 4, child: _PetStage(controller: controller)),
      _TreatBar(controller: controller),
      Flexible(
        flex: 5,
        child: _TaskList(
          controller: controller,
          editing: _editing,
          onToggleEditing: () => setState(() => _editing = !_editing),
          onQuickAdd: controller.state.canAddTask
              ? _editing
                    ? _addFromEditor
                    : _quickAdd
              : null,
          onEdit: _editTask,
          onRemove: _removeTask,
          onHistory: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HistoryScreen(
                eventLog: eventLog,
                petName: controller.state.petName,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: PetSpacing.s10),
    ],
  );
}

class _SunHalo extends StatelessWidget {
  const _SunHalo();

  @override
  Widget build(BuildContext context) => Positioned(
    top: PetSpacing.sunTop,
    left: (MediaQuery.sizeOf(context).width - PetSpacing.sunSize) / 2,
    child: const ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[PetColors.sunHalo, PetColors.transparent],
            stops: <double>[PetSpacing.zero, PetEffects.haloStop],
          ),
        ),
        child: SizedBox.square(dimension: PetSpacing.sunSize),
      ),
    ),
  );
}

class _PetStage extends StatelessWidget {
  const _PetStage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final name = controller.state.petName;
    final status = controller.statusLine;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        height: PetSpacing.sunSize,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _BreathingSprite(controller: controller),
            Transform.translate(
              offset: const Offset(PetSpacing.zero, -PetSpacing.s12),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: PetColors.groundShadow,
                  borderRadius: PetRadii.pillBorder,
                ),
                child: SizedBox(width: PetSpacing.s170, height: PetSpacing.s20),
              ),
            ),
            Transform.translate(
              offset: const Offset(PetSpacing.zero, -PetSpacing.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(name, style: PetTextStyles.display30),
                  const SizedBox(width: PetSpacing.s8),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: PetColors.badgeFill,
                      borderRadius: PetRadii.pillBorder,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PetSpacing.s10,
                        vertical: PetSpacing.s4,
                      ),
                      child: Text(
                        controller.growthStage.label,
                        style: PetTextStyles.small.copyWith(
                          color: PetColors.accentText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(PetSpacing.zero, -PetSpacing.s8),
              child: SizedBox(
                width: PetSpacing.s280,
                height: PetSpacing.s38,
                child: AnimatedSwitcher(
                  duration: PetMotion.task,
                  child: Text(
                    status,
                    key: ValueKey<String>(status),
                    style: PetTextStyles.status,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            if (controller.pendingHatchRequest != null)
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: 'Your pet is on its way — no rush. Open adoption request',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HatchRequestScreen(controller: controller),
                  ),
                ),
                child: InkWell(
                  borderRadius: PetRadii.pillBorder,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          HatchRequestScreen(controller: controller),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: PetSpacing.s12,
                      vertical: PetSpacing.s4,
                    ),
                    child: Text(
                      '🐾  Your pet is on its way — no rush.  Import ›',
                      style: PetTextStyles.small,
                    ),
                  ),
                ),
              ),
            ExcludeSemantics(child: _Decorations(controller: controller)),
          ],
        ),
      ),
    );
  }
}

class _BreathingSprite extends StatefulWidget {
  const _BreathingSprite({required this.controller});

  final AppController controller;

  @override
  State<_BreathingSprite> createState() => _BreathingSpriteState();
}

class _BreathingSpriteState extends State<_BreathingSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  Offset _lastTapPosition = const Offset(
    PetSpacing.s192 / 2,
    PetSpacing.s208 / 2,
  );

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: PetMotion.breath)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final treatment = PetStageTheme.treatment(widget.controller.growthStage);
    return Semantics(
      container: true,
      button: true,
      label: 'Touch ${widget.controller.state.petName}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _lastTapPosition = details.localPosition,
        onTap: () {
          widget.controller.touchPet(
            dx: _lastTapPosition.dx - PetSpacing.s192 / 2,
            dy: _lastTapPosition.dy - PetSpacing.s208 / 2,
          );
        },
        onLongPress: widget.controller.nuzzlePet,
        child: SizedBox(
          width: PetSpacing.s192,
          height: PetSpacing.s208,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _breath,
                  builder: (context, child) {
                    final eased = Curves.easeInOut.transform(_breath.value);
                    final isIdle = widget.controller.petAnimation == 'idle';
                    return Transform.translate(
                      offset: Offset(
                        PetSpacing.zero,
                        isIdle ? -PetSpacing.xxs * eased : PetSpacing.zero,
                      ),
                      child: Transform.scale(
                        scale:
                            treatment.spriteScale *
                            (isIdle
                                ? 1 + (PetMotion.breathScale - 1) * eased
                                : 1),
                        child: child,
                      ),
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: treatment.frameColor,
                        width: treatment.frameWidth,
                      ),
                      borderRadius: PetRadii.spriteBorder,
                    ),
                    child: PetSprite(
                      atlas: widget.controller.spriteAtlas,
                      stateName: widget.controller.petAnimation,
                      fixedFrame: widget.controller.petAnimationFrame,
                    ),
                  ),
                ),
              ),
              if (widget.controller.scheduleShowsZzz)
                const Positioned(
                  top: PetSpacing.s12,
                  right: PetSpacing.s10,
                  child: Text('zzz', style: PetTextStyles.body15Strong),
                ),
              if (widget.controller.momentParticle != null)
                Positioned(
                  key: ValueKey<int>(widget.controller.particleNonce),
                  top: PetSpacing.s8,
                  right: PetSpacing.s4,
                  child: Text(
                    widget.controller.momentParticle!,
                    style: PetTextStyles.display24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Decorations extends StatelessWidget {
  const _Decorations({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final unlocked = controller.decorations
        .where((item) => controller.state.unlockedDecorIds.contains(item.id))
        .toList(growable: false);
    const slots = <Offset>[
      Offset(2, 16),
      Offset(56, 25),
      Offset(112, 8),
      Offset(178, 24),
      Offset(236, 10),
      Offset(292, 20),
    ];
    return SizedBox(
      width: 336,
      height: PetSpacing.s52,
      child: Stack(
        children: unlocked
            .map((item) {
              final offset = slots[item.slot.clamp(0, slots.length - 1)];
              return Positioned(
                left: offset.dx,
                top: offset.dy,
                child: DecorItemView(decor: item, unlocked: true),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _TreatBar extends StatelessWidget {
  const _TreatBar({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      PetSpacing.s20,
      PetSpacing.zero,
      PetSpacing.s20,
      PetSpacing.s10,
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CollectionScreen(controller: controller),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Collection'),
          ),
        ),
        const SizedBox(width: PetSpacing.s10),
        Expanded(
          child: Semantics(
            button: true,
            enabled: controller.state.treats > 0,
            label:
                'Feed ${controller.state.petName}, ${controller.state.treats} ${controller.selectedPet.treatName}s available',
            child: FilledButton(
              onPressed: controller.state.treats > 0
                  ? () async {
                      final fed = await controller.feedTreat();
                      if (fed) await HapticFeedback.lightImpact();
                    }
                  : null,
              child: Text(
                '${controller.selectedPet.treatEmoji} Feed · ${controller.state.treats}',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.controller,
    required this.editing,
    required this.onToggleEditing,
    required this.onQuickAdd,
    required this.onEdit,
    required this.onRemove,
    required this.onHistory,
  });

  final AppController controller;
  final bool editing;
  final VoidCallback onToggleEditing;
  final VoidCallback? onQuickAdd;
  final ValueChanged<TodoTask> onEdit;
  final ValueChanged<TodoTask> onRemove;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      PetSpacing.s20,
      PetSpacing.zero,
      PetSpacing.s20,
      PetSpacing.s12,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: PetSpacing.s10),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  "Today's little things",
                  style: PetTextStyles.caption,
                ),
              ),
              IconButton(
                tooltip: 'Things we did together',
                onPressed: onHistory,
                icon: const Icon(Icons.favorite_outline_rounded),
              ),
              TextButton(
                onPressed: onToggleEditing,
                child: Text(editing ? 'Done' : 'Edit'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(top: PetSpacing.s4),
            itemCount: controller.state.tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: PetSpacing.s10),
            itemBuilder: (context, index) {
              final task = controller.state.tasks[index];
              return _TaskCard(
                title: task.title,
                note: task.note,
                kind: task.kind,
                hasReminder: task.reminder?.enabled ?? false,
                checked: task.completedToday,
                editing: editing,
                onEdit: () => onEdit(task),
                onRemove: () => onRemove(task),
                onTap: () async {
                  final completed = await controller.completeTask(task.id);
                  if (completed) await HapticFeedback.mediumImpact();
                },
              );
            },
          ),
        ),
        const SizedBox(height: PetSpacing.s8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onQuickAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              onQuickAdd == null
                  ? 'Seven little things are plenty for now'
                  : editing
                  ? 'Add one little thing'
                  : 'Jot it down',
            ),
          ),
        ),
      ],
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.title,
    required this.note,
    required this.kind,
    required this.hasReminder,
    required this.checked,
    required this.editing,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
  });

  final String title;
  final String? note;
  final TaskKind kind;
  final bool hasReminder;
  final bool checked;
  final bool editing;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // excludeSemantics strips the inner InkWell's tap action, so the card node
    // must advertise the action itself or assistive tech can't activate it.
    final VoidCallback? effectiveTap = editing
        ? onEdit
        : checked
        ? null
        : onTap;
    return Semantics(
      container: true,
      button: true,
      label: title,
      excludeSemantics: !editing,
      enabled: editing || !checked,
      checked: checked,
      onTap: effectiveTap,
      child: AnimatedContainer(
        duration: PetMotion.task,
        constraints: const BoxConstraints(minHeight: PetSpacing.s78),
        decoration: BoxDecoration(
          color: checked ? PetColors.doneFill : PetColors.white,
          borderRadius: PetRadii.cardBorder,
          boxShadow: checked ? PetShadows.taskDone : PetShadows.task,
        ),
        child: Material(
          color: PetColors.transparent,
          borderRadius: PetRadii.cardBorder,
          child: InkWell(
            onTap: editing
                ? onEdit
                : checked
                ? null
                : onTap,
            borderRadius: PetRadii.cardBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PetSpacing.s20,
                vertical: PetSpacing.s17,
              ),
              child: Row(
                children: <Widget>[
                  ExcludeSemantics(
                    child: AnimatedContainer(
                      duration: PetMotion.task,
                      width: PetSpacing.s44,
                      height: PetSpacing.s44,
                      decoration: BoxDecoration(
                        color: checked
                            ? PetColors.primary
                            : PetColors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: checked ? PetColors.primary : PetColors.stroke,
                          width: PetSpacing.stroke,
                        ),
                      ),
                      child: checked
                          ? const Icon(
                              Icons.check_rounded,
                              size: PetSpacing.s24,
                              color: PetColors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: PetSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: checked
                              ? PetTextStyles.task.copyWith(
                                  color: PetColors.accentText,
                                )
                              : PetTextStyles.task,
                        ),
                        if (note != null) ...<Widget>[
                          const SizedBox(height: PetSpacing.xs),
                          Text(note!, style: PetTextStyles.small),
                        ],
                        if (kind == TaskKind.oneOff || hasReminder) ...<Widget>[
                          const SizedBox(height: PetSpacing.xs),
                          Text(
                            [
                              if (kind == TaskKind.oneOff) 'Just once',
                              if (hasReminder) 'Gentle reminder',
                            ].join(' · '),
                            style: PetTextStyles.small,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (editing) ...<Widget>[
                    IconButton(
                      tooltip: 'Edit $title',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove $title',
                      onPressed: onRemove,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns its own text controller: disposing one right after `showDialog`
/// resolves tears it down while the route is still animating out and the
/// TextField still depends on it.
class _QuickAddDialog extends StatefulWidget {
  const _QuickAddDialog();

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _keep() {
    final value = _field.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Jot it down'),
    content: TextField(
      controller: _field,
      autofocus: true,
      maxLength: 60,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        hintText: 'A thought before it slips away',
      ),
      onSubmitted: (_) => _keep(),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Not now'),
      ),
      FilledButton(onPressed: _keep, child: const Text('Keep it')),
    ],
  );
}

class _UnlockBanner extends StatelessWidget {
  const _UnlockBanner({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final unlock = controller.activeUnlock;
    return AnimatedSlide(
      duration: PetMotion.unlockSlide,
      curve: Curves.easeOut,
      offset: unlock == null ? const Offset(PetSpacing.zero, -2) : Offset.zero,
      child: AnimatedOpacity(
        duration: PetMotion.unlockSlide,
        opacity: unlock == null ? PetSpacing.zero : PetEffects.fullOpacity,
        child: IgnorePointer(
          ignoring: unlock == null,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(
                PetSpacing.s22,
                PetSpacing.s52,
                PetSpacing.s22,
                PetSpacing.zero,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: PetSpacing.s18,
                vertical: PetSpacing.s14,
              ),
              decoration: const BoxDecoration(
                color: PetColors.white,
                borderRadius: PetRadii.bannerBorder,
                boxShadow: PetShadows.banner,
              ),
              child: Row(
                children: <Widget>[
                  if (unlock != null)
                    ExcludeSemantics(
                      child: DecorItemView(
                        decor: controller.decorations.firstWhere(
                          (item) => item.id == unlock.id,
                        ),
                        unlocked: true,
                      ),
                    ),
                  const SizedBox(width: PetSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'New keepsake · ${unlock?.name ?? ''} is here!',
                          style: PetTextStyles.body15Strong.copyWith(
                            color: PetColors.display,
                          ),
                        ),
                        const SizedBox(height: PetSpacing.xxs),
                        Text(
                          'It lives beside ${controller.state.petName} forever',
                          style: PetTextStyles.small,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LittleTheater extends StatelessWidget {
  const _LittleTheater({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: PetMotion.fade,
    opacity: controller.theaterVisible
        ? PetEffects.fullOpacity
        : PetSpacing.zero,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: PetEffects.theaterGradientCenter,
          colors: <Color>[PetColors.theaterCenter, PetColors.theaterEdge],
        ),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: _TwinkleField()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  controller.hatchCeremonyPetName == null
                      ? '· LITTLE THEATER ·'
                      : '· A NEW FRIEND ADOPTED ·',
                  style: PetTextStyles.theaterLabel,
                ),
                const SizedBox(height: PetSpacing.s16),
                ExcludeSemantics(
                  child: SizedBox(
                    width: PetSpacing.s192,
                    height: PetSpacing.s208,
                    child: PetSprite(
                      atlas: controller.spriteAtlas,
                      stateName: 'review',
                    ),
                  ),
                ),
                const SizedBox(height: PetSpacing.s16),
                SizedBox(
                  width: PetSpacing.s280,
                  child: Text(
                    controller.hatchCeremonyPetName == null
                        ? '${controller.state.petName} nuzzles you happily — thank you for today'
                        : 'Welcome, ${controller.hatchCeremonyPetName}. Your little companion is here with you.',
                    style: PetTextStyles.theaterLine,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: PetSpacing.s20),
                _PrimaryButton(
                  label: controller.hatchCeremonyPetName == null
                      ? 'Thank you, ${controller.state.petName}'
                      : 'Welcome home, ${controller.state.petName}',
                  onTap: controller.dismissTheater,
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: PetColors.primary,
        borderRadius: PetRadii.pillBorder,
        boxShadow: PetShadows.theaterButton,
      ),
      child: Material(
        color: PetColors.transparent,
        borderRadius: PetRadii.pillBorder,
        child: InkWell(
          borderRadius: PetRadii.pillBorder,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? PetSpacing.s32 : PetSpacing.s20,
              vertical: PetSpacing.s13,
            ),
            child: Text(label, style: PetTextStyles.button16),
          ),
        ),
      ),
    ),
  );
}

class _TwinkleField extends StatefulWidget {
  const _TwinkleField();

  @override
  State<_TwinkleField> createState() => _TwinkleFieldState();
}

class _TwinkleFieldState extends State<_TwinkleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: PetMotion.twinkle)
      ..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, _) =>
        CustomPaint(painter: _StarPainter(_animation.value)),
  );
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = PetColors.theaterLabel;
    for (var index = 0; index < 20; index++) {
      final phase = (progress + index * PetEffects.twinklePhaseStep) % 1;
      paint.color = PetColors.theaterLabel.withValues(
        alpha:
            PetEffects.twinkleMinimum +
            PetEffects.twinkleRange *
                (PetEffects.twinkleMidpoint -
                    (phase - PetEffects.twinkleMidpoint).abs()) *
                PetSpacing.xxs,
      );
      final x = (index * 73 % 337) / 337 * size.width;
      final y = (index * 127 % 691) / 691 * size.height;
      canvas.drawCircle(Offset(x, y), PetSpacing.xxs + (index % 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

String _dateGreeting(DateTime value) {
  const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final dayPart = value.hour < 12
      ? 'Lovely morning'
      : value.hour < 18
      ? 'Lovely afternoon'
      : 'Lovely evening';
  return '${weekdays[value.weekday - 1]}, ${months[value.month - 1]} ${value.day} · $dayPart';
}
