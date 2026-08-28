import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../data/event_log_store.dart';
import '../domain/accessory.dart';
import '../domain/app_state.dart';
import '../domain/furniture.dart';
import '../domain/furniture_migration.dart';
import '../domain/onboarding_flow.dart';
import '../sprite/pet_sprite.dart';
import '../sprite/rig_pet_sprite.dart';
import 'collection_screen.dart';
import 'history_screen.dart';
import 'hatch_request_screen.dart';
import 'settings_screen.dart';
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
import 'widgets/accessory_item_view.dart';

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

  Future<void> _showAccessories() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: PetColors.screenBottom,
    builder: (context) => _AccessorySheet(controller: widget.controller),
  );

  @override
  Widget build(BuildContext context) {
    final treatment = PetStageTheme.treatment(widget.controller.growthStage);
    return Semantics(
      container: true,
      button: true,
      label: 'Touch ${widget.controller.state.petName}, accessories',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _lastTapPosition = details.localPosition,
        onTap: _showAccessories,
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
                            accessories: widget.controller.equippedAccessories,
                            accessoryManifest: widget.controller.roomAssets,
                          )
                        : PetSprite(
                            atlas: widget.controller.spriteAtlas,
                            stateName: widget.visualTestMode
                                ? 'idle'
                                : widget.controller.petAnimation,
                            fixedFrame: widget.visualTestMode
                                ? 0
                                : widget.controller.petAnimationFrame,
                            accessories: widget.controller.equippedAccessories,
                            accessoryManifest: widget.controller.roomAssets,
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

class _AccessorySheet extends StatelessWidget {
  const _AccessorySheet({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final owned = accessoryCatalog
          .where((item) => controller.state.ownedAccessoryIds.contains(item.id))
          .toList(growable: false);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PetSpacing.s20,
            PetSpacing.s18,
            PetSpacing.s20,
            PetSpacing.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${controller.state.petName}\'s accessories',
                style: PetTextStyles.display24,
              ),
              const SizedBox(height: PetSpacing.s14),
              if (owned.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: PetSpacing.s20),
                  child: Text('Nothing worn', style: PetTextStyles.body15),
                )
              else
                for (final item in owned) ...<Widget>[
                  _AccessoryChoice(controller: controller, item: item),
                  const SizedBox(height: PetSpacing.s10),
                ],
            ],
          ),
        ),
      );
    },
  );
}

class _AccessoryChoice extends StatelessWidget {
  const _AccessoryChoice({required this.controller, required this.item});

  final AppController controller;
  final AccessoryItem item;

  @override
  Widget build(BuildContext context) {
    final equipped =
        controller.state.equippedAccessoryByAnchor[item.anchor.name] == item.id;
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: PetColors.white,
        shape: StairBorder.large(),
        shadows: PetShadows.panel,
      ),
      child: Padding(
        padding: const EdgeInsets.all(PetSpacing.s12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 112,
              height: 84,
              child: Center(
                child: AccessoryItemView(
                  item: item,
                  manifest: controller.roomAssets,
                ),
              ),
            ),
            const SizedBox(width: PetSpacing.s12),
            Expanded(child: Text(item.name, style: PetTextStyles.body15Strong)),
            PxButton(
              compact: true,
              height: PetSpacing.s44,
              style: equipped ? PxButtonStyle.outline : PxButtonStyle.primary,
              onPressed: () async {
                if (equipped) {
                  await controller.unequipAccessory(item.anchor);
                } else {
                  await controller.equipAccessory(item.id);
                }
              },
              label: Text(equipped ? 'Remove' : 'Wear'),
            ),
          ],
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
            final offset = _roomSlotOffsets[item.slot]!;
            final alternatives = furnitureCatalog
                .where(
                  (candidate) =>
                      candidate.slot == item.slot &&
                      controller.state.ownedFurnitureIds.contains(candidate.id),
                )
                .toList(growable: false);
            return Positioned(
              left: offset.dx,
              top: offset.dy,
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
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

const Map<FurnitureSlot, Offset> _roomSlotOffsets = <FurnitureSlot, Offset>{
  FurnitureSlot.window: Offset(18, 18),
  FurnitureSlot.wallArt: Offset(145, 30),
  FurnitureSlot.wallClock: Offset(305, 24),
  FurnitureSlot.bed: Offset(22, 178),
  FurnitureSlot.rug: Offset(150, 194),
  FurnitureSlot.bookshelf: Offset(4, 102),
  FurnitureSlot.floorLamp: Offset(286, 102),
  FurnitureSlot.plant: Offset(328, 174),
  FurnitureSlot.toy: Offset(82, 186),
  FurnitureSlot.rockingChair: Offset(308, 158),
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
            enabled: controller.state.treats > 0,
            label:
                'Feed ${controller.state.petName}, ${controller.state.treats} ${controller.selectedPet.treatName}s available',
            child: PxButton(
              onPressed: controller.state.treats > 0
                  ? () async {
                      final fed = await controller.feedTreat();
                      if (fed) await HapticFeedback.lightImpact();
                    }
                  : null,
              icon: const PxIcon(
                PxIconData.bone,
                size: PetSpacing.s20,
                color: PetColors.white,
              ),
              label: Text('Feed · ${controller.state.treats}'),
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
                firstWin: isFirstWinTask(task),
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.title,
    required this.note,
    required this.kind,
    required this.firstWin,
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
  final bool firstWin;
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
                        if (!firstWin &&
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
      final side = PetSpacing.xxs + (index % 3);
      canvas.drawRect(Rect.fromLTWH(x, y, side, side), paint);
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
