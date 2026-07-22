import 'package:flutter/material.dart';

import 'application/app_controller.dart';
import 'data/app_state_store.dart';
import 'data/event_log_store.dart';
import 'data/notification_service.dart';
import 'domain/event_log.dart';
import 'ui/pettodo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final eventLog = EventLogStore.onDevice();
  final notifications = NotificationService();
  // Anything before runApp() that throws leaves the user staring at a black
  // screen with no way back. Notifications are optional company for the pet,
  // never a precondition for opening the app, so a platform failure here is
  // logged and stepped over. (A missing Android drawable did exactly this.)
  try {
    await notifications.initialize(() {
      return eventLog.append(
        PetEvent(type: PetEventType.notificationTap, timestamp: DateTime.now()),
      );
    });
  } catch (error, stackTrace) {
    debugPrint('Notification init failed (continuing without it): $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  final controller = AppController(
    stateStore: AppStateStore.onDevice(),
    eventLog: eventLog,
    notifications: notifications,
  );
  await controller.initialize();
  runApp(PetTodoApp(controller: controller, eventLog: eventLog));
}
