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
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'role': role,
      'isAvailable': isAvailable,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabase() {
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
    return ShiftModel(
      id: id,
      title: map['title'] ?? '',
      startTime: map['startTime'] != null 
          ? (DateTime.tryParse(map['startTime'].toString()) ?? DateTime.now())
          : map['start_time'] != null
              ? (DateTime.tryParse(map['start_time'].toString()) ?? DateTime.now())
              : DateTime.now(),
      endTime: map['endTime'] != null 
          ? (DateTime.tryParse(map['endTime'].toString()) ?? DateTime.now())
          : map['end_time'] != null
              ? (DateTime.tryParse(map['end_time'].toString()) ?? DateTime.now())
              : DateTime.now(),
      assignedTo: map['assignedTo'] ?? map['assigned_to'],
      assignedToName: map['assignedToName'] ?? map['assigned_to_name'] ?? '',
      role: map['role'] ?? 'Staff',
      isAvailable: map['isAvailable'] ?? map['is_available'] ?? true,
      createdAt: map['createdAt'] != null 
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : map['created_at'] != null
              ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
              : DateTime.now(),
    );
  }
}