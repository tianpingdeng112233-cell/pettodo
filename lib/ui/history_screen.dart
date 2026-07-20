import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/event_log_store.dart';
import '../domain/task_history.dart';
import 'theme/app_theme.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_radii.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.eventLog,
    required this.petName,
  });

  final EventLogStore eventLog;
  final String petName;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Future<List<HistoryWeek>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.eventLog.readAll().then(aggregatePositiveHistory);
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Things we did together'),
        backgroundColor: PetColors.transparent,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.screenGradient),
        child: FutureBuilder<List<HistoryWeek>>(
          future: _history,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final weeks = snapshot.data!;
            if (weeks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(PetSpacing.s32),
                  child: Text(
                    'Finished little things will gather here, warm and safe.',
                    style: PetTextStyles.body16,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(PetSpacing.s20),
              itemCount: weeks.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: PetSpacing.s14),
              itemBuilder: (context, index) => _WeekCard(
                week: weeks[index],
                petName: widget.petName,
                isCurrentWeek: _isCurrentWeek(weeks[index].weekStart),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.petName,
    required this.isCurrentWeek,
  });

  final HistoryWeek week;
  final String petName;
  final bool isCurrentWeek;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(PetSpacing.s18),
    decoration: const BoxDecoration(
      color: PetColors.white,
      borderRadius: PetRadii.cardBorder,
      boxShadow: PetShadows.panel,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          isCurrentWeek ? 'THIS WEEK' : 'WEEK OF ${_shortDate(week.weekStart)}',
          style: PetTextStyles.caption,
        ),
        const SizedBox(height: PetSpacing.s8),
        Text(
          isCurrentWeek
              ? 'This week, you and $petName did ${week.total} things together'
              : 'You and $petName did ${week.total} things together',
          style: PetTextStyles.body16Strong,
        ),
        const SizedBox(height: PetSpacing.s14),
        for (final day in week.days) ...<Widget>[
          Text(_formatDay(day.date), style: PetTextStyles.caption),
          const SizedBox(height: PetSpacing.xs),
          for (final item in day.items)
            Padding(
              padding: const EdgeInsets.only(bottom: PetSpacing.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('♥ ', style: PetTextStyles.small),
                  Expanded(
                    child: Text(item.title, style: PetTextStyles.body15Soft),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );
}

bool _isCurrentWeek(DateTime start) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return start == today.subtract(Duration(days: today.weekday - 1));
}

String _formatDay(DateTime value) {
  const weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return '${weekdays[value.weekday - 1]} · ${value.day}/${value.month}';
}

String _shortDate(DateTime value) => '${value.day}/${value.month}';
