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
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'restaurantName': restaurantName,
      'restaurantId': restaurantId,
      'phone': phone,
      'address': address,
      'cuisineType': cuisineType,
      'tableCount': tableCount,
      'onboardingCompleted': onboardingCompleted,
      'twoFAEnabled': twoFAEnabled,
      'twoFASecret': twoFASecret,
      'createdAt': createdAt.toIso8601String(),
      'permissions': permissions.toMap(),
      'isApproved': isApproved,
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      'uid': uid,
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
    };
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      role: map['role'] ?? 'Staff',
      restaurantName: map['restaurantName'] ?? '',
      restaurantId: map['restaurantId'] ?? '',
      phone: map['phone'],
      address: map['address'],
      cuisineType: map['cuisineType'],
      tableCount: map['tableCount'],
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      twoFAEnabled: map['twoFAEnabled'] ?? false,
      twoFASecret: map['twoFASecret'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      permissions: map['permissions'] != null
          ? UserPermissions.fromMap(map['permissions'])
          : UserPermissions.staffPermissions(),
      isApproved: map['isApproved'] ?? false,
    );
  }

  factory UserModel.fromSupabase(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
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
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      permissions: map['permissions'] != null
          ? UserPermissions.fromMap(map['permissions'])
          : UserPermissions.staffPermissions(),
      isApproved: map['is_approved'] ?? false,
    );
  }
}
