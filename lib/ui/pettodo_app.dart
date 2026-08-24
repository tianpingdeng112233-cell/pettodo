import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../data/event_log_store.dart';
import 'app_theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class PetTodoApp extends StatefulWidget {
  const PetTodoApp({
    super.key,
    required this.controller,
    required this.eventLog,
  });

  final AppController controller;
  final EventLogStore eventLog;

  @override
  State<PetTodoApp> createState() => _PetTodoAppState();
}

class _PetTodoAppState extends State<PetTodoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.onResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pawside',
      theme: AppTheme.light,
      home: widget.controller.state.onboardingComplete
          ? HomeScreen(controller: widget.controller, eventLog: widget.eventLog)
          : OnboardingScreen(controller: widget.controller),
    ),
  );
}
