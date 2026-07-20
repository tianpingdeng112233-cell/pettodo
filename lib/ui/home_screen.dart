import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../data/event_log_store.dart';
import '../domain/unlocks.dart';
import '../sprite/pet_sprite.dart';
import 'app_theme.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.eventLog,
  });

  final AppController controller;
  final EventLogStore eventLog;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: Text(controller.state.petName),
      centerTitle: true,
      actions: <Widget>[
        IconButton(
          tooltip: '设置',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  SettingsScreen(controller: controller, eventLog: eventLog),
            ),
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: controller.unlockBanner == null
                  ? const SizedBox(height: 44)
                  : Container(
                      key: ValueKey(controller.unlockBanner),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.honey.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        controller.unlockBanner!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
            SizedBox(
              height: 292,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  _Decorations(controller: controller),
                  SizedBox(
                    width: 270,
                    height: 270,
                    child: PetSprite(
                      atlas: controller.spriteAtlas,
                      stateName: controller.petAnimation,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _ParticleBurst(
                        key: ValueKey(controller.celebrationNonce),
                        active: controller.celebrationNonce > 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: controller.affectionateMessage == null
                  ? Text(
                      controller.state.allDone ? '今天就一起舒服地待着吧' : '今天也慢慢来',
                      key: const ValueKey('calm'),
                      style: Theme.of(context).textTheme.titleMedium,
                    )
                  : Text(
                      controller.affectionateMessage!,
                      key: const ValueKey('affection'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFB56A3F),
                      ),
                    ),
            ),
            const SizedBox(height: 22),
            ...List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TaskCard(
                  title: controller.state.taskTitles[index],
                  checked: controller.state.completedToday[index],
                  onTap: () async {
                    final completed = await controller.completeTask(index);
                    if (completed) await HapticFeedback.mediumImpact();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
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
  Widget build(BuildContext context) => Material(
    color: checked ? AppTheme.mint.withValues(alpha: 0.25) : AppTheme.card,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: checked ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: Semantics(
        button: true,
        checked: checked,
        label: title,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: checked ? AppTheme.mint : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: checked
                        ? AppTheme.mint
                        : AppTheme.cocoa.withValues(alpha: 0.28),
                    width: 2,
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.cocoa.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Decorations extends StatelessWidget {
  const _Decorations({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final unlocked = decorUnlocks
        .where((item) => controller.state.unlockedDecorIds.contains(item.id))
        .toList(growable: false);
    const positions = <Alignment>[
      Alignment(-0.82, 0.58),
      Alignment(0.82, -0.44),
      Alignment(0.78, 0.72),
    ];
    return Stack(
      children: List.generate(
        unlocked.length,
        (index) => Align(
          alignment: positions[index],
          child: Text(
            unlocked[index].emoji,
            style: const TextStyle(fontSize: 40),
          ),
        ),
      ),
    );
  }
}

class _ParticleBurst extends StatefulWidget {
  const _ParticleBurst({super.key, required this.active});

  final bool active;

  @override
  State<_ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<_ParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.active) _animation.forward();
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
        CustomPaint(painter: _ParticlePainter(progress: _animation.value)),
  );
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({required this.progress});

  final double progress;

  static const colors = <Color>[
    AppTheme.honey,
    AppTheme.mint,
    Color(0xFFE99A8D),
    Color(0xFF9DB7DE),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width / 2, size.height * 0.52);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    for (var index = 0; index < 22; index++) {
      final angle = index * math.pi * 2 / 22;
      final distance = 30 + progress * (75 + (index % 5) * 14);
      final point = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance - progress * 25,
      );
      canvas.drawCircle(
        point,
        3 + (index % 3).toDouble(),
        Paint()
          ..color = colors[index % colors.length].withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
