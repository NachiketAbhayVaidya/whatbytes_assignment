import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/task_grouping.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
import '../theme.dart';
import '../widgets/priority_chip.dart';
import '../widgets/stats_strip.dart';
import '../widgets/task_tile.dart';
import 'change_password_dialog.dart';
import 'task_form_screen.dart';

enum StatusFilter { all, incomplete, completed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, this.service, this.username, this.canChangePassword = true});
  final User user;

  /// The chosen @username (falls back to the account's display name).
  final String? username;

  /// False for Google-only accounts, which have no password to change.
  final bool canChangePassword;

  /// Lets tests supply a fake backend; the app uses the real one.
  final TaskService? service;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TaskService _service = widget.service ?? TaskService(widget.user.uid);
  late final Stream<List<Task>> _tasks = _service.watch();
  final _searchController = TextEditingController();
  Priority? _priority;
  StatusFilter _status = StatusFilter.all;
  String _query = '';
  StreamSubscription<List<Task>>? _reminderSub;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    final notifications = NotificationService.instance;
    notifications.requestPermission();
    // Keep local reminders in sync with every add/edit/complete/delete.
    _reminderSub = _tasks.listen(notifications.sync, onError: (_) {});
    // Re-check overdue status and sections as time passes, not only when data changes.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _reminderSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openForm([Task? task]) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => TaskFormScreen(service: _service, task: task)));

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
      }
    }
  }

  Future<void> _delete(Task t) async {
    final messenger = ScaffoldMessenger.of(context);
    await _run(() => _service.delete(t.id!));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Deleted "${t.title}"'),
        action: SnackBarAction(label: 'Undo', onPressed: () => _run(() => _service.restore(t))),
      ));
  }

  List<Task> _apply(List<Task> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((t) {
      if (_priority != null && t.priority != _priority) return false;
      if (q.isNotEmpty && !t.title.toLowerCase().contains(q) && !t.description.toLowerCase().contains(q)) {
        return false;
      }
      return switch (_status) {
        StatusFilter.all => true,
        StatusFilter.incomplete => !t.completed,
        StatusFilter.completed => t.completed,
      };
    }).toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate)); // earliest first
    return list;
  }

  /// Flattens grouped tasks into section headers (String) and tasks.
  List<Object> _sections(List<Task> sorted) {
    final items = <Object>[];
    groupTasks(sorted, DateTime.now()).forEach((bucket, tasks) {
      items.add(bucket);
      items.addAll(tasks);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_task),
      ),
      body: Column(children: [
        _Header(
          username: widget.username ?? widget.user.displayName,
          canChangePassword: widget.canChangePassword,
          email: widget.user.email ?? '',
          searchController: _searchController,
          onSearch: (v) => setState(() => _query = v),
          onLogout: () async {
            await NotificationService.instance.cancelAll();
            await AuthService().signOut();
          },
        ),
        Expanded(
          child: StreamBuilder<List<Task>>(
            stream: _tasks,
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('Could not load tasks.'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator.adaptive());
              final all = snap.data!;
              final items = _sections(_apply(all));
              return CustomScrollView(slivers: [
                if (all.isNotEmpty) SliverToBoxAdapter(child: StatsStrip(stats: computeStats(all, DateTime.now()))),
                SliverToBoxAdapter(
                  child: _Filters(
                    priority: _priority,
                    status: _status,
                    onPriority: (p) => setState(() => _priority = p),
                    onStatus: (s) => setState(() => _status = s),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.inbox_outlined, size: 64, color: c.muted),
                        const SizedBox(height: 8),
                        Text(all.isEmpty ? 'No tasks yet. Tap + to add one!' : 'No tasks match your search or filters.',
                            style: TextStyle(color: c.muted)),
                      ]),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        if (item is TaskBucket) return _SectionHeader(item);
                        final t = item as Task;
                        return TaskTile(
                          task: t,
                          onTap: () => _openForm(t),
                          onToggle: () => _run(() => _service.setCompleted(t.id!, !t.completed)),
                          onDelete: () => _delete(t),
                        );
                      },
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.bucket);
  final TaskBucket bucket;

  @override
  Widget build(BuildContext context) {
    final overdue = bucket == TaskBucket.overdue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(bucket.label,
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, color: overdue ? const Color(0xFFE5534B) : context.c.ink)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.username,
      required this.canChangePassword,
      required this.email,
      required this.searchController,
      required this.onSearch,
      required this.onLogout});
  final String? username;
  final bool canChangePassword;
  final String email;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUsername = username != null && username!.isNotEmpty; // older accounts have none
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.c.header,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 18),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Today, ${DateFormat('d MMM').format(DateTime.now())}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 2),
                  const Text('My tasks', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
                  Text(hasUsername ? '@$username' : email,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
              PopupMenuButton<String>(
                tooltip: 'Account',
                icon: const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (v) {
                  switch (v) {
                    case 'theme':
                      ThemeController.instance.set(isDark ? ThemeMode.light : ThemeMode.dark);
                    case 'password':
                      showDialog(context: context, builder: (_) => const ChangePasswordDialog());
                    default:
                      onLogout();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (hasUsername)
                        Text('@$username',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.c.ink)),
                      Text(email, style: TextStyle(fontSize: 12, color: context.c.muted)),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'theme',
                    child: ListTile(
                      leading: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                      title: Text(isDark ? 'Light mode' : 'Dark mode'),
                    ),
                  ),
                  if (canChangePassword)
                    const PopupMenuItem(
                        value: 'password',
                        child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Change password'))),
                  const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Log out'))),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: searchController,
                onChanged: onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search tasks',
                  isDense: true,
                  filled: true,
                  fillColor: context.c.card,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: searchController,
                    builder: (_, v, __) => v.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              searchController.clear();
                              onSearch('');
                            },
                          ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.priority, required this.status, required this.onPriority, required this.onStatus});
  final Priority? priority;
  final StatusFilter status;
  final ValueChanged<Priority?> onPriority;
  final ValueChanged<StatusFilter> onStatus;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(children: [
        for (final s in StatusFilter.values)
          _chip(context, s.name[0].toUpperCase() + s.name.substring(1), status == s, () => onStatus(s)),
        const SizedBox(width: 8),
        Container(width: 1, height: 22, color: context.c.border),
        const SizedBox(width: 8),
        for (final p in Priority.values)
          _chip(context, '${priorityLabel(p)} priority', priority == p, () => onPriority(priority == p ? null : p),
              color: priorityColor(p)),
      ]),
    );
  }

  Widget _chip(BuildContext context, String label, bool selected, VoidCallback onTap, {Color color = kPrimary}) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: color,
        backgroundColor: c.card,
        side: BorderSide(color: selected ? color : c.border),
        labelStyle: TextStyle(color: selected ? Colors.white : c.ink, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
