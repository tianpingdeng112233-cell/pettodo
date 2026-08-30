import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../domain/onboarding_flow.dart';
import '../sprite/pet_sprite.dart';
import '../sprite/rig_pet.dart';
import '../sprite/rig_pet_sprite.dart';
import '../sprite/sprite_atlas.dart';
import 'hatch_request_screen.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_motion.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';
import 'theme/pixel_background.dart';
import 'theme/stair_border.dart';
import 'widgets/pixel_components.dart';
import 'widgets/pixel_icon.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.controller,
    this.initialStep = OnboardingStep.choosePet,
    this.showStayOnScreen,
    this.initialSelectedThingIndexes = const <int>{},
    this.random,
  });

  final AppController controller;

  /// Deterministic seams used by the five 393pt golden baselines.
  final OnboardingStep initialStep;
  final bool? showStayOnScreen;
  final Set<int> initialSelectedThingIndexes;
  final math.Random? random;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final List<OnboardingStep> _steps;
  late final PageController _pages;
  late final TextEditingController _name;
  late final math.Random _random;
  late OnboardingStep _step;
  late Set<int> _selectedThings;
  String? _customThing;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final forceStay = widget.showStayOnScreen;
    _steps = onboardingSteps(
      isAndroid: forceStay ?? defaultTargetPlatform == TargetPlatform.android,
      overlaySupported: forceStay ?? widget.controller.overlaySupported,
    );
    final requestedIndex = _steps.indexOf(widget.initialStep);
    final initialIndex = requestedIndex < 0 ? 0 : requestedIndex;
    _step = _steps[initialIndex];
    _pages = PageController(initialPage: initialIndex);
    _name = TextEditingController(
      text: widget.controller.selectedPet.displayName,
    );
    _random = widget.random ?? math.Random();
    _selectedThings = <int>{
      ...widget.initialSelectedThingIndexes.where(
        (index) => index >= 0 && index < onboardingThings.length,
      ),
    }.take(onboardingThingLimit).toSet();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _goTo(OnboardingStep step) {
    final index = _steps.indexOf(step);
    if (index < 0) return;
    if (step == OnboardingStep.namePet) _prefillNameIfUntouched();
    FocusScope.of(context).unfocus();
    _pages.animateToPage(
      index,
      duration: PetMotion.fade,
      curve: Curves.easeOut,
    );
  }

  /// Prefill belongs to entering the naming step, not to the selection tap:
  /// it reads whatever pet is current at that moment and never overwrites a
  /// name the user typed themselves.
  void _prefillNameIfUntouched() {
    final current = _name.text.trim();
    final untouched =
        current.isEmpty ||
        widget.controller.pets.any((pet) => pet.displayName == current) ||
        current == widget.controller.state.petName;
    if (untouched) {
      _name.text = widget.controller.selectedPet.displayName;
    }
  }

  Future<void> _selectPet(PetAssetDescriptor pet) async {
    await widget.controller.selectPet(pet.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openHatchRequest() async {
    final before = widget.controller.state.selectedPetId;
    final beforeName = widget.controller.selectedPet.displayName;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HatchRequestScreen(controller: widget.controller),
      ),
    );
    if (!mounted) return;
    final after = widget.controller.state.selectedPetId;
    if (after != before &&
        (_name.text.trim().isEmpty || _name.text.trim() == beforeName)) {
      _name.text = widget.controller.state.petName;
    }
    setState(() {});
  }

  void _rollName() {
    final next = suggestedPetName(
      pool: <String>{
        ...onboardingNamePool,
        ...widget.controller.pets.map((pet) => pet.displayName),
      }.toList(growable: false),
      current: _displayName,
      roll: _random.nextInt(1 << 31),
    );
    _name.text = next;
    _name.selection = TextSelection.collapsed(offset: next.length);
    setState(() {});
  }

  void _toggleThing(int index) {
    setState(() {
      _selectedThings = toggleOnboardingThing(_selectedThings, index);
    });
  }

  Future<void> _editCustomThing() async {
    if (_customThing != null) {
      setState(() => _customThing = null);
      return;
    }
    if (_selectionCount == onboardingThingLimit) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _CustomThingDialog(),
    );
    if (!mounted || result == null || result.trim().isEmpty) return;
    setState(() => _customThing = result.trim());
  }

  Future<void> _prepareRoutine() async {
    if (_saving || _selectionCount == 0) return;
    setState(() => _saving = true);
    await widget.controller.prepareOnboarding(
      selectedPetId: widget.controller.state.selectedPetId,
      petName: _displayName,
      taskTitles: _selectedTaskTitles,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _goTo(OnboardingStep.celebrate);
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.controller.finishOnboarding();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _enableOverlayAndFinish() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.controller.setOverlayEnabled(true);
    await widget.controller.finishOnboarding();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: PetColors.transparent,
      systemNavigationBarColor: PetColors.screenBottom,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      body: PixelBackground(
        showHalo:
            _step == OnboardingStep.namePet ||
            _step == OnboardingStep.celebrate,
        child: PageView(
          controller: _pages,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => setState(() => _step = _steps[index]),
          children: _steps.map(_buildStep).toList(growable: false),
        ),
      ),
    ),
  );

  Widget _buildStep(OnboardingStep step) => switch (step) {
    OnboardingStep.choosePet => _ChoosePetPage(
      controller: widget.controller,
      onSelect: _selectPet,
      onHatch: _openHatchRequest,
      onNext: () => _goTo(OnboardingStep.namePet),
    ),
    OnboardingStep.namePet => _NamePage(
      controller: widget.controller,
      field: _name,
      displayName: _displayName,
      onChanged: (_) => setState(() {}),
      onRoll: _rollName,
      onNext: () => _goTo(OnboardingStep.littleThings),
    ),
    OnboardingStep.littleThings => _LittleThingsPage(
      controller: widget.controller,
      selected: _selectedThings,
      customThing: _customThing,
      saving: _saving,
      onToggle: _toggleThing,
      onCustom: _editCustomThing,
      onNext: _prepareRoutine,
    ),
    OnboardingStep.celebrate => _CelebratePage(
      controller: widget.controller,
      saving: _saving,
      onNext: _steps.contains(OnboardingStep.stayOnScreen)
          ? () => _goTo(OnboardingStep.stayOnScreen)
          : _finish,
    ),
    OnboardingStep.stayOnScreen => _StayOnScreenPage(
      controller: widget.controller,
      petName: _displayName,
      saving: _saving,
      onEnable: _enableOverlayAndFinish,
      onSkip: _finish,
    ),
  };

  String get _displayName {
    final value = _name.text.trim();
    return value.isEmpty ? widget.controller.selectedPet.displayName : value;
  }

  int get _selectionCount =>
      _selectedThings.length + (_customThing == null ? 0 : 1);

  List<String> get _selectedTaskTitles {
    final indexes = _selectedThings.toList()..sort();
    return <String>[
      ...indexes.map((index) => onboardingThings[index].taskTitle),
      if (_customThing != null) '✏️ $_customThing',
    ];
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots(this.step);

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) => Row(
    children: List<Widget>.generate(
      onboardingProgressStepCount,
      (index) => Padding(
        padding: EdgeInsets.only(right: index == 3 ? 0 : PetSpacing.s6),
        child: Container(
          width: PetSpacing.s26,
          height: PetSpacing.s8,
          decoration: ShapeDecoration(
            color: index <= onboardingProgressIndex(step)
                ? PetColors.primary
                : PetColors.inactive,
            shape: const StairBorder.small(),
          ),
        ),
      ),
    ),
  );
}

