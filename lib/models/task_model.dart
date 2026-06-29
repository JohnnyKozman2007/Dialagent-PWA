import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      assignedTo: data['assignedTo'],
      assignedToName: data['assignedToName'],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      dueDate: data['dueDate'] != null ? (data['dueDate'] as Timestamp).toDate() : null,
      syncedToCalendar: data['syncedToCalendar'] ?? false,
      calendarEventId: data['calendarEventId'],
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
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'syncedToCalendar': syncedToCalendar,
      'calendarEventId': calendarEventId,
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
