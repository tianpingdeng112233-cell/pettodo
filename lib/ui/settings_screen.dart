import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../data/event_log_store.dart';
import '../data/export_service.dart';
import '../domain/app_state.dart';
import '../domain/unlocks.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.eventLog,
  });

  final AppController controller;
  final EventLogStore eventLog;

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initialValue,
    required ValueChanged<String> onSave,
  }) async {
    final field = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    field.dispose();
    if (result != null) onSave(result);
  }

  Future<void> _pickTime(BuildContext context) async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: controller.state.notificationHour,
        minute: controller.state.notificationMinute,
      ),
      helpText: '每天什么时候收到邀请？',
      cancelText: '取消',
      confirmText: '保存',
    );
    if (result != null) {
      await controller.updateNotificationTime(result.hour, result.minute);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final next = nextUnlock(controller.state.lifetimeCompletions);
      final progress = next == null
          ? '已完成 ${controller.state.lifetimeCompletions} 次 · 小窝里的装饰都收集齐啦'
          : '已完成 ${controller.state.lifetimeCompletions} 次 · '
                '下一个解锁还差 ${next.threshold - controller.state.lifetimeCompletions} 次';
      final denied =
          controller.state.notificationPermission ==
          NotificationPermissionState.denied;
      return Scaffold(
        appBar: AppBar(
          title: const Text('设置'),
          backgroundColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            _Section(
              title: '伙伴',
              children: <Widget>[
                ListTile(
                  title: const Text('宠物名字'),
                  subtitle: Text(controller.state.petName),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editText(
                    context,
                    title: '给它换个名字',
                    initialValue: controller.state.petName,
                    onSave: controller.updatePetName,
                  ),
                ),
              ],
            ),
            _Section(
              title: '每天的 3 件小事',
              children: List.generate(
                3,
                (index) => ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(controller.state.taskTitles[index]),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editText(
                    context,
                    title: '编辑小事 ${index + 1}',
                    initialValue: controller.state.taskTitles[index],
                    onSave: (value) => controller.updateTaskTitle(index, value),
                  ),
                ),
              ),
            ),
            _Section(
              title: '温柔提醒',
              children: <Widget>[
                SwitchListTile(
                  title: const Text('每天邀请一次'),
                  value: controller.state.notificationEnabled,
                  onChanged: denied ? null : controller.setNotificationEnabled,
                ),
                if (controller.state.notificationEnabled)
                  ListTile(
                    title: const Text('邀请时间'),
                    trailing: Text(
                      TimeOfDay(
                        hour: controller.state.notificationHour,
                        minute: controller.state.notificationMinute,
                      ).format(context),
                    ),
                    onTap: () => _pickTime(context),
                  ),
              ],
            ),
            _Section(
              title: '小窝收藏',
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(progress),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 18,
                        children: decorUnlocks
                            .map((item) {
                              final unlocked = controller.state.unlockedDecorIds
                                  .contains(item.id);
                              return Semantics(
                                label: unlocked
                                    ? '已解锁${item.name}'
                                    : '${item.threshold} 次后解锁',
                                child: Opacity(
                                  opacity: unlocked ? 1 : 0.28,
                                  child: Text(
                                    item.emoji,
                                    style: const TextStyle(fontSize: 34),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _Section(
              title: '数据与版本',
              children: <Widget>[
                Builder(
                  builder: (buttonContext) => ListTile(
                    leading: const Icon(Icons.ios_share_rounded),
                    title: const Text('导出数据'),
                    subtitle: const Text('分享本地 JSONL 事件记录'),
                    onTap: () async {
                      final box =
                          buttonContext.findRenderObject()! as RenderBox;
                      final origin = box.localToGlobal(Offset.zero) & box.size;
                      await ExportService(
                        eventLog,
                      ).shareEvents(sharePositionOrigin: origin);
                    },
                  ),
                ),
                const ListTile(
                  title: Text('PetTodo'),
                  trailing: Text('1.0.0 (1)'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(child: Column(children: children)),
      ],
    ),
  );
}
