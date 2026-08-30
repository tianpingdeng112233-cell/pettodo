import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../application/focus_session_controller.dart';
import '../domain/app_state.dart';
import '../domain/focus_economy.dart';
import 'focus_complete_screen.dart';
import 'focus_pet.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';
import 'theme/pixel_background.dart';
import 'theme/stair_border.dart';
import 'widgets/pixel_components.dart';
import 'widgets/pixel_icon.dart';
import 'widgets/treat_count.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  int _durationMinutes = 25;
  String? _taskId;
  FocusSessionController? _session;
  bool _openingCompletion = false;

  TodoTask? get _selectedTask {
    final taskId = _taskId;
    if (taskId == null) return null;
    return widget.controller.state.taskById(taskId);
  }

  void _start() {
    final session = widget.controller.createFocusSession(
      durationMinutes: _durationMinutes,
      taskId: _taskId,
    );
    session.addListener(_onSessionChanged);
    _session = session;
    session.start();
  }

  void _onSessionChanged() {
    final session = _session;
    if (session?.state != FocusSessionState.completed || _openingCompletion) {
      if (mounted) setState(() {});
      return;
    }
    _openingCompletion = true;
    final completion = session!.completion!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => FocusCompleteScreen(
            controller: widget.controller,
            completion: completion,
          ),
        ),
      );
    });
  }

  Future<void> _chooseTask() async {
    final tasks = widget.controller.state.tasks
        .where((task) => !task.isComplete)
        .toList(growable: false);
    final selection = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            PetSpacing.s20,
            PetSpacing.s8,
            PetSpacing.s20,
            PetSpacing.s20,
          ),
          children: <Widget>[
            const Text(
              'What are you focusing on?',
              style: PetTextStyles.display24,
            ),
            const SizedBox(height: PetSpacing.s12),
            ListTile(
              title: const Text('Nothing in particular'),
              onTap: () => Navigator.of(context).pop(''),
            ),
            for (final task in tasks)
              ListTile(
                title: Text(task.title),
                subtitle: Text(
                  task.kind == TaskKind.daily ? 'Today' : 'One-off',
                ),
                onTap: () => Navigator.of(context).pop(task.id),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;
    setState(() => _taskId = selection.isEmpty ? null : selection);
  }

  void _abandon() {
    final session = _session;
    final wasActive =
        session != null &&
        (session.state == FocusSessionState.running ||
            session.state == FocusSessionState.paused);
    session?.abandon();
    if (wasActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "That's plenty for now. "
            '${widget.controller.state.petName} loved being with you.',
          ),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _session
      ?..removeListener(_onSessionChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_session == null) {
          Navigator.of(context).pop();
        } else {
          _abandon();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Focus', style: PetTextStyles.display24),
          backgroundColor: PetColors.transparent,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _session == null
                ? () => Navigator.of(context).maybePop()
                : _abandon,
            icon: const PxIcon(PxIconData.back),
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: PetSpacing.s16),
              child: Center(
                child: _TreatChip(amount: widget.controller.state.treats),
              ),
            ),
          ],
        ),
        body: PixelBackground(
          showHalo: true,
          child: _session == null ? _buildSetup() : _buildRunning(_session!),
        ),
      ),
    ),
  );

  Widget _buildSetup() {
    final drop = treatDropForFocus(_durationMinutes);
    final task = _selectedTask;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        PetSpacing.s20,
        PetSpacing.s8,
        PetSpacing.s20,
        PetSpacing.s24,
      ),
      child: Column(
        children: <Widget>[
          FocusPet(
            controller: widget.controller,
            pose: FocusPetPose.awake,
            size: 136,
          ),
          Text(
            '“Want to focus for a bit? I’ll nap right beside you~”',
            style: PetTextStyles.body16Strong,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PetSpacing.s18),
          PxCard(
            padding: const EdgeInsets.fromLTRB(
              PetSpacing.s18,
              PetSpacing.s14,
              PetSpacing.s18,
              PetSpacing.s14,
            ),
            child: Column(
              children: <Widget>[
                Text('$_durationMinutes', style: _numberStyle(44)),
                const Text('minutes', style: PetTextStyles.body15Soft),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: PetColors.primary,
                    inactiveTrackColor: PetColors.stroke,
                    trackHeight: 8,
                    trackShape: const RectangularSliderTrackShape(),
                    thumbColor: PetColors.white,
                    overlayColor: PetColors.ghostFill,
                    thumbShape: const _SquareSliderThumb(),
                    tickMarkShape: SliderTickMarkShape.noTickMark,
                  ),
                  child: Slider(
                    value: _durationMinutes.toDouble(),
                    min: 5,
                    max: 45,
                    divisions: 8,
                    semanticFormatterCallback: (value) =>
                        '${value.round()} minutes',
                    onChanged: (value) =>
                        setState(() => _durationMinutes = value.round()),
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('5', style: PetTextStyles.small),
                    Text('15', style: PetTextStyles.small),
                    Text('25', style: PetTextStyles.small),
                    Text('35', style: PetTextStyles.small),
                    Text('45', style: PetTextStyles.small),
                  ],
                ),
                const SizedBox(height: PetSpacing.s8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Finish to earn ',
                      style: PetTextStyles.captionSoft,
                    ),
                    TreatCount(
                      '$drop',
                      style: PetTextStyles.captionSoft,
                      iconSize: 14,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: PetSpacing.s20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Focusing on something? (totally optional)',
              style: PetTextStyles.caption,
            ),
          ),
          const SizedBox(height: PetSpacing.s8),
          PxCard(
            small: true,
            padding: const EdgeInsets.symmetric(
              horizontal: PetSpacing.s16,
              vertical: PetSpacing.s14,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    task?.title ?? 'Choose a little thing',
                    style: task == null
                        ? PetTextStyles.body15Soft
                        : PetTextStyles.body15Strong,
                  ),
                ),
                TextButton(
                  onPressed: _chooseTask,
                  child: Text(task == null ? 'Choose' : 'Change'),
                ),
              ],
            ),
          ),
          const SizedBox(height: PetSpacing.s24),
          SizedBox(
            width: double.infinity,
            child: PxButton(
              label: const Text('Start focusing'),
              onPressed: _start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunning(FocusSessionController session) {
    final totalSeconds = (session.remaining.inMilliseconds / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final task = _selectedTask;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PetSpacing.s24,
          PetSpacing.s24,
          PetSpacing.s24,
          PetSpacing.s28,
        ),
        child: Column(
          children: <Widget>[
            Text(
              '${minutes.toString().padLeft(2, '0')}:'
              '${seconds.toString().padLeft(2, '0')}',
              style: _numberStyle(76),
            ),
            Text(
              'of ${session.durationMinutes} minutes',
              style: PetTextStyles.body15Soft,
            ),
            if (task != null) ...<Widget>[
              const SizedBox(height: PetSpacing.s14),
              _TaskChip(title: task.title),
            ],
            const Spacer(),
            FocusPet(
              controller: widget.controller,
              pose: FocusPetPose.napping,
              size: 210,
            ),
            const _FloatingZzz(),
            const SizedBox(height: PetSpacing.s8),
            const Text(
              'If you leave, I’ll pause for you',
              style: PetTextStyles.body15Soft,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: _DashedEscapeButton(
                label: const Text('That’s enough for now'),
                onPressed: _abandon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _numberStyle(double size) => TextStyle(
  fontFamily: PetTextStyles.bodyFamily,
  fontFamilyFallback: PetTextStyles.bodyFallback,
  fontSize: size,
  height: 1,
  fontWeight: FontWeight.w700,
  color: PetColors.bodyStrong,
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

class _TreatChip extends StatelessWidget {
  const _TreatChip({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: PetColors.badgeFill,
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PetSpacing.s10,
        vertical: PetSpacing.s5,
      ),
      child: Text('🦴 $amount', style: PetTextStyles.chip),
    ),
  );
}

class _TaskChip extends StatelessWidget {
  const _TaskChip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: PetColors.badgeFill,
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PetSpacing.s12,
        vertical: PetSpacing.s6,
      ),
      child: Text('Working on “$title”', style: PetTextStyles.chip),
    ),
  );
}

class _FloatingZzz extends StatelessWidget {
  const _FloatingZzz();

  // V1 freeze (David 2026-08-30): static glyphs, no drift animation.
  @override
  Widget build(BuildContext context) => Text(
    'z  z  z',
    style: PetTextStyles.display24.copyWith(color: PetColors.bodySoft),
  );
}

class _SquareSliderThumb extends SliderComponentShape {
  const _SquareSliderThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    const size = 20.0;
    final rect = Rect.fromCenter(center: center, width: size, height: size);
    canvas.drawRect(rect, Paint()..color = PetColors.white);
    canvas.drawRect(
      rect.deflate(1),
      Paint()
        ..color = PetColors.accentText
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..isAntiAlias = false,
    );
  }
}

class _DashedEscapeButton extends StatelessWidget {
  const _DashedEscapeButton({required this.label, required this.onPressed});

  final Widget label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: CustomPaint(
      painter: const _DashedStairPainter(),
      child: Material(
        type: MaterialType.transparency,
        shape: const StairBorder.large(),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          customBorder: const StairBorder.large(),
          onTap: onPressed,
          child: SizedBox(
            height: 54,
            child: Center(
              child: DefaultTextStyle(
                style: PetTextStyles.button.copyWith(
                  color: PetColors.bodyStrong,
                ),
                textAlign: TextAlign.center,
                child: label,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashedStairPainter extends CustomPainter {
  const _DashedStairPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = const StairBorder.large().getOuterPath(
      (Offset.zero & size).deflate(1),
    );
    final paint = Paint()
      ..color = PetColors.bodyStrong
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final candidate = distance + 6;
        final end = candidate < metric.length ? candidate : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedStairPainter oldDelegate) => false;
}
