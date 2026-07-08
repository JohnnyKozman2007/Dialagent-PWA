import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shift_model.dart';
import 'user_provider.dart';

final shiftsProvider = StreamProvider<List<ShiftModel>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;
  final restaurantId = user?.restaurantId;
  if (restaurantId == null || restaurantId.isEmpty) {
    return Stream.value([]);
  }

  return Supabase.instance.client
      .from('shifts')
      .stream(primaryKey: ['id'])
      .eq('restaurant_id', restaurantId)
      .map((maps) {
        final shifts = maps.map((map) => ShiftModel.fromMap(map['id'] as String, map)).toList();
        shifts.sort((a, b) => a.startTime.compareTo(b.startTime)); // ascending order
        return shifts;
      });
});

final availableShiftsProvider = StreamProvider<List<ShiftModel>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;
  final restaurantId = user?.restaurantId;
  if (restaurantId == null || restaurantId.isEmpty) {
    return Stream.value([]);
  }

  return Supabase.instance.client
      .from('shifts')
      .stream(primaryKey: ['id'])
      .eq('restaurant_id', restaurantId)
      .map((maps) {
        final shifts = maps
            .map((map) => ShiftModel.fromMap(map['id'] as String, map))
            .where((shift) => shift.isAvailable)
            .toList();
        shifts.sort((a, b) => a.startTime.compareTo(b.startTime)); // ascending order
        return shifts;
      });
});