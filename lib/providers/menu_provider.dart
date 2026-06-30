import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_provider.dart';

// Provider for fetching menu categories
final menuCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = await ref.watch(userProvider.future);
  if (user == null) return [];

  final res = await Supabase.instance.client
      .from('menu_categories')
      .select()
      .eq('restaurant_name', user.restaurantName)
      .order('name');
  
  return List<Map<String, dynamic>>.from(res);
});

// Provider for fetching menu items
final menuItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = await ref.watch(userProvider.future);
  if (user == null) return [];

  final res = await Supabase.instance.client
      .from('menu_items')
      .select()
      .eq('restaurant_name', user.restaurantName)
      .order('name');

  return List<Map<String, dynamic>>.from(res);
});
