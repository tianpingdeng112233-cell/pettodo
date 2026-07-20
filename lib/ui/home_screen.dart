import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../data/event_log_store.dart';
import '../domain/unlocks.dart';
import '../sprite/pet_sprite.dart';
import 'settings_screen.dart';
import 'theme/app_theme.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_effects.dart';
import 'theme/pet_motion.dart';
import 'theme/pet_radii.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
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

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.controller, required this.eventLog});

  final AppController controller;
  final EventLogStore eventLog;

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
      Expanded(child: _PetStage(controller: controller)),
      _TaskList(controller: controller),
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
    final status = controller.petAnimation == 'jumping'
        ? '$name is hopping with joy!'
        : controller.state.allDone
        ? '$name is happy and full today~'
        : '$name is sunbathing, tail swishing softly';
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        height: PetSpacing.sunSize,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ExcludeSemantics(child: _BreathingSprite(controller: controller)),
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
              child: Text(name, style: PetTextStyles.display30),
            ),
            Transform.translate(
              offset: const Offset(PetSpacing.zero, -PetSpacing.s8),
              child: SizedBox(
                height: PetSpacing.s20,
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
            const SizedBox(height: PetSpacing.zero),
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
  Widget build(BuildContext context) => AnimatedBuilder(
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
          scale: isIdle ? 1 + (PetMotion.breathScale - 1) * eased : 1,
          child: child,
        ),
      );
    },
    child: SizedBox(
      width: PetSpacing.s192,
      height: PetSpacing.s208,
      child: PetSprite(
        atlas: widget.controller.spriteAtlas,
        stateName: widget.controller.petAnimation,
      ),
    ),
  );
}

class _Decorations extends StatelessWidget {
  const _Decorations({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final unlocked = decorUnlocks.where(
      (item) => controller.state.unlockedDecorIds.contains(item.id),
    );
    return SizedBox(
      height: PetSpacing.s36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: unlocked
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: PetSpacing.s8),
                child: _DecorShape(id: item.id, enabled: true),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.controller});

  final AppController controller;

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
        const Padding(
          padding: EdgeInsets.only(
            left: PetSpacing.s10,
            bottom: PetSpacing.s12,
          ),
          child: Text(
            "Today's three little things",
            style: PetTextStyles.caption,
          ),
        ),
        for (var index = 0; index < 3; index++) ...<Widget>[
          _TaskCard(
            title: controller.state.taskTitles[index],
            checked: controller.state.completedToday[index],
            onTap: () async {
              final completed = await controller.completeTask(index);
              if (completed) await HapticFeedback.mediumImpact();
            },
          ),
          if (index < 2) const SizedBox(height: PetSpacing.s12),
        ],
      ],
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.title,
    required this.checked,
    required this.onTap,
  });

  final String title;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: !checked,
    checked: checked,
    child: AnimatedContainer(
      duration: PetMotion.task,
      height: PetSpacing.s78,
      decoration: BoxDecoration(
        color: checked ? PetColors.doneFill : PetColors.white,
        borderRadius: PetRadii.cardBorder,
        boxShadow: checked ? PetShadows.taskDone : PetShadows.task,
      ),
      child: Material(
        color: PetColors.transparent,
        borderRadius: PetRadii.cardBorder,
        child: InkWell(
          onTap: checked ? null : onTap,
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
                  child: Text(
                    title,
                    style: checked
                        ? PetTextStyles.task.copyWith(
                            color: PetColors.accentText,
                          )
                        : PetTextStyles.task,
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
                  ExcludeSemantics(
                    child: _DecorShape(
                      id: unlock?.id ?? 'soft_ball',
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: PetSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'New keepsake · ${_decorName(unlock?.id)} is here!',
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
                const Text(
                  '· LITTLE THEATER ·',
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
                    '${controller.state.petName} nuzzles you happily — thank you for today',
                    style: PetTextStyles.theaterLine,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: PetSpacing.s20),
                _PrimaryButton(
                  label: 'Thank you, ${controller.state.petName}',
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

class _DecorShape extends StatelessWidget {
  const _DecorShape({required this.id, required this.enabled});

  final String id;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final opacity = enabled
        ? PetEffects.fullOpacity
        : PetEffects.upcomingDecorOpacity;
    if (id == 'flower') {
      return Opacity(
        opacity: opacity,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: PetColors.stroke,
            borderRadius: PetRadii.pillBorder,
          ),
          child: SizedBox(width: PetSpacing.s48, height: PetSpacing.s18),
        ),
      );
    }
    if (id == 'home') {
      return Opacity(
        opacity: opacity,
        child: const Icon(
          Icons.home_rounded,
          color: PetColors.decorHouse,
          size: PetSpacing.s36,
        ),
      );
    }
    return Opacity(
      opacity: opacity,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: PetEffects.ballHighlightCenter,
            colors: <Color>[PetColors.ballHighlight, PetColors.primary],
          ),
        ),
        child: SizedBox.square(dimension: PetSpacing.s34),
      ),
    );
  }
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

String _decorName(String? id) => switch (id) {
  'flower' => 'Cozy Cushion',
  'home' => 'Little House',
  _ => 'Bouncy Ball',
};

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
