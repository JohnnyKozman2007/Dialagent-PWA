import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/shift_model.dart';
import '../../providers/shift_provider.dart';
import '../../providers/user_provider.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final roleAsync = ref.watch(userRoleProvider);
    final shiftsAsync = ref.watch(shiftsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Management'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          roleAsync.when(
            data: (role) {
              if (role == 'Owner' || role == 'Manager') {
                return IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddShiftDialog(context),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: roleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (String role) {
          final isManager = role == 'Owner' || role == 'Manager';

          return shiftsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (List<ShiftModel> shifts) {
              if (shifts.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No shifts created yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      Text(
                        'Tap the + button to create one',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: shifts.length,
                itemBuilder: (context, index) {
                  final shift = shifts[index];
                  final isAssignedToMe = shift.assignedTo == user?.uid;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        shift.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '${_formatTime(shift.startTime)} - ${_formatTime(shift.endTime)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (shift.assignedTo != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Assigned to: ${shift.assignedToName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ] else if (shift.isAvailable) ...[
                            const SizedBox(height: 4),
                            Text(
                              '🟢 Available',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: isManager
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEditShiftDialog(context, shift),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteShift(shift.id),
                                ),
                              ],
                            )
                          : (shift.isAvailable && shift.assignedTo == null
                              ? ElevatedButton(
                                  onPressed: () => _assignShiftToMe(shift.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Take Shift'),
                                )
                              : (isAssignedToMe
                                  ? ElevatedButton(
                                      onPressed: () => _unassignShift(shift.id),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Drop Shift'),
                                    )
                                  : const SizedBox.shrink())),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _assignShiftToMe(String shiftId) async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('shifts').doc(shiftId).update({
        'assignedTo': user.uid,
        'assignedToName': user.email,
        'isAvailable': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift assigned to you!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _unassignShift(String shiftId) async {
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('shifts').doc(shiftId).update({
        'assignedTo': null,
        'assignedToName': '',
        'isAvailable': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift dropped!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _deleteShift(String shiftId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: const Text('Are you sure you want to delete this shift?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await FirebaseFirestore.instance.collection('shifts').doc(shiftId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift deleted!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  void _showAddShiftDialog(BuildContext context) {
    final titleController = TextEditingController();
    DateTime startTime = DateTime.now().add(const Duration(hours: 1));
    DateTime endTime = DateTime.now().add(const Duration(hours: 3));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Shift Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(_formatTime(startTime)),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(startTime),
                    );
                    if (time != null) {
                      setState(() {
                        startTime = DateTime(
                          startTime.year,
                          startTime.month,
                          startTime.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(_formatTime(endTime)),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(endTime),
                    );
                    if (time != null) {
                      setState(() {
                        endTime = DateTime(
                          endTime.year,
                          endTime.month,
                          endTime.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a title')),
                  );
                  return;
                }

                await FirebaseFirestore.instance.collection('shifts').add({
                  'title': titleController.text,
                  'startTime': startTime,
                  'endTime': endTime,
                  'assignedTo': null,
                  'assignedToName': '',
                  'role': 'Staff',
                  'isAvailable': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shift created!')),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditShiftDialog(BuildContext context, ShiftModel shift) {
    final titleController = TextEditingController(text: shift.title);
    DateTime startTime = shift.startTime;
    DateTime endTime = shift.endTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Shift Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(_formatTime(startTime)),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(startTime),
                    );
                    if (time != null) {
                      setState(() {
                        startTime = DateTime(
                          startTime.year,
                          startTime.month,
                          startTime.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(_formatTime(endTime)),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(endTime),
                    );
                    if (time != null) {
                      setState(() {
                        endTime = DateTime(
                          endTime.year,
                          endTime.month,
                          endTime.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('shifts')
                    .doc(shift.id)
                    .update({
                  'title': titleController.text,
                  'startTime': startTime,
                  'endTime': endTime,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shift updated!')),
                );
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}