class _ChoosePetPage extends StatelessWidget {
  const _ChoosePetPage({
    required this.controller,
    required this.onSelect,
    required this.onHatch,
    required this.onNext,
  });

  final AppController controller;
  final ValueChanged<PetAssetDescriptor> onSelect;
  final VoidCallback onHatch;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _PageShell(
    progress: const _ProgressDots(OnboardingStep.choosePet),
    button: PxButton(label: const Text("That's the one"), onPressed: onNext),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text("Who's coming home?", style: PetTextStyles.display26),
        const SizedBox(height: PetSpacing.s6),
        Text(
          // The roster grows as preset pets land; the line must never claim
          // more friends than the registry actually holds.
          controller.pets.length == 1
              ? 'A little friend is waiting — take your time'
              : '${controller.pets.length} little friends are waiting '
                    '— take your time',
          style: PetTextStyles.body15Soft,
        ),
        const SizedBox(height: PetSpacing.s18),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: PetSpacing.s10,
          mainAxisSpacing: PetSpacing.s10,
          childAspectRatio: 0.98,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: controller.pets
              .map(
                (pet) => _PetChoice(
                  controller: controller,
                  pet: pet,
                  selected: pet.id == controller.state.selectedPetId,
                  onTap: () => onSelect(pet),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: PetSpacing.s14),
        _OwnPetEntry(onTap: onHatch),
      ],
    ),
  );
}

