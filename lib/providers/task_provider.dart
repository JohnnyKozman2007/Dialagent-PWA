import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import 'user_provider.dart';

final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;
  final restaurantId = user?.restaurantId;

  if (restaurantId == null || restaurantId.isEmpty) {
    return Stream.value([]);
  }

  // 🔥 Now that the index is deployed, we use orderBy for server-side sorting
  return FirebaseFirestore.instance
      .collection('tasks')
      .where('restaurantId', isEqualTo: restaurantId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Task.fromFirestore(doc))
          .toList());
});
