import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import 'user_provider.dart';

final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;
  final restaurantId = user?.restaurantId;
  final role = user?.role ?? 'Staff';
  final uid = user?.uid;

  if (restaurantId == null || restaurantId.isEmpty) {
    return Stream.value([]);
  }

  // Staff only see tasks assigned to themselves.
  // Owner and Manager see all tasks for the restaurant.
  if (role == 'Staff') {
    if (uid == null || uid.isEmpty) return Stream.value([]);
    return Supabase.instance.client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .map((maps) {
          final tasks = maps
              .map((map) => Task.fromMap(map['id'] as String, map))
              .where((task) => task.assignedTo == uid)
              .toList();
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tasks;
        });
  } else {
    // Owner / Manager — all tasks
    return Supabase.instance.client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .map((maps) {
          final tasks =
              maps.map((map) => Task.fromMap(map['id'] as String, map)).toList();
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tasks;
        });
  }
});
