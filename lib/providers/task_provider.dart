import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_restaurant_app/models/task_model.dart';
import 'package:my_restaurant_app/services/calendar_sync_service.dart';
import 'package:my_restaurant_app/providers/user_provider.dart';

final restaurantIdProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(userProvider);
  final user = userAsync.value;  // ✅ Extract the actual user
  return user?.restaurantId;
});

final taskListProvider = FutureProvider<List<Task>>((ref) async {
  final restaurantId = ref.watch(restaurantIdProvider);
  if (restaurantId == null) throw Exception('No restaurant ID');

  final snapshot = await FirebaseFirestore.instance
      .collection('tasks')
      .where('restaurantId', isEqualTo: restaurantId)
      .orderBy('createdAt', descending: true)
      .get();

  return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
});

final createTaskProvider = FutureProvider.family<void, Task>((ref, task) async {
  final docRef = await FirebaseFirestore.instance.collection('tasks').add(task.toMap());
  await CalendarSyncService.syncTaskToCalendar(task.copyWith(id: docRef.id));
});

final updateTaskProvider = FutureProvider.family<void, Task>((ref, task) async {
  await FirebaseFirestore.instance.collection('tasks').doc(task.id).update(task.toMap());
  await CalendarSyncService.syncTaskToCalendar(task);
});

final deleteTaskProvider = FutureProvider.family<void, String>((ref, taskId) async {
  final doc = await FirebaseFirestore.instance.collection('tasks').doc(taskId).get();
  if (doc.exists) {
    final task = Task.fromFirestore(doc);
    await CalendarSyncService.deleteCalendarEvent(task.calendarEventId);
  }
  await FirebaseFirestore.instance.collection('tasks').doc(taskId).delete();
});

final claimTaskProvider = FutureProvider.family<void, String>((ref, taskId) async {
  final userAsync = ref.read(userProvider);
  final user = userAsync.value;  // ✅ Extract the actual user
  if (user == null) throw Exception('User not logged in');

  final doc = FirebaseFirestore.instance.collection('tasks').doc(taskId);
  final snapshot = await doc.get();
  final task = Task.fromFirestore(snapshot);

  String newStatus;
  String? assignedTo;
  String? assignedToName;

  if (task.assignedTo == user.uid) {
    assignedTo = null;
    assignedToName = null;
    newStatus = 'pending';
  } else {
    assignedTo = user.uid;
    assignedToName = user.displayName ?? user.email;
    newStatus = 'in-progress';
  }

  final updatedTask = task.copyWith(
    assignedTo: assignedTo,
    assignedToName: assignedToName,
    status: newStatus,
  );

  await doc.update(updatedTask.toMap());
  await CalendarSyncService.syncTaskToCalendar(updatedTask);
});