class _PetChoice extends StatelessWidget {
  const _PetChoice({
    required this.controller,
    required this.pet,
    required this.selected,
    required this.onTap,
  });

  final AppController controller;
  final PetAssetDescriptor pet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    checked: selected,
    label: pet.displayName,
    onTap: onTap,
    child: GestureDetector(
      onTap: onTap,
      child: PxCard(
        selected: selected,
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 6),
        shadows: selected ? PetShadows.petChoice : PetShadows.task,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: PetSpacing.s64,
              height: 69,
              child: FutureBuilder<Object>(
                future: pet.isRig
                    ? controller.petRig(pet)
                    : controller.petAtlas(pet),
                builder: (context, snapshot) {
                  final visual = snapshot.data;
                  if (visual is LoadedRigPet) {
                    return RigPetSprite(
                      pet: visual,
                      fixedElapsed: Duration.zero,
                    );
                  }
                  if (visual is LoadedSpriteAtlas) {
                    // Still frame: a list of looping pets is visual noise.
                    return PetSprite(atlas: visual, fixedFrame: 0);
                  }
                  return const PxIcon(
                    PxIconData.paw,
                    color: PetColors.inactive,
                  );
                },
              ),
            ),
            const SizedBox(height: PetSpacing.s4),
            Text(
              pet.displayName,
              style: PetTextStyles.caption.copyWith(
                color: selected ? PetColors.accentText : PetColors.body,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

class _OwnPetEntry extends StatelessWidget {
  const _OwnPetEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label:
        'Your real pet can live here too — from your photos, unlockable anytime',
    onTap: onTap,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PetSpacing.s16,
          vertical: PetSpacing.s12,
        ),
        decoration: const ShapeDecoration(
          color: PetColors.futureCard,
          shape: StairBorder.large(),
        ),
        child: const Row(
          children: <Widget>[
            PxIcon(PxIconData.paw, size: 26, color: PetColors.systemIcon),
            SizedBox(width: PetSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Your real pet can live here too',
                    style: PetTextStyles.body15Strong,
                  ),
                  Text(
                    'From your photos — unlockable anytime',
                    style: PetTextStyles.captionSoft,
                  ),
                ],
              ),
            ),
            PxIcon(
              PxIconData.chevronRight,
              size: PetSpacing.s16,
              color: PetColors.systemIcon,
            ),
          ],
        ),
      ),
    ),
  );
}

class _NamePage extends StatelessWidget {
  const _NamePage({
    required this.controller,
    required this.field,
    required this.displayName,
    required this.onChanged,
    required this.onRoll,
    required this.onNext,
  });

