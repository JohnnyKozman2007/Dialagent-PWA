import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shift_model.dart';

final shiftsProvider = StreamProvider<List<ShiftModel>>((ref) {
  return Supabase.instance.client
      .from('shifts')
      .stream(primaryKey: ['id'])
      .order('start_time')
      .map((data) {
    return data
        .map((map) => ShiftModel.fromMap(map['id'] as String, map))
        .toList();
  });
});

final availableShiftsProvider = StreamProvider<List<ShiftModel>>((ref) {
  return Supabase.instance.client
      .from('shifts')
      .stream(primaryKey: ['id'])
      .order('start_time')
      .map((data) {
    return data
        .map((map) => ShiftModel.fromMap(map['id'] as String, map))
        .where((s) => s.isAvailable)
        .toList();
  });
});