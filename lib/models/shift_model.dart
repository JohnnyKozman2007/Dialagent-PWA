import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftModel {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? assignedTo;
  final String assignedToName;
  final String role;
  final bool isAvailable;
  final DateTime createdAt;

  ShiftModel({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.assignedTo,
    this.assignedToName = '',
    this.role = 'Staff',
    this.isAvailable = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'role': role,
      'isAvailable': isAvailable,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'is_available': isAvailable,
    };
  }

  factory ShiftModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return ShiftModel(
      id: id,
      title: map['title'] ?? '',
      startTime: parseDate(map['startTime'] ?? map['start_time']),
      endTime: parseDate(map['endTime'] ?? map['end_time']),
      assignedTo: map['assignedTo'] ?? map['assigned_to'],
      assignedToName: map['assignedToName'] ?? map['assigned_to_name'] ?? '',
      role: map['role'] ?? 'Staff',
      isAvailable: map['isAvailable'] ?? map['is_available'] ?? true,
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
    );
  }
}