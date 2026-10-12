import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

class TaskService {
  TaskService(this.uid);
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('tasks');

  /// Streams tasks sorted by due date (earliest first).
  Stream<List<Task>> watch() =>
      _col.orderBy('dueDate').snapshots().map((s) => s.docs.map(Task.fromDoc).toList());

  Future<void> add(Task t) => _col.add(t.toMap());
  Future<void> update(Task t) => _col.doc(t.id).update(t.toMap());
  Future<void> delete(String id) => _col.doc(id).delete();

  /// Re-creates a deleted task under its original id (used by Undo).
  Future<void> restore(Task t) => _col.doc(t.id).set(t.toMap());

  Future<void> setCompleted(String id, bool done) => _col.doc(id).update({
        'completed': done,
        'completedAt': done ? Timestamp.now() : null,
      });
}