  final AppController controller;
  final TextEditingController field;
  final String displayName;
  final ValueChanged<String> onChanged;
  final VoidCallback onRoll;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _PageShell(
    horizontalPadding: PetSpacing.s28,
    progress: const _ProgressDots(OnboardingStep.namePet),
    button: PxButton(
      label: Text('Nice to meet you, $displayName'),
      onPressed: onNext,
    ),
    child: Column(
      children: <Widget>[
        const SizedBox(height: PetSpacing.s40),
        _OnboardingSprite(controller: controller, width: 172, height: 186),
        const SizedBox(height: PetSpacing.s18),
        const PxCard(
          padding: EdgeInsets.symmetric(
            horizontal: PetSpacing.s18,
            vertical: PetSpacing.s14,
          ),
          shadows: <BoxShadow>[],
          child: Text(
            'Thanks for choosing me!\nWhat will you call me?',
            style: PetTextStyles.body16,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: PetSpacing.s30),
        SizedBox(
          height: PetSpacing.s58,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: PxInput(
                  controller: field,
                  maxLength: 20,
                  textAlign: TextAlign.start,
                  style: PetTextStyles.task.copyWith(fontSize: 20),
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: PetSpacing.s10),
              Semantics(
                button: true,
                label: 'Try another name',
                child: OutlinedButton(
                  onPressed: onRoll,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(PetSpacing.s54, PetSpacing.s54),
                    padding: EdgeInsets.zero,
                    shape: const StairBorder.small(
                      side: BorderSide(color: PetColors.stroke, width: 2),
                    ),
                  ),
                  child: const _PixelDie(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PetSpacing.s10),
        const Text(
          'Any name makes me happy — you can change it later',
          style: PetTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _PixelDie extends StatelessWidget {
  const _PixelDie();

  @override
  Widget build(BuildContext context) => Container(
    width: PetSpacing.s24,
    height: PetSpacing.s24,
    decoration: BoxDecoration(
      border: Border.all(color: PetColors.accentText, width: 2),
    ),
    child: const Stack(
      children: <Widget>[
        Positioned(left: 4, top: 4, child: _DieDot()),
        Positioned(right: 4, top: 4, child: _DieDot()),
        Positioned(left: 4, bottom: 4, child: _DieDot()),
        Positioned(right: 4, bottom: 4, child: _DieDot()),
      ],
    ),
  );
}

class _DieDot extends StatelessWidget {
  const _DieDot();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: PetColors.accentText,
    child: SizedBox.square(dimension: 3),
  );
}

class _LittleThingsPage extends StatelessWidget {
  const _LittleThingsPage({
    required this.controller,
    required this.selected,
    required this.customThing,
    required this.saving,
    required this.onToggle,
    required this.onCustom,
    required this.onNext,
  });

  final AppController controller;
  final Set<int> selected;
  final String? customThing;
  final bool saving;
  final ValueChanged<int> onToggle;
  final VoidCallback onCustom;
  final VoidCallback onNext;

  int get selectionCount => selected.length + (customThing == null ? 0 : 1);

  @override
  Widget build(BuildContext context) => _PageShell(
    progress: const _ProgressDots(OnboardingStep.littleThings),
    button: PxButton(
      label: Text(selectionCount == 0 ? 'Pick at least one' : 'These three!'),
      onPressed: selectionCount == 0 || saving ? null : onNext,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _OnboardingSprite(controller: controller, width: 86, height: 93),
            const SizedBox(width: PetSpacing.s14),
            const Expanded(
              child: PxCard(
                padding: EdgeInsets.symmetric(
                  horizontal: PetSpacing.s16,
                  vertical: PetSpacing.s12,
                ),
                shadows: <BoxShadow>[],
                child: Text(
                  'Which little things will we do together?',
                  style: PetTextStyles.body15Strong,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PetSpacing.s10),
        const Text(
          'Keep them tiny — pick up to three, change them anytime',
          style: PetTextStyles.caption,
        ),
        const SizedBox(height: PetSpacing.s18),
        for (final entry in onboardingThings.indexed) ...<Widget>[
          SizedBox(
            width: double.infinity,
            child: _ThingChip(
              emoji: entry.$2.emoji,
              label: entry.$2.label,
              selected: selected.contains(entry.$1),
              onTap: () => onToggle(entry.$1),
            ),
          ),
          const SizedBox(height: PetSpacing.s10),
        ],
        SizedBox(
          width: double.infinity,
          child: _ThingChip(
            emoji: '✏️',
            label: customThing ?? 'My own thing…',
            selected: customThing != null,
            muted: customThing == null,
            dashed: customThing == null,
            onTap: onCustom,
          ),
        ),
      ],
    ),
  );
}

class _ThingChip extends StatelessWidget {
  const _ThingChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
    this.muted = false,
    this.dashed = false,
  });

  final String emoji;
  final String label;
  final bool selected;
  final bool muted;
  final bool dashed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    checked: selected,
    label: label,
    onTap: onTap,
    child: PxChip(
      selected: selected,
      dashed: dashed,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Text(emoji),
          const SizedBox(width: PetSpacing.s10),
          Expanded(
            child: Text(
              label,
              style: muted
                  ? PetTextStyles.body16Strong.copyWith(
                      color: PetColors.bodySoft,
                    )
                  : PetTextStyles.body16Strong.copyWith(
                      color: selected ? PetColors.white : PetColors.bodyStrong,
                    ),
            ),
          ),
          if (selected) const PxCheckbox(checked: true),
        ],
      ),
    ),
  );
}

class _CelebratePage extends StatelessWidget {
  const _CelebratePage({
    required this.controller,
    required this.saving,
    required this.onNext,
  });

  final AppController controller;
  final bool saving;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      const Positioned(
        top: 150,
        left: 45,
        child: _Confetti(color: PetColors.primary),
      ),
      const Positioned(
        top: 122,
        right: 60,
        child: _Confetti(color: PetColors.decorHouse, size: 8),
      ),
      const Positioned(
        top: 245,
        right: 50,
        child: _Confetti(color: PetColors.ballHighlight, size: 12),
      ),
      const Positioned(
        top: 290,
        left: 38,
        child: _Confetti(color: PetColors.accentText, size: 8),
      ),
      const Positioned(
        top: 350,
        right: 72,
        child: _Confetti(color: PetColors.primary, size: 8),
      ),
      _PageShell(
        horizontalPadding: PetSpacing.s28,
        progress: const _ProgressDots(OnboardingStep.celebrate),
        button: PxButton(
          label: Text(
            saving ? 'Getting our little home ready…' : "Let's go home",
          ),
          onPressed: saving ? null : onNext,
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 70),
            _OnboardingSprite(
              controller: controller,
              state: 'jumping',
              fixedFrame: null,
              width: 200,
              height: 217,
            ),
            const SizedBox(height: PetSpacing.s26),
            const Text(
              'Our little routine\nis ready!',
              style: PetTextStyles.display28,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PetSpacing.s24),
            PxCard(
              fillColor: PetColors.doneFill,
              padding: const EdgeInsets.symmetric(
                horizontal: PetSpacing.s22,
                vertical: PetSpacing.s14,
              ),
              shadows: const <BoxShadow>[],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const PxIcon(
                    PxIconData.treat,
                    size: PetSpacing.s24,
                    color: PetColors.accentText,
                  ),
                  const SizedBox(width: PetSpacing.s10),
                  Flexible(
                    child: Text(
                      '+1 ${controller.selectedPet.treatName} — for getting us started',
                      style: PetTextStyles.body15Strong,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Confetti extends StatelessWidget {
  const _Confetti({required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: ShapeDecoration(color: color, shape: const StairBorder.small()),
  );
}

class _StayOnScreenPage extends StatelessWidget {
  const _StayOnScreenPage({
    required this.controller,
    required this.petName,
    required this.saving,
    required this.onEnable,
    required this.onSkip,
  });

  final AppController controller;
  final String petName;
  final bool saving;
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      PetSpacing.s28,
      PetSpacing.s64,
      PetSpacing.s28,
      PetSpacing.s26,
    ),
    child: Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PetSpacing.s12,
              vertical: PetSpacing.s4,
            ),
            decoration: const ShapeDecoration(
              color: PetColors.badgeFill,
              shape: StairBorder.small(),
            ),
            child: const Text('Android only', style: PetTextStyles.captionSoft),
          ),
        ),
        const SizedBox(height: PetSpacing.s30),
        _LauncherPreview(controller: controller),
        const SizedBox(height: PetSpacing.s26),
        const PxCard(
          padding: EdgeInsets.symmetric(
            horizontal: PetSpacing.s18,
            vertical: PetSpacing.s14,
          ),
          shadows: <BoxShadow>[],
          child: Text(
            'Can I stay on your screen\nwhile you go about your day?',
            style: PetTextStyles.body16,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: PetSpacing.s10),
        const Text(
          'No reminders from out there — just company.\nYou can change your mind in Settings.',
          style: PetTextStyles.caption,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        PxButton(
          label: Text(
            saving ? 'Opening your screen settings…' : 'Let $petName stay',
          ),
          onPressed: saving ? null : onEnable,
        ),
        const SizedBox(height: PetSpacing.s12),
        TextButton(
          onPressed: saving ? null : onSkip,
          child: const Text('Maybe later', style: PetTextStyles.secondaryLink),
        ),
      ],
    ),
  );
}

class _LauncherPreview extends StatelessWidget {
  const _LauncherPreview({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => PxCard(
    fillColor: PetColors.bodyStrong,
    borderColor: PetColors.bodyStrong,
    borderWidth: 3,
    padding: const EdgeInsets.all(3),
    shadows: const <BoxShadow>[],
    child: Container(
      width: 216,
      height: 342,
      color: const Color(0xFF2B2B33),
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: PetSpacing.s14,
            left: PetSpacing.s16,
            child: Text(
              'Tue, Aug 25',
              style: TextStyle(fontSize: 11, color: Color(0xFFCFCFD8)),
            ),
          ),
          Positioned(
            top: 60,
            left: 42,
            child: Row(
              children: List<Widget>.generate(
                3,
                (index) => Container(
                  width: PetSpacing.s30,
                  height: PetSpacing.s30,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8E8EC),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: PetSpacing.s24,
            bottom: 80,
            child: _OnboardingSprite(
              controller: controller,
              width: 96,
              height: 104,
            ),
          ),
          Positioned(
            left: PetSpacing.s18,
            right: PetSpacing.s18,
            bottom: PetSpacing.s24,
            child: Container(
              height: PetSpacing.s34,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8EC),
                borderRadius: BorderRadius.circular(PetSpacing.s17),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PageShell extends StatelessWidget {
  const _PageShell({
    required this.progress,
    required this.child,
    required this.button,
    this.horizontalPadding = PetSpacing.s24,
  });

  final Widget progress;
  final Widget child;
  final Widget button;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      horizontalPadding,
      PetSpacing.s64,
      horizontalPadding,
      PetSpacing.s26,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        progress,
        const SizedBox(height: PetSpacing.s22),
        Expanded(child: _ScrollableOnboardingContent(child: child)),
        const SizedBox(height: PetSpacing.s12),
        SizedBox(width: double.infinity, child: button),
      ],
    ),
  );
}

class _ScrollableOnboardingContent extends StatelessWidget {
  const _ScrollableOnboardingContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: child,
      ),
    ),
  );
}

class _OnboardingSprite extends StatelessWidget {
  const _OnboardingSprite({
    required this.controller,
    required this.width,
    required this.height,
    this.state = 'idle',
    this.fixedFrame = 0,
  });

  final AppController controller;
  final double width;
  final double height;
  final String state;
  final int? fixedFrame;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: height,
      child: controller.selectedPet.isRig
          ? RigPetSprite(pet: controller.rigPet!, fixedElapsed: Duration.zero)
          : PetSprite(
              atlas: controller.spriteAtlas,
              stateName: state,
              fixedFrame: fixedFrame,
            ),
    ),
  );
}

class _CustomThingDialog extends StatefulWidget {
  const _CustomThingDialog();

  @override
  State<_CustomThingDialog> createState() => _CustomThingDialogState();
}

class _CustomThingDialogState extends State<_CustomThingDialog> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _keep() {
    final value = _field.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('My own thing…'),
    content: PxInput(
      controller: _field,
      autofocus: true,
      maxLength: 40,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        hintText: 'One tiny thing',
        counterText: '',
      ),
      onSubmitted: (_) => _keep(),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Maybe later'),
      ),
      TextButton(onPressed: _keep, child: const Text('Keep this one')),
    ],
  );
}
