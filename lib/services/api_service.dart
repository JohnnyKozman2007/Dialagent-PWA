import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static const String backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');

  // Helper to get headers with Supabase Auth token if logged in
  static Map<String, String> _getHeaders() {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // AUTH-01: Login / Sign up authentication gate
  static Future<Map<String, dynamic>> authenticate(String email, String password, String action) async {
    if (backendUrl.isNotEmpty) {
      final response = await http.post(
        Uri.parse('$backendUrl/auth/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'action': action,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Authentication failed');
      }
    } else {
      // Direct Supabase fallback authentication
      final client = Supabase.instance.client;
      if (action == 'LOGIN') {
        final res = await client.auth.signInWithPassword(email: email, password: password);
        return {'user': res.user?.toJson(), 'session': res.session?.toJson()};
      } else {
        final res = await client.auth.signUp(email: email, password: password);
        return {'user': res.user?.toJson(), 'session': res.session?.toJson()};
      }
    }
  }

  // AUTH-02: Get role evaluation details
  static Future<Map<String, dynamic>> getMe() async {
    if (backendUrl.isNotEmpty) {
      final response = await http.get(
        Uri.parse('$backendUrl/auth/me'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch user metadata');
      }
    } else {
      // Direct Supabase fallback
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final data = await client.from('users').select().eq('uid', user.id).maybeSingle();
      return data ?? {};
    }
  }

  // BO-03: Get backoffice analytics
  static Future<List<Map<String, dynamic>>> getBackofficeAnalytics() async {
    if (backendUrl.isNotEmpty) {
      final response = await http.get(
        Uri.parse('$backendUrl/backoffice/analytics?range=today'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to fetch analytics');
      }
    } else {
      // Simulate/mock analytics since database is fresh
      return [
        {'title': 'Total Restaurants', 'value': '12', 'change': '+2 this week'},
        {'title': 'Active Phone Orders', 'value': '87', 'change': 'Live call tracking active'},
        {'title': 'Web Orders', 'value': '143', 'change': '98% success rate'},
        {'title': 'VoIP Lines Connected', 'value': '4', 'change': 'Latency 24ms'},
        {'title': 'Support Tickets Open', 'value': '3', 'change': '2 pending assignment'},
      ];
    }
  }

  // BO-02: Get support tickets
  static Future<List<Map<String, dynamic>>> getSupportTickets() async {
    if (backendUrl.isNotEmpty) {
      final response = await http.get(
        Uri.parse('$backendUrl/backoffice/support/tickets?status=OPEN&limit=20'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to fetch tickets');
      }
    } else {
      // Mock support tickets
      return [
        {'id': '101', 'subject': 'POS Printer Offline', 'restaurant': 'Le Parisien', 'priority': 'HIGH', 'status': 'OPEN'},
        {'id': '102', 'subject': 'VoIP Port Binding Error (5060)', 'restaurant': 'Pizza Gusto', 'priority': 'HIGH', 'status': 'OPEN'},
        {'id': '103', 'subject': 'Stripe payout setup assistance', 'restaurant': 'Sushi Bar', 'priority': 'MEDIUM', 'status': 'OPEN'},
      ];
    }
  }

  // BO-04: Fraud detection / Restaurant validation panel
  static Future<List<Map<String, dynamic>>> getPendingRestaurants() async {
    if (backendUrl.isNotEmpty) {
      final response = await http.get(
        Uri.parse('$backendUrl/backoffice/restaurants/pending'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load pending restaurants');
      }
    } else {
      // Fallback: Query all users/restaurants that are not yet approved
      final client = Supabase.instance.client;
      final data = await client
          .from('users')
          .select()
          .eq('role', 'Owner')
          .eq('is_approved', false);
      return List<Map<String, dynamic>>.from(data);
    }
  }

  // BO-04: Verify (Approve / Reject) restaurant onboarding requests
  static Future<void> verifyRestaurant(String uid, String action) async {
    if (backendUrl.isNotEmpty) {
      final response = await http.patch(
        Uri.parse('$backendUrl/backoffice/restaurants/$uid/verify'),
        headers: _getHeaders(),
        body: jsonEncode({'action': action}),
      );
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to verify restaurant');
      }
    } else {
      // Fallback: Direct DB update
      final client = Supabase.instance.client;
      if (action == 'APPROVE') {
        await client.from('users').update({
          'is_approved': true,
        }).eq('uid', uid);
      } else {
        // Reject - we can delete or keep unapproved
        await client.from('users').update({
          'is_approved': false,
        }).eq('uid', uid);
      }
    }
  }
}
