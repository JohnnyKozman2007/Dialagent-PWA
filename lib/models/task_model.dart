import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp; // keep as fallback if still referenced, but parse dynamically
import 'package:equatable/equatable.dart';

class Task extends Equatable {
  final String id;
  final String title;
  final String description;
  final String restaurantId;
  final String? assignedTo;      // user UID
  final String? assignedToName;
  final String status;           // 'pending', 'in-progress', 'completed'
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool syncedToCalendar;
  final String? calendarEventId; // from Google Calendar

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.restaurantId,
    this.assignedTo,
    this.assignedToName,
    this.status = 'pending',
    required this.createdAt,
    this.dueDate,
    this.syncedToCalendar = false,
    this.calendarEventId,
  });

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return Task(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      restaurantId: map['restaurantId'] ?? map['restaurant_id'] ?? '',
      assignedTo: map['assignedTo'] ?? map['assigned_to'],
      assignedToName: map['assignedToName'] ?? map['assigned_to_name'],
      status: map['status'] ?? 'pending',
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      dueDate: map['dueDate'] != null || map['due_date'] != null
          ? parseDate(map['dueDate'] ?? map['due_date'])
          : null,
      syncedToCalendar: map['syncedToCalendar'] ?? map['synced_to_calendar'] ?? false,
      calendarEventId: map['calendarEventId'] ?? map['calendar_event_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'restaurantId': restaurantId,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'status': status,
      'createdAt': createdAt,
      'dueDate': dueDate,
      'syncedToCalendar': syncedToCalendar,
      'calendarEventId': calendarEventId,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'title': title,
      'description': description,
      'restaurant_id': restaurantId,
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'synced_to_calendar': syncedToCalendar,
      'calendar_event_id': calendarEventId,
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? restaurantId,
    String? assignedTo,
    String? assignedToName,
    String? status,
    DateTime? createdAt,
    DateTime? dueDate,
    bool? syncedToCalendar,
    String? calendarEventId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      restaurantId: restaurantId ?? this.restaurantId,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      syncedToCalendar: syncedToCalendar ?? this.syncedToCalendar,
      calendarEventId: calendarEventId ?? this.calendarEventId,
    );
  }

  @override
  List<Object?> get props => [id, title, status, assignedTo, dueDate];
}
