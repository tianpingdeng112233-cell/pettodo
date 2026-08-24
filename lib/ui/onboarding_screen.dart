import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../sprite/pet_sprite.dart';
import '../sprite/sprite_atlas.dart';
import 'hatch_request_screen.dart';
import 'theme/app_theme.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_effects.dart';
import 'theme/pet_motion.dart';
import 'theme/pet_radii.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';

const List<String> _onboardingTasks = <String>[
  'Drink 8 cups of water',
  'Learn 20 new words',
  'Walk the dog',
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  late final TextEditingController _name;
  late final List<TextEditingController> _tasks;
  int _page = 0;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 20, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _tasks = _onboardingTasks
        .map((_) => TextEditingController())
        .toList(growable: false);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _pages.dispose();
    _name.dispose();
    for (final field in _tasks) {
      field.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _goTo(int page) {
    FocusScope.of(context).unfocus();
    _pages.animateToPage(page, duration: PetMotion.fade, curve: Curves.easeOut);
  }

  /// Opens the hatchery. A pack imported in there selects the new pet, so on
  /// return we offer its hatched name — without ever overwriting a name the
  /// user already typed.
  Future<void> _openHatchRequest() async {
    final before = widget.controller.state.selectedPetId;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HatchRequestScreen(controller: widget.controller),
      ),
    );
    if (!mounted) return;
    final after = widget.controller.state.selectedPetId;
    if (after != before && _name.text.trim().isEmpty) {
      _name.text = widget.controller.state.petName;
    }
    setState(() {});
  }

  Future<void> _finish(bool enableNotifications) async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.controller.completeOnboarding(
      selectedPetId: widget.controller.state.selectedPetId,
      petName: _name.text,
      taskTitles: List<String>.generate(
        3,
        (index) => _tasks[index].text.trim().isEmpty
            ? _onboardingTasks[index]
            : _tasks[index].text,
        growable: false,
      ),
      enableNotifications: enableNotifications,
      notificationHour: _notificationTime.hour,
      notificationMinute: _notificationTime.minute,
    );
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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.screenGradient),
        child: Stack(
          children: <Widget>[
            const _OnboardingHalo(),
            Column(
              children: <Widget>[
                const SizedBox(height: PetSpacing.s44),
                _StepHeader(
                  page: _page,
                  onBack: _page == 0 ? null : () => _goTo(_page - 1),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) => setState(() => _page = page),
                    children: <Widget>[
                      _ChoosePetPage(
                        controller: widget.controller,
                        onHatch: _openHatchRequest,
                        onNext: () => _goTo(1),
                      ),
                      _NamePage(
                        controller: widget.controller,
                        field: _name,
                        hint: _selectedPetName,
                        onNext: () => _goTo(2),
                      ),
                      _TasksPage(fields: _tasks, onNext: () => _goTo(3)),
                      _NotificationPage(
                        controller: widget.controller,
                        petName: _displayName,
                        time: _notificationTime,
                        saving: _saving,
                        onTime: (value) =>
                            setState(() => _notificationTime = value),
                        onEnable: () => _finish(true),
                        onSkip: () => _finish(false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  String get _selectedPetName => widget.controller.selectedPet.displayName;

  String get _displayName =>
      _name.text.trim().isEmpty ? _selectedPetName : _name.text.trim();
}

class _OnboardingHalo extends StatelessWidget {
  const _OnboardingHalo();

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

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.page, required this.onBack});

  final int page;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: PetSpacing.s40,
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        if (onBack != null)
          Positioned(
            left: PetSpacing.s20,
            child: Semantics(
              container: true,
              child: IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: PetColors.bodySoft,
                ),
              ),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(
            4,
            (index) => Container(
              width: PetSpacing.s8,
              height: PetSpacing.s8,
              margin: const EdgeInsets.symmetric(horizontal: PetSpacing.s4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index <= page ? PetColors.primary : PetColors.inactive,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChoosePetPage extends StatelessWidget {
  const _ChoosePetPage({
    required this.controller,
    required this.onHatch,
    required this.onNext,
  });

  final AppController controller;
  final VoidCallback onHatch;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      PetSpacing.s28,
      PetSpacing.zero,
      PetSpacing.s28,
      PetSpacing.s26,
    ),
    child: Column(
      children: <Widget>[
        Expanded(
          child: _ScrollableOnboardingContent(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _OnboardingSprite(controller: controller, state: 'idle'),
                const SizedBox(height: PetSpacing.s13),
                Text(
                  "Hi, I'm ${controller.selectedPet.displayName}!",
                  style: PetTextStyles.display26,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PetSpacing.s8),
                const Text(
                  "Start with three little things —\nI'll be right here with you",
                  style: PetTextStyles.body15Soft,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PetSpacing.s18),
                for (final pet in controller.pets) ...<Widget>[
                  _PetChoice(
                    controller: controller,
                    pet: pet,
                    selected: pet.id == controller.state.selectedPetId,
                  ),
                  const SizedBox(height: PetSpacing.s10),
                ],
                _FuturePetChoice(controller: controller, onTap: onHatch),
              ],
            ),
          ),
        ),
        _OnboardingButton(label: "That's the one", onTap: onNext),
      ],
    ),
  );
}

class _PetChoice extends StatelessWidget {
  const _PetChoice({
    required this.controller,
    required this.pet,
    required this.selected,
  });

  final AppController controller;
  final PetAssetDescriptor pet;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    enabled: true,
    checked: selected,
    label: pet.displayName,
    onTap: () => controller.selectPet(pet.id),
    child: GestureDetector(
      onTap: () => controller.selectPet(pet.id),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PetSpacing.s18,
          vertical: PetSpacing.s13,
        ),
        decoration: BoxDecoration(
          color: PetColors.white,
          border: Border.all(
            color: selected ? PetColors.primary : PetColors.stroke,
            width: selected ? PetSpacing.stroke : PetSpacing.xxs,
          ),
          borderRadius: PetRadii.cardSmallBorder,
          boxShadow: selected ? PetShadows.petChoice : null,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: PetSpacing.s44,
              height: PetSpacing.s48,
              child: FutureBuilder<LoadedSpriteAtlas>(
                future: controller.petAtlas(pet),
                builder: (context, snapshot) => snapshot.hasData
                    // Still frame: a list of looping pets is visual noise.
                    ? PetSprite(atlas: snapshot.data!, fixedFrame: 0)
                    : const Icon(
                        Icons.pets_rounded,
                        color: PetColors.inactive,
                      ),
              ),
            ),
            const SizedBox(width: PetSpacing.s14),
            Expanded(
              child: Text(
                pet.displayName,
                style: PetTextStyles.body16Strong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected)
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: PetColors.primary,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: PetSpacing.s26,
                  child: Icon(
                    Icons.check_rounded,
                    size: PetSpacing.s16,
                    color: PetColors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _FuturePetChoice extends StatelessWidget {
  const _FuturePetChoice({required this.controller, required this.onTap});

  final AppController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: true,
      checked: false,
      label: "Adopt your own pet from photos",
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PetSpacing.s18,
            vertical: PetSpacing.s13,
          ),
          decoration: BoxDecoration(
            color: PetColors.futureCard,
            border: Border.all(
              color: PetColors.disabledBorder,
              width: PetSpacing.xxs,
            ),
            borderRadius: PetRadii.cardSmallBorder,
          ),
          child: Row(
            children: <Widget>[
              const ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: PetColors.disabledFill,
                    borderRadius: PetRadii.spriteBorder,
                  ),
                  child: SizedBox(
                    width: PetSpacing.s44,
                    height: PetSpacing.s48,
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: PetColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: PetSpacing.s14),
              const Expanded(
                child: Text(
                  "Adopt your own pet from photos",
                  style: PetTextStyles.body15Strong,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PetSpacing.s10,
                  vertical: PetSpacing.s4,
                ),
                decoration: const BoxDecoration(
                  color: PetColors.badgeFill,
                  borderRadius: PetRadii.pillBorder,
                ),
                child: Text(
                  controller.pendingHatchRequest == null
                      ? '1–5 photos'
                      : 'Waiting warmly',
                  style: PetTextStyles.soon,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  const _NamePage({
    required this.controller,
    required this.field,
    required this.hint,
    required this.onNext,
  });

  final AppController controller;
  final TextEditingController field;
  final String hint;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _OnboardingFrame(
    button: _OnboardingButton(label: "That's my name!", onTap: onNext),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _OnboardingSprite(controller: controller, state: 'idle'),
        const SizedBox(height: PetSpacing.s14),
        const Text('What will you call me?', style: PetTextStyles.display26),
        const SizedBox(height: PetSpacing.s8),
        const Text('Any name makes me happy', style: PetTextStyles.body15Soft),
        const SizedBox(height: PetSpacing.s20),
        TextField(
          controller: field,
          maxLength: 20,
          textAlign: TextAlign.center,
          style: PetTextStyles.body17,
          decoration: InputDecoration(hintText: hint, counterText: ''),
        ),
      ],
    ),
  );
}

class _TasksPage extends StatelessWidget {
  const _TasksPage({required this.fields, required this.onNext});

  final List<TextEditingController> fields;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _OnboardingFrame(
    button: _OnboardingButton(label: 'These three!', onTap: onNext),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text(
          'Which 3 little things will we do?',
          style: PetTextStyles.display26,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PetSpacing.s14),
        const Text(
          'Keep them tiny — change them anytime',
          style: PetTextStyles.body15Soft,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PetSpacing.s22),
        for (var index = 0; index < 3; index++) ...<Widget>[
          TextField(
            controller: fields[index],
            maxLength: 40,
            style: PetTextStyles.body17,
            decoration: InputDecoration(
              hintText: _onboardingTasks[index],
              counterText: '',
            ),
          ),
          if (index < 2) const SizedBox(height: PetSpacing.s12),
        ],
      ],
    ),
  );
}

class _NotificationPage extends StatelessWidget {
  const _NotificationPage({
    required this.controller,
    required this.petName,
    required this.time,
    required this.saving,
    required this.onTime,
    required this.onEnable,
    required this.onSkip,
  });

  final AppController controller;
  final String petName;
  final TimeOfDay time;
  final bool saving;
  final ValueChanged<TimeOfDay> onTime;
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => _OnboardingFrame(
    button: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _OnboardingButton(
          label: saving
              ? 'Getting our little home ready…'
              : 'Sure! See you at ${_formatTime(time)}',
          onTap: saving ? null : onEnable,
        ),
        const SizedBox(height: PetSpacing.s12),
        Semantics(
          container: true,
          child: TextButton(
            onPressed: saving ? null : onSkip,
            child: const Text(
              "Not now, I'll come find you",
              style: PetTextStyles.secondaryLink,
            ),
          ),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _OnboardingSprite(controller: controller, state: 'idle'),
        const SizedBox(height: PetSpacing.s14),
        const Text(
          'May I say hi in the evening?',
          style: PetTextStyles.display24,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PetSpacing.s8),
        const Text(
          'Just because I miss you — never to rush',
          style: PetTextStyles.body15Soft,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PetSpacing.s18),
        Wrap(
          spacing: PetSpacing.s10,
          children: <Widget>[
            for (final hour in <int>[19, 20, 21])
              _TimeChip(
                time: TimeOfDay(hour: hour, minute: 0),
                selected: time.hour == hour && time.minute == 0,
                onTap: onTime,
              ),
          ],
        ),
        const SizedBox(height: PetSpacing.s12),
        const Text(
          "Turn it off anytime — I won't mind",
          style: PetTextStyles.disabledSmall,
        ),
      ],
    ),
  );
}

class _OnboardingFrame extends StatelessWidget {
  const _OnboardingFrame({required this.child, required this.button});

  final Widget child;
  final Widget button;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      PetSpacing.s28,
      PetSpacing.zero,
      PetSpacing.s28,
      PetSpacing.s26,
    ),
    child: Column(
      children: <Widget>[
        Expanded(child: _ScrollableOnboardingContent(child: child)),
        button,
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
  const _OnboardingSprite({required this.controller, required this.state});

  final AppController controller;
  final String state;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: PetSpacing.s150,
      height: PetSpacing.s162,
      child: PetSprite(
        atlas: controller.spriteAtlas,
        stateName: state,
        fixedFrame: 0,
      ),
    ),
  );
}

class _OnboardingButton extends StatelessWidget {
  const _OnboardingButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null
        ? PetEffects.disabledButtonOpacity
        : PetEffects.fullOpacity,
    child: Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: PetColors.primary,
          borderRadius: PetRadii.pillBorder,
          boxShadow: PetShadows.primaryButton,
        ),
        child: Material(
          color: PetColors.transparent,
          borderRadius: PetRadii.pillBorder,
          child: InkWell(
            onTap: onTap,
            borderRadius: PetRadii.pillBorder,
            child: SizedBox(
              height: PetSpacing.s54,
              child: Center(child: Text(label, style: PetTextStyles.button)),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.time,
    required this.selected,
    required this.onTap,
  });

  final TimeOfDay time;
  final bool selected;
  final ValueChanged<TimeOfDay> onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    checked: selected,
    child: InkWell(
      borderRadius: PetRadii.pillBorder,
      onTap: () => onTap(time),
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
          _formatTime(time),
          style: selected
              ? PetTextStyles.chip.copyWith(color: PetColors.white)
              : PetTextStyles.chip,
        ),
      ),
    ),
  );
}

String _formatTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}
