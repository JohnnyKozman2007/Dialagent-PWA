import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

// Provider that fetches the full UserModel
final userProvider = FutureProvider<UserModel?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  try {
    final data = await Supabase.instance.client
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .maybeSingle();

    if (data != null) {
      return UserModel.fromMap(user.id, data);
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