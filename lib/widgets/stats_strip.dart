import 'package:flutter/material.dart';
import '../models/task_grouping.dart';
import '../theme.dart';
import 'task_tile.dart';

class StatsStrip extends StatelessWidget {
  const StatsStrip({super.key, required this.stats});
  final TaskStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(children: [
        Row(children: [
          Text('${stats.done} of ${stats.total} tasks complete',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
          const Spacer(),
          Text('${(stats.progress * 100).round()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimary)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: stats.progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: c.field,
              valueColor: const AlwaysStoppedAnimation(kPrimary),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _Stat(icon: Icons.task_alt, color: const Color(0xFF4CAF84), value: '${stats.doneThisWeek}', label: 'Done this week'),
          _Stat(
              icon: Icons.warning_amber_rounded,
              color: stats.overdue > 0 ? const Color(0xFFE5534B) : c.muted,
              value: '${stats.overdue}',
              label: 'Overdue'),
          _Stat(icon: Icons.payments_outlined, color: kPrimary, value: formatMoney(stats.earnedThisWeek), label: 'Earned this week'),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value, required this.label});
  final IconData icon;
  final Color color;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.c.ink)),
        ),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: context.c.muted)),
      ]),
    );
  }
}
