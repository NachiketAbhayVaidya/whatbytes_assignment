import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../theme.dart';
import '../utils/link.dart';
import '../widgets/priority_chip.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, required this.service, this.task});
  final TaskService service;
  final Task? task;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _desc = TextEditingController(text: widget.task?.description);
  late final _link = TextEditingController(text: widget.task?.link);
  late final _pay = TextEditingController(
      text: widget.task?.pay == null ? '' : widget.task!.pay!.toStringAsFixed(widget.task!.pay! % 1 == 0 ? 0 : 2));
  late DateTime _date = widget.task?.dueDate ?? DateTime.now();
  late TimeOfDay? _time =
      (widget.task?.hasTime ?? false) ? TimeOfDay.fromDateTime(widget.task!.dueDate) : null;
  late Priority _priority = widget.task?.priority ?? Priority.medium;
  late int _remind = widget.task?.remindMinutes ?? 0;
  bool _saving = false;

  bool get _editing => widget.task != null;

  /// The date plus the optional time, as one moment.
  DateTime get _dueMoment => DateTime(_date.year, _date.month, _date.day, _time?.hour ?? 0, _time?.minute ?? 0);

  /// True if saving now would make this a past-due task.
  bool get _inPast => Task(
        title: '',
        description: '',
        dueDate: _dueMoment,
        hasTime: _time != null,
        priority: _priority,
      ).isOverdue(DateTime.now());

  /// Reminder choices depend on whether the task has a time of day.
  List<(int, String)> get _remindOptions => _time == null
      ? const [(kNoReminder, 'No reminder'), (0, '9:00 AM on the day'), (1440, '9:00 AM the day before')]
      : const [
          (kNoReminder, 'No reminder'),
          (0, 'At due time'),
          (15, '15 min before'),
          (60, '1 hour before'),
          (1440, '1 day before'),
        ];

  void _fixReminder() {
    if (!_remindOptions.any((o) => o.$1 == _remind)) _remind = 0;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 18, minute: 0));
    if (t != null) {
      setState(() {
        _time = t;
        _fixReminder();
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final payText = _pay.text.trim();
    final t = Task(
      id: widget.task?.id,
      title: _title.text.trim(),
      description: _desc.text.trim(),
      dueDate: _dueMoment,
      hasTime: _time != null,
      priority: _priority,
      completed: widget.task?.completed ?? false,
      completedAt: widget.task?.completedAt,
      pay: payText.isEmpty ? null : double.parse(payText),
      remindMinutes: _remind,
      link: parseLink(_link.text)?.toString(),
    );
    try {
      if (_editing) {
        await widget.service.update(t);
      } else {
        await widget.service.add(t);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save task. Try again.')));
      }
    }
  }

  Future<void> _delete() async {
    final task = widget.task!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.service.delete(task.id!);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not delete task. Try again.')));
      return;
    }
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Deleted "${task.title}"'),
        action: SnackBarAction(label: 'Undo', onPressed: () => widget.service.restore(task).catchError((Object _) {})),
      ));
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _pay.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit task' : 'New task'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete task',
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.shade400,
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _desc,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Due date', suffixIcon: Icon(Icons.calendar_today_outlined)),
                child: Text(DateFormat('EEE, d MMM y').format(_date), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickTime,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Time (optional)',
                  suffixIcon: _time == null
                      ? const Icon(Icons.schedule)
                      : IconButton(
                          tooltip: 'Remove time',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() {
                            _time = null;
                            _fixReminder();
                          }),
                        ),
                ),
                child: Text(_time == null ? 'Any time' : _time!.format(context), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (_inPast && !(widget.task?.completed ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFE5534B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${DateFormat('d MMM y').format(_date)}${_time == null ? '' : ', ${_time!.format(context)}'} '
                      'is in the past, so this task will show as overdue. Pick a later date or time.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFE5534B)),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              key: ValueKey(_time != null), // rebuild when the option list changes
              initialValue: _remind,
              decoration: const InputDecoration(labelText: 'Reminder', prefixIcon: Icon(Icons.notifications_none)),
              borderRadius: BorderRadius.circular(16),
              dropdownColor: c.card,
              items: [for (final o in _remindOptions) DropdownMenuItem(value: o.$1, child: Text(o.$2))],
              onChanged: (v) => setState(() => _remind = v ?? 0),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pay,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?'))],
              decoration: const InputDecoration(labelText: 'Pay for this gig (optional)', prefixText: '₹ '),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _link,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Task link (optional)',
                hintText: 'Job post, brief or map link',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: parseLink(_link.text) == null
                    ? null
                    : IconButton(
                        tooltip: 'Open link',
                        icon: const Icon(Icons.open_in_new, size: 20),
                        onPressed: () => openLink(context, _link.text),
                      ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty || parseLink(v) != null) ? null : 'Enter a valid web link',
            ),
            const SizedBox(height: 20),
            const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SegmentedButton<Priority>(
              showSelectedIcon: false,
              segments: [
                for (final p in Priority.values) ButtonSegment(value: p, label: Text(priorityLabel(p))),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                    (st) => st.contains(WidgetState.selected) ? priorityColor(_priority) : c.field),
                foregroundColor:
                    WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? Colors.white : c.ink),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(_editing ? 'Save changes' : 'Create task'),
            ),
          ]),
        ),
      ),
    );
  }
}
