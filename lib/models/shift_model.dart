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

  factory ShiftModel.fromMap(String id, Map<String, dynamic> map) {
    return ShiftModel(
      id: id,
      title: map['title'] ?? '',
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedTo: map['assignedTo'],
      assignedToName: map['assignedToName'] ?? '',
      role: map['role'] ?? 'Staff',
      isAvailable: map['isAvailable'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}