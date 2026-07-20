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
  await notifications.initialize(() {
    return eventLog.append(
      PetEvent(type: PetEventType.notificationTap, timestamp: DateTime.now()),
    );
  });
  final controller = AppController(
    stateStore: AppStateStore.onDevice(),
    eventLog: eventLog,
    notifications: notifications,
  );
  await controller.initialize();
  runApp(PetTodoApp(controller: controller, eventLog: eventLog));
}
