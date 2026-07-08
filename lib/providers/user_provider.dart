import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

// Provider that fetches the full UserModel
final userProvider = FutureProvider<UserModel?>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;

  try {
    final data = await client
        .from('users')
        .select()
        .eq('uid', user.id)
        .maybeSingle();

    if (data != null) {
      return UserModel.fromSupabase(data);
    }
    return null;
  } catch (e) {
    return null;
  }
});

// Simple provider that only fetches the role string (for the dashboard)
final userRoleProvider = FutureProvider<String>((ref) async {
  final user = await ref.watch(userProvider.future);
  return user?.role ?? 'Staff';
});