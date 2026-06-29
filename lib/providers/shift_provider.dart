import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift_model.dart';

final shiftsProvider = StreamProvider<List<ShiftModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('shifts')
      .orderBy('startTime')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => ShiftModel.fromMap(doc.id, doc.data()))
        .toList();
  });
});

final availableShiftsProvider = StreamProvider<List<ShiftModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('shifts')
      .where('isAvailable', isEqualTo: true)
      .orderBy('startTime')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => ShiftModel.fromMap(doc.id, doc.data()))
        .toList();
  });
});