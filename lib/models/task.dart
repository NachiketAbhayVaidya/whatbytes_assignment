import 'package:cloud_firestore/cloud_firestore.dart';

enum Priority { low, medium, high }

/// Reminder offset meaning "don't remind me".
const kNoReminder = -1;

/// Time of day used for reminders on tasks that only have a due date.
const kDefaultReminderHour = 9;

class Task {
  final String? id;
  final String title;
  final String description;

  /// Due date. Includes the time of day only when [hasTime] is true.
  final DateTime dueDate;
  final bool hasTime;
  final Priority priority;
  final bool completed;
  final DateTime? completedAt;

  /// What the gig pays, if anything.
  final double? pay;

  /// Minutes before the due moment to remind, or [kNoReminder].
  final int remindMinutes;

  /// Web link for the gig (job post, map, brief...).
  final String? link;

  const Task({
    this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    this.hasTime = false,
    this.completed = false,
    this.completedAt,
    this.pay,
    this.remindMinutes = 0,
    this.link,
  });

  Task copyWith({bool? completed, DateTime? completedAt}) => Task(
        id: id,
        title: title,
        description: description,
        dueDate: dueDate,
        priority: priority,
        hasTime: hasTime,
        completed: completed ?? this.completed,
        completedAt: completedAt ?? this.completedAt,
        pay: pay,
        remindMinutes: remindMinutes,
        link: link,
      );

  /// When the reminder should fire, or null if reminders are off.
  /// Date-only tasks remind at [kDefaultReminderHour] on the due date.
  DateTime? get reminderAt {
    if (remindMinutes == kNoReminder) return null;
    final base =
        hasTime ? dueDate : DateTime(dueDate.year, dueDate.month, dueDate.day, kDefaultReminderHour);
    return base.subtract(Duration(minutes: remindMinutes));
  }

  bool isOverdue(DateTime now) {
    if (completed) return false;
    if (hasTime) return dueDate.isBefore(now);
    return DateTime(dueDate.year, dueDate.month, dueDate.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'dueDate': Timestamp.fromDate(dueDate),
        'hasTime': hasTime,
        'priority': priority.name,
        'completed': completed,
        'completedAt': completedAt == null ? null : Timestamp.fromDate(completedAt!),
        'pay': pay,
        'remindMinutes': remindMinutes,
        'link': link,
      };

  factory Task.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Task(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      dueDate: (d['dueDate'] as Timestamp).toDate(),
      hasTime: d['hasTime'] ?? false,
      priority: Priority.values.firstWhere((p) => p.name == d['priority'], orElse: () => Priority.medium),
      completed: d['completed'] ?? false,
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      pay: (d['pay'] as num?)?.toDouble(),
      remindMinutes: (d['remindMinutes'] as num?)?.toInt() ?? 0,
      link: d['link'] as String?,
    );
  }
}
