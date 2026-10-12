import 'package:flutter/material.dart';
import '../models/task.dart';

Color priorityColor(Priority p) => switch (p) {
      Priority.low => const Color(0xFF4CAF84),
      Priority.medium => const Color(0xFFF5A623),
      Priority.high => const Color(0xFFE5534B),
    };

String priorityLabel(Priority p) => p.name[0].toUpperCase() + p.name.substring(1);

class PriorityChip extends StatelessWidget {
  const PriorityChip(this.priority, {super.key});
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: priorityColor(priority), borderRadius: BorderRadius.circular(10)),
      child: Text(priorityLabel(priority),
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
