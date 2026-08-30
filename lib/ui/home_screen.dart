import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../data/event_log_store.dart';
import '../domain/app_state.dart';
import '../domain/bond.dart';
import '../domain/furniture.dart';
import '../domain/furniture_migration.dart';
import '../domain/onboarding_flow.dart';
import '../domain/task_grouping.dart';
import '../sprite/pet_sprite.dart';
import '../sprite/rig_pet_sprite.dart';
import 'collection_screen.dart';
import 'focus_screen.dart';
import 'history_screen.dart';
import 'hatch_request_screen.dart';
import 'pet_date_format.dart';
import 'settings_screen.dart';
import 'snacks_screen.dart';
import 'store_screen.dart';
import 'task_editor_sheet.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_effects.dart';
import 'theme/pet_motion.dart';
import 'theme/pixel_background.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_stage_theme.dart';
import 'theme/pet_text_styles.dart';
import 'theme/stair_border.dart';
import 'widgets/pixel_components.dart';
import 'widgets/pixel_icon.dart';
import 'widgets/furniture_item_view.dart';
import 'widgets/bond_progress_bar.dart';
import 'widgets/treat_count.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.eventLog,
    this.now,
    this.visualTestMode = false,
  });

  final AppController controller;
  final EventLogStore eventLog;
  final DateTime? now;
  final bool visualTestMode;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: PetColors.transparent,
      systemNavigationBarColor: PetColors.screenBottom,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      body: PixelBackground(
        showHalo: true,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: _HomeContent(
                controller: controller,
                eventLog: eventLog,
                now: now,
                visualTestMode: visualTestMode,
              ),
            ),
            _UnlockBanner(controller: controller),
            if (controller.eveningHelloVisible)
              _EveningHelloBubble(controller: controller),
            if (controller.theaterVisible)
              _LittleTheater(controller: controller),
          ],
        ),
      ),
    ),
  );
}

class _HomeContent extends StatefulWidget {
  const _HomeContent({
    required this.controller,
    required this.eventLog,
    required this.now,
    required this.visualTestMode,
  });

  final AppController controller;
  final EventLogStore eventLog;
  final DateTime? now;
  final bool visualTestMode;

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  bool _editing = false;
  Timer? _comingUpBoundaryTimer;

  AppController get controller => widget.controller;
  EventLogStore get eventLog => widget.eventLog;

  @override
  void initState() {
    super.initState();
    _scheduleComingUpBoundary();
  }

  @override
  void didUpdateWidget(covariant _HomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleComingUpBoundary();
  }

  @override
  void dispose() {
    _comingUpBoundaryTimer?.cancel();
    super.dispose();
  }

