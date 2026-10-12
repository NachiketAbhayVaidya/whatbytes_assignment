import 'task.dart';

enum TaskBucket { overdue, today, tomorrow, thisWeek, later, earlier }

extension TaskBucketLabel on TaskBucket {
  String get label => switch (this) {
        TaskBucket.overdue => 'Overdue',
        TaskBucket.today => 'Today',
        TaskBucket.tomorrow => 'Tomorrow',
        TaskBucket.thisWeek => 'This week',
        TaskBucket.later => 'Later',
        TaskBucket.earlier => 'Earlier',
      };
}

/// Which section of the list a task belongs in.
TaskBucket bucketOf(Task t, DateTime now) {
  if (t.isOverdue(now)) return TaskBucket.overdue;
  // UTC dates so daylight-saving shifts can't skew the day count.
  final due = DateTime.utc(t.dueDate.year, t.dueDate.month, t.dueDate.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final days = due.difference(today).inDays;
  if (days < 0) return TaskBucket.earlier; // completed tasks from the past
  if (days == 0) return TaskBucket.today;
  if (days == 1) return TaskBucket.tomorrow;
  if (days <= 7) return TaskBucket.thisWeek;
  return TaskBucket.later;
}

/// Groups already-sorted tasks into ordered, non-empty sections.
Map<TaskBucket, List<Task>> groupTasks(List<Task> sorted, DateTime now) {
  final groups = <TaskBucket, List<Task>>{};
  for (final t in sorted) {
    groups.putIfAbsent(bucketOf(t, now), () => []).add(t);
  }
  return {for (final b in TaskBucket.values) if (groups.containsKey(b)) b: groups[b]!};
}

class TaskStats {
  const TaskStats({required this.total, required this.done, required this.overdue, required this.doneThisWeek, required this.earnedThisWeek});
  final int total, done, overdue, doneThisWeek;
  final double earnedThisWeek;

  double get progress => total == 0 ? 0 : done / total;
}

/// Weeks start on Monday.
TaskStats computeStats(List<Task> tasks, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  var done = 0, overdue = 0, doneThisWeek = 0;
  var earned = 0.0;
  for (final t in tasks) {
    if (t.completed) {
      done++;
      final at = t.completedAt;
      if (at != null && !at.isBefore(weekStart)) {
        doneThisWeek++;
        earned += t.pay ?? 0;
      }
    } else if (t.isOverdue(now)) {
      overdue++;
    }
  }
  return TaskStats(total: tasks.length, done: done, overdue: overdue, doneThisWeek: doneThisWeek, earnedThisWeek: earned);
}
