import 'package:cloud_firestore/cloud_firestore.dart';
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
      'createdAt': createdAt,
      'permissions': permissions.toMap(),
      'isApproved': isApproved,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
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
      'permissions': permissions.toMap(),
      'is_approved': isApproved,
    };
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      if (val is DateTime) return val;
      return DateTime.now();
    }

    final permissionsRaw = map['permissions'];
    UserPermissions parsedPermissions = UserPermissions.staffPermissions();
    if (permissionsRaw is Map) {
      parsedPermissions = UserPermissions.fromMap(Map<String, dynamic>.from(permissionsRaw));
    }

    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      role: map['role'] ?? 'Staff',
      restaurantName: map['restaurantName'] ?? map['restaurant_name'] ?? '',
      restaurantId: map['restaurantId'] ?? map['restaurant_id'] ?? '',
      phone: map['phone'],
      address: map['address'],
      cuisineType: map['cuisineType'] ?? map['cuisine_type'],
      tableCount: map['tableCount'] ?? map['table_count'],
      onboardingCompleted: map['onboardingCompleted'] ?? map['onboarding_completed'] ?? false,
      twoFAEnabled: map['twoFAEnabled'] ?? map['two_fa_enabled'] ?? false,
      twoFASecret: map['twoFASecret'] ?? map['two_fa_secret'],
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      permissions: parsedPermissions,
      isApproved: map['isApproved'] ?? map['is_approved'] ?? false,
    );
  }
}
