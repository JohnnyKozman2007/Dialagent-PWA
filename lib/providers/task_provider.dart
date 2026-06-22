import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_restaurant_app/models/task_model.dart';
import 'package:my_restaurant_app/services/calendar_sync_service.dart';
import 'package:my_restaurant_app/providers/user_provider.dart';

// Provider to get the current restaurantId from user provider
final restaurantIdProvider = Provider<String?>((ref) {
  final user = ref.watch(userProvider); // Assume you have a userProvider
  return user?.restaurantId;
});

// Provider that fetches tasks for the current restaurant
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

// Provider to create a task
final createTaskProvider = FutureProvider.family<void, Task>((ref, task) async {
  final docRef = await FirebaseFirestore.instance.collection('tasks').add(task.toMap());
  // After creation, sync to Google Calendar via service
  await CalendarSyncService.syncTaskToCalendar(task.copyWith(id: docRef.id));
});

// Provider to update a task
final updateTaskProvider = FutureProvider.family<void, Task>((ref, task) async {
  await FirebaseFirestore.instance.collection('tasks').doc(task.id).update(task.toMap());
  await CalendarSyncService.syncTaskToCalendar(task);
});

// Provider to delete a task
final deleteTaskProvider = FutureProvider.family<void, String>((ref, taskId) async {
  // Fetch task to get calendarEventId before deleting
  final doc = await FirebaseFirestore.instance.collection('tasks').doc(taskId).get();
  if (doc.exists) {
    final task = Task.fromFirestore(doc);
    await CalendarSyncService.deleteCalendarEvent(task.calendarEventId);
  }
  await FirebaseFirestore.instance.collection('tasks').doc(taskId).delete();
});

// Provider to claim/unclaim task (assign to current user)
final claimTaskProvider = FutureProvider.family<void, String>((ref, taskId) async {
  final user = ref.read(userProvider);
  if (user == null) throw Exception('User not logged in');

  final doc = FirebaseFirestore.instance.collection('tasks').doc(taskId);
  final snapshot = await doc.get();
  final task = Task.fromFirestore(snapshot);

  String newStatus;
  String? assignedTo;
  String? assignedToName;

  if (task.assignedTo == user.uid) {
    // Unclaim
    assignedTo = null;
    assignedToName = null;
    newStatus = 'pending';
  } else {
    // Claim
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
