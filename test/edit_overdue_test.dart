import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatbytesassignment/models/task.dart';
import 'package:whatbytesassignment/screens/home_screen.dart';
import 'package:whatbytesassignment/services/task_service.dart';
import 'package:whatbytesassignment/theme.dart';
import 'package:whatbytesassignment/widgets/task_tile.dart';

class _FakeUser implements User {
  @override
  String get uid => 'u1';
  @override
  String? get displayName => 'tester';
  @override
  String? get email => 'tester@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory stand-in for TaskService that behaves like the Firestore one:
/// every change pushes a fresh list (sorted by due date) to listeners.
class _MemoryTaskService extends TaskService {
  _MemoryTaskService() : super('u1');
  final _tasks = <String, Task>{};
  final _changes = StreamController<void>.broadcast();
  var _next = 0;

  List<Task> get all => _tasks.values.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  @override
  Stream<List<Task>> watch() => Stream.multi((c) {
        c.add(all);
        final sub = _changes.stream.listen((_) => c.add(all));
        c.onCancel = sub.cancel;
      }, isBroadcast: true);

  @override
  Future<void> add(Task t) async {
    final id = 't${_next++}';
    _tasks[id] = Task(
        id: id, title: t.title, description: t.description, dueDate: t.dueDate, hasTime: t.hasTime,
        priority: t.priority, completed: t.completed, pay: t.pay, remindMinutes: t.remindMinutes, link: t.link);
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _tasks.remove(id);
    _changes.add(null);
  }

  @override
  Future<void> restore(Task t) async {
    _tasks[t.id!] = t;
    _changes.add(null);
  }

  @override
  Future<void> update(Task t) async {
    _tasks[t.id!] = t;
    _changes.add(null);
  }
}

void main() {
  testWidgets('moving an overdue task to a later time today clears Overdue', (tester) async {
    tester.view.physicalSize = const Size(800, 2400); // tall, so the whole form is on screen
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    // Needs room to move +5 minutes without crossing midnight.
    if (now.hour == 23 && now.minute > 50) return;

    final service = _MemoryTaskService();
    final past = now.subtract(const Duration(minutes: 3)); // like "due 10:00, it is now 10:03"
    await service.add(Task(
      title: 'Deliver parcel',
      description: '',
      dueDate: DateTime(past.year, past.month, past.day, past.hour, past.minute),
      hasTime: true,
      priority: Priority.medium,
    ));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: HomeScreen(user: _FakeUser(), service: service),
    ));
    await tester.pumpAndSettle();
    // "Overdue" appears twice while overdue: the stats label and the section header.
    expect(find.text('Overdue'), findsNWidgets(2), reason: 'task starts overdue');
    expect(find.text('Today'), findsNothing);

    // Open the task and change its time to 5 minutes from now.
    await tester.tap(find.text('Deliver parcel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Time (optional)'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined)); // type the time instead of the dial
    await tester.pumpAndSettle();

    final target = now.add(const Duration(minutes: 5));
    final hour12 = target.hour % 12 == 0 ? 12 : target.hour % 12;
    final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), '$hour12');
    await tester.enterText(fields.at(1), target.minute.toString().padLeft(2, '0'));
    await tester.tap(find.text(target.hour >= 12 ? 'PM' : 'AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining('is in the past'), findsNothing, reason: 'form should not warn');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final savedDue = service.all.single.dueDate;
    expect(savedDue.hour, target.hour);
    expect(savedDue.minute, target.minute);

    expect(find.text('Overdue'), findsOneWidget, reason: 'only the stats label should remain, no Overdue section');
    expect(find.text('Today'), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // dispose timers
  });

  testWidgets('trash button on a card deletes the task and Undo brings it back', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _MemoryTaskService();
    await service.add(Task(
        title: 'Walk dog', description: '', dueDate: DateTime.now().add(const Duration(days: 2)), priority: Priority.low));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: HomeScreen(user: _FakeUser(), service: service),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Walk dog'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(TaskTile), matching: find.byIcon(Icons.delete_outline)));
    await tester.pumpAndSettle();
    expect(find.text('Walk dog'), findsNothing);
    expect(find.text('Deleted "Walk dog"'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Walk dog'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Delete in the edit screen removes the task', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _MemoryTaskService();
    await service.add(Task(
        title: 'Pick up order', description: '', dueDate: DateTime.now().add(const Duration(days: 2)), priority: Priority.high));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: HomeScreen(user: _FakeUser(), service: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick up order'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete task').last); // the app bar action on the edit screen
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsNothing, reason: 'should return to the list');
    expect(service.all, isEmpty);
    expect(find.text('Deleted "Pick up order"'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
