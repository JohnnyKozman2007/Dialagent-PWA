import 'permissions.dart';

class UserModel {
  final String uid;
  final String email;
  final String role;
  final String restaurantName;
  final String restaurantId;
  final String? phone;
  final String? address;
  final String? cuisineType;
  final int? tableCount;
  final bool onboardingCompleted;
  final bool twoFAEnabled;
  final String? twoFASecret;
  final DateTime createdAt;
  final UserPermissions permissions;
  final bool isApproved;
  final String? stripeMerchandiseId;

  UserModel({
    required this.uid,
    required this.email,
    this.role = 'Staff',
    this.restaurantName = '',
    this.restaurantId = '',
    this.phone,
    this.address,
    this.cuisineType,
    this.tableCount,
    this.onboardingCompleted = false,
    this.twoFAEnabled = false,
    this.twoFASecret,
    required this.createdAt,
    this.permissions = const UserPermissions(),
    this.isApproved = false,
    this.stripeMerchandiseId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'email': email,
      'role': role,
      'restaurant_name': restaurantName,
      'restaurant_id': restaurantId,
      'phone': phone,
      'address': address,
      'cuisine_type': cuisineType,
      'table_count': tableCount,
      'onboarding_completed': onboardingCompleted,
      'two_fa_enabled': twoFAEnabled,
      'two_fa_secret': twoFASecret,
      'created_at': createdAt.toIso8601String(),
      'permissions': permissions.toMap(),
      'is_approved': isApproved,
      'stripe_merchandise_id': stripeMerchandiseId,
    };
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      role: map['role'] ?? 'Staff',
      restaurantName: map['restaurant_name'] ?? '',
      restaurantId: map['restaurant_id'] ?? '',
      phone: map['phone'],
      address: map['address'],
      cuisineType: map['cuisine_type'],
      tableCount: map['table_count'],
      onboardingCompleted: map['onboarding_completed'] ?? false,
      twoFAEnabled: map['two_fa_enabled'] ?? false,
      twoFASecret: map['two_fa_secret'],
      createdAt: parseDateTime(map['created_at']),
      permissions: map['permissions'] != null
          ? UserPermissions.fromMap(map['permissions'])
          : UserPermissions.staffPermissions(),
      isApproved: map['is_approved'] ?? false,
      stripeMerchandiseId: map['stripe_merchandise_id'],
    );
  }
}
