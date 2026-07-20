import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../domain/app_state.dart';
import '../sprite/pet_sprite.dart';
import 'app_theme.dart';

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
  String _selectedPetId = 'choco';
  TimeOfDay _notificationTime = const TimeOfDay(hour: 20, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: 'Choco');
    _tasks = defaultTaskTitles
        .map((title) => TextEditingController(text: title))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    for (final controller in _tasks) {
      controller.dispose();
    }
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    _pages.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _chooseTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      helpText: '选一个想收到邀请的时间',
      cancelText: '取消',
      confirmText: '选好啦',
    );
    if (value != null) setState(() => _notificationTime = value);
  }

  Future<void> _finish(bool enableNotifications) async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.controller.completeOnboarding(
      selectedPetId: _selectedPetId,
      petName: _name.text,
      taskTitles: _tasks.map((item) => item.text).toList(growable: false),
      enableNotifications: enableNotifications,
      notificationHour: _notificationTime.hour,
      notificationMinute: _notificationTime.minute,
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index <= _page
                          ? AppTheme.honey
                          : AppTheme.honey.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (value) => setState(() => _page = value),
              children: <Widget>[
                _PetPage(
                  controller: widget.controller,
                  selectedPetId: _selectedPetId,
                  onSelected: (value) => setState(() => _selectedPetId = value),
                  onNext: _next,
                ),
                _FormPage(
                  title: '它想听你叫它什么？',
                  subtitle: '以后，这个名字会出现在每一份小小陪伴里。',
                  buttonText: '就叫这个名字',
                  onNext: _next,
                  children: <Widget>[
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.done,
                      maxLength: 20,
                      decoration: const InputDecoration(labelText: '宠物名字'),
                    ),
                  ],
                ),
                _FormPage(
                  title: '每天想一起做哪 3 件小事？',
                  subtitle: '每天都是新的一天。没做完也不会留下任何压力。',
                  buttonText: '和它一起开始',
                  onNext: _next,
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: _tasks[index],
                        maxLength: 40,
                        decoration: InputDecoration(
                          labelText: '小事 ${index + 1}',
                        ),
                      ),
                    ),
                  ),
                ),
                _NotificationPage(
                  petName: _name.text.trim().isEmpty
                      ? 'Choco'
                      : _name.text.trim(),
                  time: _notificationTime,
                  saving: _saving,
                  onChooseTime: _chooseTime,
                  onEnable: () => _finish(true),
                  onSkip: () => _finish(false),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PetPage extends StatelessWidget {
  const _PetPage({
    required this.controller,
    required this.selectedPetId,
    required this.onSelected,
    required this.onNext,
  });

  final AppController controller;
  final String selectedPetId;
  final ValueChanged<String> onSelected;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 12),
        Text('先认识一下你的伙伴', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('v1 先由 Choco 陪你。以后这里会住进更多朋友。'),
        const SizedBox(height: 18),
        SizedBox(height: 200, child: PetSprite(atlas: controller.spriteAtlas)),
        RadioGroup<String>(
          groupValue: selectedPetId,
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
          child: Column(
            children: controller.pets
                .map(
                  (pet) => Card(
                    child: RadioListTile<String>(
                      value: pet.id,
                      title: Text(pet.displayName),
                      subtitle: const Text('温柔、好奇，喜欢陪在你身边'),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const Card(
          child: ListTile(
            enabled: false,
            leading: Icon(Icons.add_a_photo_outlined),
            title: Text('上传自家宠物照片（即将上线）'),
          ),
        ),
        const Spacer(),
        FilledButton(onPressed: onNext, child: const Text('选好啦')),
      ],
    ),
  );
}

class _FormPage extends StatelessWidget {
  const _FormPage({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.buttonText,
    required this.onNext,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final String buttonText;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.sizeOf(context).height - 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 34),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle),
          const SizedBox(height: 34),
          ...children,
          const SizedBox(height: 24),
          FilledButton(onPressed: onNext, child: Text(buttonText)),
        ],
      ),
    ),
  );
}

class _NotificationPage extends StatelessWidget {
  const _NotificationPage({
    required this.petName,
    required this.time,
    required this.saving,
    required this.onChooseTime,
    required this.onEnable,
    required this.onSkip,
  });

  final String petName;
  final TimeOfDay time;
  final bool saving;
  final VoidCallback onChooseTime;
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Spacer(),
        const Icon(
          Icons.notifications_none_rounded,
          size: 68,
          color: AppTheme.honey,
        ),
        const SizedBox(height: 28),
        Text('偶尔，让它轻轻叫你回来', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text('$petName 只会每天发来一次温柔邀请。不开也完全没关系。'),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: saving ? null : onChooseTime,
          icon: const Icon(Icons.schedule_rounded),
          label: Text('每天 ${time.format(context)}'),
        ),
        const Spacer(),
        FilledButton(
          onPressed: saving ? null : onEnable,
          child: Text(saving ? '正在准备小窝…' : '好呀，提醒我'),
        ),
        TextButton(
          onPressed: saving ? null : onSkip,
          child: const Text('暂时不用'),
        ),
      ],
    ),
  );
}
