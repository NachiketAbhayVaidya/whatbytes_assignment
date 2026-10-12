import 'task.dart';

/// iOS keeps only the soonest 64 pending local notifications, so stay under it.
const kMaxScheduledReminders = 60;

/// Which tasks should have a reminder scheduled, soonest first.
/// Skips completed tasks, tasks without a reminder and reminders already in the past.
List<({Task task, DateTime at})> plannedReminders(List<Task> tasks, DateTime now,
    {int limit = kMaxScheduledReminders}) {
  final planned = <({Task task, DateTime at})>[];
  for (final t in tasks) {
    final at = t.reminderAt;
    if (t.completed || t.id == null || at == null || !at.isAfter(now)) continue;
    planned.add((task: t, at: at));
  }
  planned.sort((a, b) => a.at.compareTo(b.at));
  return planned.take(limit).toList();
}
