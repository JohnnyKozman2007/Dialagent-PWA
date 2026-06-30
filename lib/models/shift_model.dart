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
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'role': role,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ShiftModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }
    return ShiftModel(
      id: id,
      title: map['title'] ?? '',
      startTime: parseDateTime(map['start_time']),
      endTime: parseDateTime(map['end_time']),
      assignedTo: map['assigned_to'],
      assignedToName: map['assigned_to_name'] ?? '',
      role: map['role'] ?? 'Staff',
      isAvailable: map['is_available'] ?? true,
      createdAt: parseDateTime(map['created_at']),
    );
  }
}