import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../theme.dart';
import '../utils/link.dart';
import 'priority_chip.dart';

String formatMoney(double v) => '₹${NumberFormat.decimalPattern('en_IN').format(v)}';

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, required this.onToggle, required this.onTap, required this.onDelete});
  final Task task;
  final VoidCallback onToggle, onTap, onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final overdue = task.isOverdue(DateTime.now());
    final dateText = task.hasTime
        ? DateFormat('d MMM y, h:mm a').format(task.dueDate)
        : DateFormat('d MMM y').format(task.dueDate);
    final subtle = TextStyle(fontSize: 12, color: c.muted);
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // the Firestore stream removes the item
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 0,
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 4, 10),
            child: Row(children: [
              Checkbox(
                value: task.completed,
                shape: const CircleBorder(),
                activeColor: kPrimary,
                onChanged: (_) => onToggle(),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: task.completed ? TextDecoration.lineThrough : null,
                        color: task.completed ? c.muted : c.ink,
                      )),
                  if (task.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: subtle),
                    ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(task.hasTime ? Icons.schedule : Icons.event, size: 13, color: overdue ? Colors.red : c.muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(dateText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: overdue ? Colors.red : c.muted)),
                    ),
                    if (task.remindMinutes != kNoReminder && !task.completed) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.notifications_active_outlined, size: 13, color: c.muted),
                    ],
                  ]),
                  if (task.link != null)
                    InkWell(
                      onTap: () => openLink(context, task.link!),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.link, size: 14, color: kPrimary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(linkHost(task.link!),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w500)),
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                PriorityChip(task.priority),
                if (task.pay != null) ...[
                  const SizedBox(height: 6),
                  Text(formatMoney(task.pay!),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: task.completed ? const Color(0xFF4CAF84) : c.ink)),
                ],
              ]),
              IconButton(
                tooltip: 'Delete task',
                icon: Icon(Icons.delete_outline, size: 20, color: c.muted),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: onDelete,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
