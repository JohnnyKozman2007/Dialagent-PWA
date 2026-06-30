import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import 'user_provider.dart';

final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;
  final restaurantId = user?.restaurantId;

  if (restaurantId == null || restaurantId.isEmpty) {
    return Stream.value([]);
  }

  return Supabase.instance.client
      .from('tasks')
      .stream(primaryKey: ['id'])
      .eq('restaurant_id', restaurantId)
      .order('created_at', ascending: false)
      .map((list) => list
          .map((map) => Task.fromMap(map['id'] as String, map))
          .toList());
});
