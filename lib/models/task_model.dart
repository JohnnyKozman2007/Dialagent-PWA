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
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }
    DateTime? parseNullableDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return null;
    }
    return Task(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      restaurantId: map['restaurant_id'] ?? '',
      assignedTo: map['assigned_to'],
      assignedToName: map['assigned_to_name'],
      status: map['status'] ?? 'pending',
      createdAt: parseDateTime(map['created_at']),
      dueDate: parseNullableDateTime(map['due_date']),
      syncedToCalendar: map['synced_to_calendar'] ?? false,
      calendarEventId: map['calendar_event_id'],
    );
  }

  Map<String, dynamic> toMap() {
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
