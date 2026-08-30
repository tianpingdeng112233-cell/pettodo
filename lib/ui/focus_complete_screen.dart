import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../application/focus_session_controller.dart';
import '../domain/app_state.dart';
import 'focus_pet.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';
import 'theme/pixel_background.dart';
import 'widgets/pixel_components.dart';

class FocusCompleteScreen extends StatefulWidget {
  const FocusCompleteScreen({
    super.key,
    required this.controller,
    required this.completion,
  });

  final AppController controller;
  final FocusSessionCompletion completion;

  @override
  State<FocusCompleteScreen> createState() => _FocusCompleteScreenState();
}

class _FocusCompleteScreenState extends State<FocusCompleteScreen> {
  bool _taskPromptVisible = true;
  bool _markingTask = false;

  TodoTask? get _task {
    final taskId = widget.completion.taskId;
    if (taskId == null) return null;
    return widget.controller.state.taskById(taskId);
  }

  Future<void> _markDone() async {
    final task = _task;
    if (task == null || _markingTask) return;
    setState(() => _markingTask = true);
    await widget.controller.completeTask(task.id);
    if (mounted) {
      setState(() {
        _markingTask = false;
        _taskPromptVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final completion = widget.completion;
    final controller = widget.controller;
    final task = _task;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: PixelBackground(
          showHalo: true,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                PetSpacing.s24,
                PetSpacing.s32,
                PetSpacing.s24,
                PetSpacing.s24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical -
                      PetSpacing.s54,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FocusPet(
                      controller: controller,
                      pose: FocusPetPose.celebrating,
                      size: 176,
                    ),
                    const SizedBox(height: PetSpacing.s12),
                    const Text(
                      'Focus complete!',
                      style: PetTextStyles.display26,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: PetSpacing.s8),
                    Text(
                      'You and ${controller.state.petName} focused for '
                      '${completion.minutes} minutes',
                      style: PetTextStyles.body17,
                      textAlign: TextAlign.center,
                    ),
                    if (completion.treats > 0) ...<Widget>[
                      const SizedBox(height: PetSpacing.s14),
                      _TreatBadge(amount: completion.treats),
                    ],
                    const SizedBox(height: PetSpacing.s20),
                    Text(
                      '“Let’s rest a little — I’ll be here when you’re ready~”',
                      style: PetTextStyles.body16Strong,
                      textAlign: TextAlign.center,
                    ),
                    if (_taskPromptVisible &&
                        task != null &&
                        !task.isComplete) ...<Widget>[
                      const SizedBox(height: PetSpacing.s24),
                      PxCard(
                        padding: const EdgeInsets.all(PetSpacing.s18),
                        child: Column(
                          children: <Widget>[
                            Text(
                              'Mark “${task.title}” as done while you’re at it?',
                              style: PetTextStyles.body16Strong,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: PetSpacing.s14),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: PxButton(
                                    style: PxButtonStyle.outline,
                                    height: 48,
                                    label: const Text('Not now'),
                                    onPressed: _markingTask
                                        ? null
                                        : () => setState(
                                            () => _taskPromptVisible = false,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: PetSpacing.s10),
                                Expanded(
                                  child: PxButton(
                                    height: 48,
                                    label: const Text('Mark done'),
                                    onPressed: _markingTask ? null : _markDone,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: PetSpacing.s28),
                    SizedBox(
                      width: double.infinity,
                      child: PxButton(
                        label: const Text('Back to the room'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TreatBadge extends StatelessWidget {
  const _TreatBadge({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: PetColors.badgeFill,
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PetSpacing.s14,
        vertical: PetSpacing.s6,
      ),
      child: Text(
        '+$amount ${amount == 1 ? 'treat' : 'treats'}',
        style: PetTextStyles.body15Strong,
      ),
    ),
  );
}
