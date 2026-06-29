import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

// Provider that fetches the full UserModel
final userProvider = FutureProvider<UserModel?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      return UserModel.fromMap(user.uid, doc.data()!);
    }
    return null;
  } catch (e) {
    print('Error fetching user: $e');
    return null;
  }
});

// Simple provider that only fetches the role string (for the dashboard)
final userRoleProvider = FutureProvider<String>((ref) async {
  final user = await ref.watch(userProvider.future);
  return user?.role ?? 'Staff';
});