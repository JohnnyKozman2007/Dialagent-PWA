import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/permissions.dart';

// Provider that fetches the full UserModel
final userProvider = FutureProvider<UserModel?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  try {
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data != null) {
      final model = UserModel.fromMap(user.id, data);

      // Auto-fix permissions for Owner/Manager roles.
      // The RLS policies on menu_categories / menu_items check the
      // permissions JSON column.  Owners & Managers must have full
      // permissions, but the signup flow sets them all to false.
      // We update the DB row (RLS allows users to patch their own row).
      if (model.role == 'Owner' || model.role == 'Manager') {
        final expected = UserPermissions.allPermissions();
        if (!model.permissions.canManageMenu ||
            !model.permissions.canManageStaff ||
            !model.permissions.canManageTables ||
            !model.permissions.canViewRevenue ||
            !model.permissions.canManageReservations ||
            !model.permissions.canViewSettings) {
          try {
            await Supabase.instance.client
                .from('profiles')
                .update({'permissions': expected.toMap()})
                .eq('id', user.id);
            // Return the fixed model
            return UserModel.fromMap(user.id, {
              ...data,
              'permissions': expected.toMap(),
            });
          } catch (_) {
            // If update fails, still return the original model
          }
        }
      }

      return model;
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