  void _scheduleComingUpBoundary() {
    _comingUpBoundaryTimer?.cancel();
    if (widget.now != null) return;
    final now = DateTime.now();
    final futureTimes = groupTasksForHome(controller.state.tasks, now: now)
        .comingUp
        .map((task) => task.reminder!.scheduledAt!)
        .toList(growable: false);
    if (futureTimes.isEmpty) return;
    _comingUpBoundaryTimer = Timer(
      futureTimes.first.difference(now) + const Duration(milliseconds: 1),
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleComingUpBoundary();
      },
    );
  }

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
      scheduledAt: draft.reminderScheduledAt,
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
    final reminderSaved = await controller.editTask(
      taskId: task.id,
      title: draft.title,
      kind: draft.kind,
      note: draft.note,
      reminderSelection: TaskReminderSelection(
        enabled: draft.reminderEnabled,
        hour: draft.reminderTime.hour,
        minute: draft.reminderTime.minute,
        scheduledAt: draft.reminderScheduledAt,
      ),
    );
    if (!mounted) return;
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
                  _dateGreeting(widget.now ?? DateTime.now()),
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
                    child: PxIcon(
                      PxIconData.sliders,
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
      Flexible(
        flex: 4,
        child: _PetStage(
          controller: controller,
          visualTestMode: widget.visualTestMode,
        ),
      ),
      _TreatBar(controller: controller),
      if (!widget.visualTestMode)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PetSpacing.s20,
            PetSpacing.s8,
            PetSpacing.s20,
            PetSpacing.s8,
          ),
          child: SizedBox(
            width: double.infinity,
            child: PxButton(
              height: 48,
              style: PxButtonStyle.outline,
              icon: const PxIcon(PxIconData.clock, size: PetSpacing.s18),
              label: Text('Focus with ${controller.state.petName}'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FocusScreen(controller: controller),
                ),
              ),
            ),
          ),
        ),
      Flexible(
        flex: 5,
        child: _TaskList(
          controller: controller,
          now: widget.now ?? DateTime.now(),
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

class _PetStage extends StatelessWidget {
  const _PetStage({required this.controller, required this.visualTestMode});

  final AppController controller;
  final bool visualTestMode;

  @override
  Widget build(BuildContext context) {
    final name = controller.state.petName;
    final status = visualTestMode
        ? '$name is having a cozy little nap'
        : controller.statusLine;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _RoomScene(controller: controller, visualTestMode: visualTestMode),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(name, style: PetTextStyles.display30),
                const SizedBox(width: PetSpacing.s8),
                DecoratedBox(
                  decoration: const ShapeDecoration(
                    color: PetColors.badgeFill,
                    shape: StairBorder.small(),
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
            const SizedBox(height: PetSpacing.s6),
            SizedBox(
              width: 250,
              child: Row(
                children: <Widget>[
                  DecoratedBox(
                    decoration: const ShapeDecoration(
                      color: PetColors.primary,
                      shape: StairBorder.small(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PetSpacing.s8,
                        vertical: PetSpacing.s4,
                      ),
                      child: Text(
                        'Lv ${bondLevelForXp(controller.state.bondXp)}',
                        style: PetTextStyles.small.copyWith(
                          color: PetColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: PetSpacing.s8),
                  Expanded(
                    child: BondProgressBar(
                      value: bondProgressForXp(controller.state.bondXp),
                      highlightStart: controller.bondProgressHighlightStart,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PetSpacing.s4),
            Text(
              bondTitleForLevel(bondLevelForXp(controller.state.bondXp)),
              style: PetTextStyles.caption,
            ),
            const SizedBox(height: PetSpacing.s4),
            SizedBox(
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
            if (controller.pendingHatchRequest != null)
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label:
                    'Your pet is on its way — no rush. Open adoption request',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HatchRequestScreen(controller: controller),
                  ),
                ),
                child: InkWell(
                  customBorder: const StairBorder.small(),
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
                      '🐾  Your pet is on its way — no rush.  Open ›',
                      style: PetTextStyles.small,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomScene extends StatelessWidget {
  const _RoomScene({required this.controller, required this.visualTestMode});

  final AppController controller;
  final bool visualTestMode;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    height: 220,
    child: DecoratedBox(
      decoration: const ShapeDecoration(
        color: Color(0xFFFFF1DA),
        shape: StairBorder.large(
          side: BorderSide(color: PetColors.stroke, width: 2),
        ),
      ),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: StairBorder.large()),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            const Positioned.fill(
              bottom: 62,
              child: ColoredBox(color: Color(0xFFFFE8C8)),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 64,
              child: ColoredBox(color: Color(0xFFD8B080)),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              height: 6,
              child: ColoredBox(color: Color(0xFFB9865B)),
            ),
            _RoomFurnitureLayer(controller: controller),
            const Positioned(
              left: 95,
              bottom: 14,
              child: PxGroundBar(width: 170, height: 20),
            ),
            Positioned(
              left: 108,
              top: 38,
              child: SizedBox(
                width: 144,
                height: 156,
                child: FittedBox(
                  child: _BreathingSprite(
                    controller: controller,
                    visualTestMode: visualTestMode,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BreathingSprite extends StatefulWidget {
  const _BreathingSprite({
    required this.controller,
    required this.visualTestMode,
  });

  final AppController controller;
  final bool visualTestMode;

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
        onLongPressStart: (details) {
          _lastTapPosition = details.localPosition;
          widget.controller.nuzzlePet(
            dx: _lastTapPosition.dx - PetSpacing.s192 / 2,
            dy: _lastTapPosition.dy - PetSpacing.s208 / 2,
          );
        },
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
                    final isIdle =
                        !widget.controller.selectedPet.isRig &&
                        (widget.visualTestMode ||
                            widget.controller.petAnimation == 'idle');
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
                    decoration: ShapeDecoration(
                      color: PetColors.inputFill,
                      shape: StairBorder.large(
                        side: BorderSide(
                          color: treatment.frameColor,
                          width: treatment.frameWidth,
                        ),
                      ),
                    ),
                    child: widget.controller.selectedPet.isRig
                        ? RigPetSprite(
                            key: ValueKey<(String, int)>((
                              widget.controller.selectedPet.id,
                              widget.controller.rigAnimationNonce,
                            )),
                            pet: widget.controller.rigPet!,
                            action: widget.controller.rigAction,
                            target: widget.controller.rigTarget,
                            fixedElapsed: widget.visualTestMode
                                ? Duration.zero
                                : null,
                          )
                        : PetSprite(
                            atlas: widget.controller.spriteAtlas,
                            stateName: widget.visualTestMode
                                ? 'idle'
                                : widget.controller.petAnimation,
                            fixedFrame: widget.visualTestMode
                                ? 0
                                : widget.controller.petAnimationFrame,
                          ),
                  ),
                ),
              ),
              if (widget.controller.scheduleShowsZzz && !widget.visualTestMode)
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

class _RoomFurnitureLayer extends StatelessWidget {
  const _RoomFurnitureLayer({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final placed = controller.state.placedFurnitureBySlot.values
        .map(furnitureById)
        .whereType<FurnitureItem>()
        .toList(growable: false);
    return Stack(
      children: placed
          .map((item) {
            final placement = _roomSlotPlacements[item.slot]!;
            final alternatives = furnitureCatalog
                .where(
                  (candidate) =>
                      candidate.slot == item.slot &&
                      controller.state.ownedFurnitureIds.contains(candidate.id),
                )
                .toList(growable: false);
            return Positioned(
              left: placement.left,
              top: placement.top,
              bottom: placement.bottom,
              child: Semantics(
                button: alternatives.length > 1,
                label: alternatives.length > 1
                    ? '${item.name}. Double tap to switch this slot'
                    : item.name,
                child: GestureDetector(
                  onTap: alternatives.length > 1
                      ? () async {
                          final current = alternatives.indexWhere(
                            (candidate) => candidate.id == item.id,
                          );
                          final next =
                              alternatives[(current + 1) % alternatives.length];
                          await controller.placeFurniture(next.id);
                        }
                      : null,
                  child: FurnitureItemView(
                    item: item,
                    manifest: controller.roomAssets,
                    scale: placement.scale,
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

/// Per-slot placement, proportioned against the ~150px pet (integer scales
/// keep pixels crisp): tall pieces read near pet height, seats/beds below it,
/// wall pieces sized to the wall band. Floor items anchor by their bottoms.
typedef _SlotPlacement = ({
  double left,
  double? top,
  double? bottom,
  int scale,
});

const Map<FurnitureSlot, _SlotPlacement> _roomSlotPlacements =
    <FurnitureSlot, _SlotPlacement>{
      FurnitureSlot.window: (left: 10, top: 12, bottom: null, scale: 2),
      FurnitureSlot.wallArt: (left: 150, top: 8, bottom: null, scale: 2),
      FurnitureSlot.wallClock: (left: 300, top: 14, bottom: null, scale: 2),
      FurnitureSlot.bookshelf: (left: 6, top: null, bottom: 52, scale: 2),
      FurnitureSlot.bed: (left: 6, top: null, bottom: 12, scale: 2),
      FurnitureSlot.rug: (left: 116, top: null, bottom: 8, scale: 3),
      FurnitureSlot.toy: (left: 92, top: null, bottom: 6, scale: 2),
      FurnitureSlot.floorLamp: (left: 300, top: null, bottom: 40, scale: 2),
      FurnitureSlot.plant: (left: 308, top: null, bottom: 44, scale: 2),
      FurnitureSlot.rockingChair: (left: 272, top: null, bottom: 6, scale: 2),
    };

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
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CollectionScreen(controller: controller),
              ),
            ),
            child: const Text('Collection'),
          ),
        ),
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StoreScreen(controller: controller),
              ),
            ),
            child: const Text('Shop'),
          ),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Open snacks, ${controller.state.treats} treats',
            child: PxButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SnacksScreen(controller: controller),
                ),
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('Snacks '),
                    TreatCount('${controller.state.treats}', iconSize: 14),
                  ],
                ),
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
    required this.now,
    required this.editing,
    required this.onToggleEditing,
    required this.onQuickAdd,
    required this.onEdit,
    required this.onRemove,
    required this.onHistory,
  });

  final AppController controller;
  final DateTime now;
  final bool editing;
  final VoidCallback onToggleEditing;
  final VoidCallback? onQuickAdd;
  final ValueChanged<TodoTask> onEdit;
  final ValueChanged<TodoTask> onRemove;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final groups = groupTasksForHome(controller.state.tasks, now: now);
    Widget taskCard(TodoTask task, {DateTime? scheduledAt}) => _TaskCard(
      title: task.title,
      note: task.note,
      kind: task.kind,
      firstWin: isFirstWinTask(task),
      hasReminder:
          task.reminder?.enabled == true && task.reminder?.isDaily == true,
      scheduledAt: scheduledAt,
      checked: task.completedToday,
      editing: editing,
      onEdit: () => onEdit(task),
      onRemove: () => onRemove(task),
      onTap: () async {
        final completed = await controller.completeTask(task.id);
        if (completed) await HapticFeedback.mediumImpact();
      },
    );

    final listChildren = <Widget>[
      for (final (index, task) in groups.regular.indexed) ...<Widget>[
        if (index > 0) const SizedBox(height: PetSpacing.s10),
        taskCard(task),
      ],
      if (groups.comingUp.isNotEmpty) ...<Widget>[
        if (groups.regular.isNotEmpty) const SizedBox(height: PetSpacing.s20),
        Padding(
          padding: const EdgeInsets.only(
            left: PetSpacing.s10,
            bottom: PetSpacing.s8,
          ),
          child: Row(
            children: <Widget>[
              const PxIcon(
                PxIconData.calendar,
                size: PetSpacing.s16,
                color: PetColors.caption,
              ),
              const SizedBox(width: PetSpacing.s6),
              const Text('Coming up', style: PetTextStyles.caption),
            ],
          ),
        ),
        for (final (index, task) in groups.comingUp.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: PetSpacing.s10),
          taskCard(task, scheduledAt: task.reminder!.scheduledAt),
        ],
      ],
    ];

    return Padding(
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
                  icon: const PxIcon(PxIconData.heart),
                ),
                TextButton(
                  onPressed: onToggleEditing,
                  child: Text(editing ? 'Done' : 'Edit'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: PetSpacing.s4),
              children: listChildren,
            ),
          ),
          const SizedBox(height: PetSpacing.s8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onQuickAdd,
              icon: const PxIcon(PxIconData.plus, size: PetSpacing.s18),
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
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.title,
    required this.note,
    required this.kind,
    required this.firstWin,
    required this.hasReminder,
    required this.scheduledAt,
    required this.checked,
    required this.editing,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
  });

  final String title;
  final String? note;
  final TaskKind kind;
  final bool firstWin;
  final bool hasReminder;
  final DateTime? scheduledAt;
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
      label: scheduledAt == null
          ? title
          : '$title, ${formatTimedReminder(scheduledAt!)}',
      excludeSemantics: !editing,
      enabled: editing || !checked,
      checked: checked,
      onTap: effectiveTap,
      child: AnimatedContainer(
        duration: PetMotion.task,
        constraints: const BoxConstraints(minHeight: PetSpacing.s78),
        decoration: ShapeDecoration(
          color: checked ? PetColors.doneFill : PetColors.white,
          shape: StairBorder.large(
            side: BorderSide(
              color: checked || firstWin ? PetColors.primary : PetColors.stroke,
              width: firstWin ? 3 : 2,
            ),
          ),
          shadows: checked || firstWin ? PetShadows.taskDone : PetShadows.task,
        ),
        child: Material(
          color: PetColors.transparent,
          shape: const StairBorder.large(),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: editing
                ? onEdit
                : checked
                ? null
                : onTap,
            customBorder: const StairBorder.large(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PetSpacing.s20,
                vertical: PetSpacing.s17,
              ),
              child: Row(
                children: <Widget>[
                  ExcludeSemantics(child: PxCheckbox(checked: checked)),
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
                        if (scheduledAt != null) ...<Widget>[
                          const SizedBox(height: PetSpacing.s6),
                          _TimedReminderBadge(scheduledAt: scheduledAt!),
                        ],
                        if (!firstWin &&
                            scheduledAt == null &&
                            (kind == TaskKind.oneOff ||
                                hasReminder)) ...<Widget>[
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
                  if (firstWin && !editing)
                    const PxIcon(
                      PxIconData.sparkle,
                      size: PetSpacing.s22,
                      color: PetColors.accentText,
                    ),
                  if (editing) ...<Widget>[
                    IconButton(
                      tooltip: 'Edit $title',
                      onPressed: onEdit,
                      icon: const PxIcon(PxIconData.edit),
                    ),
                    IconButton(
                      tooltip: 'Remove $title',
                      onPressed: onRemove,
                      icon: const PxIcon(PxIconData.minus),
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

class _TimedReminderBadge extends StatelessWidget {
  const _TimedReminderBadge({required this.scheduledAt});

  final DateTime scheduledAt;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(
      color: PetColors.badgeFill,
      shape: StairBorder.small(),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PetSpacing.s8,
        vertical: PetSpacing.s4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const PxIcon(
            PxIconData.clock,
            size: PetSpacing.s13,
            color: PetColors.accentText,
          ),
          const SizedBox(width: PetSpacing.s5),
          Text(
            formatTimedReminder(scheduledAt),
            style: PetTextStyles.caption.copyWith(color: PetColors.accentText),
          ),
        ],
      ),
    ),
  );
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

class _EveningHelloBubble extends StatelessWidget {
  const _EveningHelloBubble({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Positioned(
    left: PetSpacing.s24,
    right: PetSpacing.s24,
    top: 282,
    child: Semantics(
      container: true,
      label: 'Evening hello invitation',
      child: PxCard(
        padding: const EdgeInsets.all(PetSpacing.s16),
        shadows: PetShadows.banner,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'May I say hi in the evening?',
              style: PetTextStyles.body16Strong,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PetSpacing.s4),
            const Text(
              "Just a little news from my day — never a nudge",
              style: PetTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PetSpacing.s12),
            PxButton(
              height: PetSpacing.s48,
              label: Text(
                'Sure! See you at ${_homeTime(controller.state.notificationHour, controller.state.notificationMinute)}',
                style: PetTextStyles.button16,
              ),
              onPressed: () => controller.respondToEveningHello(true),
            ),
            TextButton(
              onPressed: () => controller.respondToEveningHello(false),
              child: const Text(
                "Not now, I'll come find you",
                style: PetTextStyles.secondaryLink,
              ),
            ),
            const SizedBox(height: PetSpacing.s4),
            const Text(
              "Turn it off anytime — I won't mind",
              style: PetTextStyles.disabledSmall,
            ),
          ],
        ),
      ),
    ),
  );
}

String _homeTime(int hour24, int minute) {
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final suffix = hour24 < 12 ? 'AM' : 'PM';
  return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
}

class _UnlockBanner extends StatelessWidget {
  const _UnlockBanner({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final unlock = controller.activeUnlock;
    final furnitureId = unlock == null
        ? null
        : legacyDecorToFurnitureIds[unlock.id];
    final furniture = furnitureId == null ? null : furnitureById(furnitureId);
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
              decoration: const ShapeDecoration(
                color: PetColors.white,
                shape: StairBorder.large(
                  side: BorderSide(color: PetColors.stroke, width: 2),
                ),
                shadows: PetShadows.banner,
              ),
              child: Row(
                children: <Widget>[
                  if (furniture != null)
                    ExcludeSemantics(
                      child: FurnitureItemView(
                        item: furniture,
                        manifest: controller.roomAssets,
                      ),
                    ),
                  const SizedBox(width: PetSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'New furniture · ${furniture?.name ?? ''}',
                          style: PetTextStyles.body15Strong.copyWith(
                            color: PetColors.display,
                          ),
                        ),
                        const SizedBox(height: PetSpacing.xxs),
                        Text(
                          'Placed in ${controller.state.petName}\'s room',
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

enum _TheaterType { bond, daily, hatch }

class _LittleTheater extends StatelessWidget {
  const _LittleTheater({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final bondLevel = controller.bondCelebrationLevel;
    final hatchPetName = controller.hatchCeremonyPetName;
    final theaterType = bondLevel != null
        ? _TheaterType.bond
        : hatchPetName != null
        ? _TheaterType.hatch
        : _TheaterType.daily;
    final (heading, message, actionLabel) = switch (theaterType) {
      _TheaterType.bond => (
        '· BOND GREW ·',
        'You and ${controller.state.petName} grew a little closer.',
        'Continue',
      ),
      _TheaterType.daily => (
        '· LITTLE THEATER ·',
        '${controller.state.petName} nuzzles you happily — thank you for today',
        'Thank you, ${controller.state.petName}',
      ),
      _TheaterType.hatch => (
        '· A NEW FRIEND ADOPTED ·',
        'Welcome, $hatchPetName. Your little companion is here with you.',
        'Welcome home, ${controller.state.petName}',
      ),
    };
    return AnimatedOpacity(
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
                  Text(heading, style: PetTextStyles.theaterLabel),
                  const SizedBox(height: PetSpacing.s16),
                  ExcludeSemantics(
                    child: SizedBox(
                      width: PetSpacing.s192,
                      height: PetSpacing.s208,
                      child: controller.selectedPet.isRig
                          ? RigPetSprite(
                              pet: controller.rigPet!,
                              action: controller.rigAction,
                            )
                          : PetSprite(
                              atlas: controller.spriteAtlas,
                              stateName: 'review',
                            ),
                    ),
                  ),
                  const SizedBox(height: PetSpacing.s16),
                  if (bondLevel != null) ...<Widget>[
                    Text(
                      'Bond Lv $bondLevel',
                      style: PetTextStyles.display30.copyWith(
                        color: PetColors.theaterText,
                      ),
                    ),
                    const SizedBox(height: PetSpacing.s10),
                    DecoratedBox(
                      decoration: const ShapeDecoration(
                        color: PetColors.badgeFill,
                        shape: StairBorder.small(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PetSpacing.s12,
                          vertical: PetSpacing.s5,
                        ),
                        child: Text(
                          bondTitleForLevel(bondLevel),
                          style: PetTextStyles.chip.copyWith(
                            color: PetColors.accentText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: PetSpacing.s12),
                  ],
                  SizedBox(
                    width: PetSpacing.s280,
                    child: Text(
                      message,
                      style: PetTextStyles.theaterLine,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (bondLevel != null) ...<Widget>[
                    const SizedBox(height: PetSpacing.s16),
                    SizedBox(
                      width: 250,
                      child: BondProgressBar(
                        value: bondProgressForXp(controller.state.bondXp),
                      ),
                    ),
                  ],
                  const SizedBox(height: PetSpacing.s20),
                  _PrimaryButton(
                    label: actionLabel,
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
  Widget build(BuildContext context) => PxButton(
    label: Text(label, style: PetTextStyles.button16),
    onPressed: onTap,
    compact: compact,
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
    const colors = <Color>[
      PetColors.primary,
      PetColors.ballHighlight,
      PetColors.confettiMint,
      PetColors.confettiBlue,
      PetColors.confettiPink,
    ];
    final paint = Paint();
    for (var index = 0; index < 20; index++) {
      final phase = (progress + index * PetEffects.twinklePhaseStep) % 1;
      paint.color = colors[index % colors.length].withValues(
        alpha:
            PetEffects.twinkleMinimum +
            PetEffects.twinkleRange *
                (PetEffects.twinkleMidpoint -
                    (phase - PetEffects.twinkleMidpoint).abs()) *
                PetSpacing.xxs,
      );
      final x = (index * 73 % 337) / 337 * size.width;
      final y = (index * 127 % 691) / 691 * size.height;
      final side = PetSpacing.xxs + (index % 3);
      canvas.drawRect(Rect.fromLTWH(x, y, side, side), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

String _dateGreeting(DateTime value) {
  final dayPart = value.hour < 12
      ? 'Lovely morning'
      : value.hour < 18
      ? 'Lovely afternoon'
      : 'Lovely evening';
  return '${formatShortDate(value)} · $dayPart';
}
