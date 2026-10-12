import 'package:flutter_test/flutter_test.dart';
import 'package:whatbytesassignment/models/reminders.dart';
import 'package:whatbytesassignment/models/task.dart';
import 'package:whatbytesassignment/models/task_grouping.dart';
import 'package:whatbytesassignment/services/auth_service.dart';
import 'package:whatbytesassignment/utils/link.dart';

Task task(DateTime due, {bool hasTime = false, bool done = false, DateTime? doneAt, double? pay, int remind = 0}) => Task(
      id: 'x',
      title: 't',
      description: '',
      dueDate: due,
      hasTime: hasTime,
      priority: Priority.low,
      completed: done,
      completedAt: doneAt,
      pay: pay,
      remindMinutes: remind,
    );

void main() {
  final now = DateTime(2026, 10, 14, 12); // a Wednesday

  group('reminders', () {
    test('date-only task reminds at 9 AM on the day', () {
      expect(task(DateTime(2026, 10, 20)).reminderAt, DateTime(2026, 10, 20, 9));
    });
    test('timed task reminds before the due time', () {
      final t = task(DateTime(2026, 10, 20, 18, 30), hasTime: true, remind: 60);
      expect(t.reminderAt, DateTime(2026, 10, 20, 17, 30));
    });
    test('no reminder when turned off', () {
      expect(task(DateTime(2026, 10, 20), remind: kNoReminder).reminderAt, isNull);
    });
  });

  group('grouping', () {
    test('buckets by due date', () {
      expect(bucketOf(task(DateTime(2026, 10, 13)), now), TaskBucket.overdue);
      expect(bucketOf(task(DateTime(2026, 10, 14)), now), TaskBucket.today);
      expect(bucketOf(task(DateTime(2026, 10, 15)), now), TaskBucket.tomorrow);
      expect(bucketOf(task(DateTime(2026, 10, 19)), now), TaskBucket.thisWeek);
      expect(bucketOf(task(DateTime(2026, 11, 30)), now), TaskBucket.later);
    });
    test('timed task earlier today is overdue; completed past task is earlier', () {
      expect(bucketOf(task(DateTime(2026, 10, 14, 9), hasTime: true), now), TaskBucket.overdue);
      expect(bucketOf(task(DateTime(2026, 10, 1), done: true), now), TaskBucket.earlier);
    });
  });

  test('stats count this week only, week starts Monday', () {
    final stats = computeStats([
      task(DateTime(2026, 10, 14), done: true, doneAt: DateTime(2026, 10, 13), pay: 500),
      task(DateTime(2026, 10, 10), done: true, doneAt: DateTime(2026, 10, 11), pay: 900), // last week
      task(DateTime(2026, 10, 12)), // overdue
      task(DateTime(2026, 10, 20)),
    ], now);
    expect(stats.total, 4);
    expect(stats.done, 2);
    expect(stats.doneThisWeek, 1);
    expect(stats.earnedThisWeek, 500);
    expect(stats.overdue, 1);
  });

  group('reminder planning', () {
    Task at(String id, DateTime due, {bool done = false, int remind = 0}) => Task(
        id: id, title: id, description: '', dueDate: due, priority: Priority.low, completed: done, remindMinutes: remind);

    test('skips completed, past and disabled; sorts soonest first', () {
      final planned = plannedReminders([
        at('later', DateTime(2026, 10, 25)),
        at('soon', DateTime(2026, 10, 15)),
        at('done', DateTime(2026, 10, 16), done: true),
        at('past', DateTime(2026, 10, 14)), // 9 AM today already passed at noon
        at('off', DateTime(2026, 10, 17), remind: kNoReminder),
      ], now);
      expect(planned.map((p) => p.task.id), ['soon', 'later']);
    });

    test('caps the number of scheduled reminders', () {
      final many = [for (var i = 0; i < 100; i++) at('t$i', DateTime(2026, 11, 1).add(Duration(days: i)))];
      expect(plannedReminders(many, now), hasLength(kMaxScheduledReminders));
    });
  });

  group('links', () {
    test('adds https and accepts valid web links', () {
      expect(parseLink('upwork.com/jobs/123')?.toString(), 'https://upwork.com/jobs/123');
      expect(parseLink('http://example.com')?.scheme, 'http');
    });
    test('rejects empty, spaced and non-web input', () {
      expect(parseLink(''), isNull);
      expect(parseLink('not a link'), isNull);
      expect(parseLink('javascript:alert(1)'), isNull);
      expect(parseLink('ftp://example.com'), isNull);
      expect(parseLink('localhost'), isNull);
    });
    test('shows a short host', () {
      expect(linkHost('https://www.upwork.com/jobs/1'), 'upwork.com');
    });
  });

  group('usernames', () {
    test('accepts 3-20 letters, numbers and underscores', () {
      for (final ok in ['sam', 'Sam_99', 'a_b_c', 'x' * 20]) {
        expect(AuthService.usernamePattern.hasMatch(ok), isTrue, reason: ok);
      }
    });
    test('rejects too short, too long, spaces and symbols', () {
      for (final bad in ['ab', 'x' * 21, 'has space', 'dot.name', 'a-b', '@sam', 'ñame', '']) {
        expect(AuthService.usernamePattern.hasMatch(bad), isFalse, reason: bad);
      }
    });
  });

  group('editing an overdue task', () {
    // Today is Wed 14 Oct 2026, 12:00.
    test('moving a timed task to later today clears overdue', () {
      expect(task(DateTime(2026, 10, 14, 9), hasTime: true).isOverdue(now), isTrue);
      expect(task(DateTime(2026, 10, 14, 17), hasTime: true).isOverdue(now), isFalse);
    });
    test('changing only the time of a past DATE keeps it overdue', () {
      expect(task(DateTime(2026, 10, 13, 23, 59), hasTime: true).isOverdue(now), isTrue);
    });
    test('a date-only task is overdue only before today', () {
      expect(task(DateTime(2026, 10, 13)).isOverdue(now), isTrue);
      expect(task(DateTime(2026, 10, 14)).isOverdue(now), isFalse);
    });
    test('completed tasks are never overdue', () {
      expect(task(DateTime(2026, 10, 1), done: true).isOverdue(now), isFalse);
    });
  });

  group('username suggestion', () {
    test('turns an email into a valid username', () {
      expect(AuthService.suggestUsername('Sam.Lee+x@gmail.com'), 'samleex');
      expect(AuthService.suggestUsername('jordan.rivera2026@example.com'), 'jordanrivera2026');
    });
    test('always returns something that passes validation', () {
      for (final e in [null, '', 'a@x.com', '..@x.com', 'ab@x.com', 'a_very_long_name_that_exceeds_twenty@x.com']) {
        expect(AuthService.usernamePattern.hasMatch(AuthService.suggestUsername(e)), isTrue, reason: '$e');
      }
    });
  });
}
