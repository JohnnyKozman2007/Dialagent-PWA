import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../models/shift_model.dart';
import '../../providers/shift_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  List<Map<String, dynamic>> _timecards = [];
  bool _isLoadingTimecards = false;

  @override
  void initState() {
    super.initState();
    _loadTimecards();
  }

  Future<void> _loadTimecards() async {
    setState(() => _isLoadingTimecards = true);
    try {
      final data = await ApiService.getTimecards();
      setState(() {
        _timecards = data;
      });
    } catch (e) {
      debugPrint('Error loading timecards: $e');
    } finally {
      setState(() => _isLoadingTimecards = false);
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${_formatTime(dt)}';
  }

  Future<void> _deleteShift(String id) async {
    try {
      final client = Supabase.instance.client;
      await client.from('shifts').delete().eq('id', id);
      ref.invalidate(shiftsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _claimShift(String id) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.from('shifts').update({
        'assigned_to': user.id,
        'assigned_to_name': user.email ?? '',
      }).eq('id', id);
      ref.invalidate(shiftsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift claimed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error claiming shift: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final roleAsync = ref.watch(userRoleProvider);
    final shiftsAsync = ref.watch(shiftsProvider);

    return roleAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (String role) {
        final isManager = role == 'Owner' || role == 'Manager';

        if (isManager) {
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Shift & Timecard Manager'),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/dashboard'),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddShiftDialog(context),
                  ),
                ],
                bottom: const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.calendar_month), text: 'Shift Scheduling'),
                    Tab(icon: Icon(Icons.assignment), text: 'Staff Timesheets'),
                  ],
                  indicatorColor: Colors.white,
                ),
              ),
              body: TabBarView(
                children: [
                  _buildShiftsList(shiftsAsync, user, isManager),
                  _buildTimesheetsTab(),
                ],
              ),
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Shift Board'),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/dashboard'),
              ),
            ),
            body: _buildShiftsList(shiftsAsync, user, isManager),
          );
        }
      },
    );
  }

  Widget _buildShiftsList(AsyncValue<List<ShiftModel>> shiftsAsync, User? user, bool isManager) {
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

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(shiftsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: shifts.length,
            itemBuilder: (context, index) {
              final shift = shifts[index];
              final isAssignedToMe = shift.assignedTo == user?.id;

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
                      const SizedBox(height: 4),
                      Text(
                        shift.assignedToName.isNotEmpty
                            ? 'Assigned to: ${shift.assignedToName}'
                            : 'Available (Unassigned)',
                        style: TextStyle(
                          fontSize: 12,
                          color: shift.assignedToName.isNotEmpty ? Colors.teal : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  trailing: isManager
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.grey),
                              onPressed: () => _showEditShiftDialog(context, shift),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteShift(shift.id),
                            ),
                          ],
                        )
                      : (!isAssignedToMe && shift.assignedToName.isEmpty
                          ? ElevatedButton(
                              onPressed: () => _claimShift(shift.id),
                              child: const Text('Claim'),
                            )
                          : const SizedBox.shrink()),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTimesheetsTab() {
    if (_isLoadingTimecards) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    if (_timecards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No clock-in records yet',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              Text(
                'Staff members will appear here when they clock in.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Aggregate hours and lateness per staff member email
    final Map<String, Map<String, dynamic>> summary = {};
    for (final tc in _timecards) {
      final email = tc['email'] ?? 'Unknown';
      final hours = (tc['hours_worked'] as num?)?.toDouble() ?? 0.0;
      final lateMins = (tc['minutes_late'] as num?)?.toInt() ?? 0;
      final isLate = lateMins > 0;

      if (!summary.containsKey(email)) {
        summary[email] = {
          'hours': 0.0,
          'lateCount': 0,
          'lateMinutes': 0,
        };
      }

      summary[email]!['hours'] = summary[email]!['hours'] + hours;
      if (isLate) {
        summary[email]!['lateCount'] = summary[email]!['lateCount'] + 1;
        summary[email]!['lateMinutes'] = summary[email]!['lateMinutes'] + lateMins;
      }
    }

    return RefreshIndicator(
      onRefresh: _loadTimecards,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section 1: Staff Performance Summary
          const Text(
            'Staff Performance Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Staff Member')),
                    DataColumn(label: Text('Total Hours')),
                    DataColumn(label: Text('Lateness Count')),
                    DataColumn(label: Text('Total Late Mins')),
                  ],
                  rows: summary.entries.map((entry) {
                    return DataRow(cells: [
                      DataCell(Text(entry.key)),
                      DataCell(Text('${entry.value['hours'].toStringAsFixed(2)} hrs')),
                      DataCell(Text('${entry.value['lateCount']} times',
                          style: TextStyle(
                              color: entry.value['lateCount'] > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold))),
                      DataCell(Text('${entry.value['lateMinutes']} mins')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Section 2: Detailed Timecard Logs
          const Text(
            'Detailed Timecard Logs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _timecards.length,
            itemBuilder: (context, index) {
              final tc = _timecards[index];
              final email = tc['email'] ?? 'Unknown';
              final clockIn = DateTime.parse(tc['clock_in_time']).toLocal();
              final clockOut = tc['clock_out_time'] != null
                  ? DateTime.parse(tc['clock_out_time']).toLocal()
                  : null;
              final hours = tc['hours_worked'] ?? 0.0;
              final lateMins = tc['minutes_late'] ?? 0;
              final tcId = tc['id'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: clockOut != null
                                  ? Colors.grey.shade200
                                  : Colors.green.withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              clockOut != null ? 'Completed' : 'Active (Working)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: clockOut != null ? Colors.grey : Colors.green),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.login, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('In: ${_formatDateTime(clockIn)}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.logout, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(clockOut != null
                              ? 'Out: ${_formatDateTime(clockOut)}'
                              : 'Out: —'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Worked: ${hours.toStringAsFixed(2)} hrs',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (lateMins > 0)
                            Text(
                              '⚠️ Late: $lateMins mins',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                            )
                          else
                            const Text(
                              '✓ On Time',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                        ],
                      ),
                      if (clockOut == null) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            setState(() => _isLoadingTimecards = true);
                            try {
                              await ApiService.clockOut(tcId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Employee successfully clocked out.')),
                                );
                              }
                              await _loadTimecards();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              setState(() => _isLoadingTimecards = false);
                            }
                          },
                          icon: const Icon(Icons.exit_to_app, size: 16),
                          label: const Text('Force Clock Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade800,
                            minimumSize: const Size(double.infinity, 36),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddShiftDialog(BuildContext context) {
    final titleController = TextEditingController();
    DateTime startTime = DateTime.now();
    DateTime endTime = DateTime.now().add(const Duration(hours: 8));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Shift'),
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
                final client = Supabase.instance.client;
                final user = client.auth.currentUser;
                if (user == null) return;

                final profile = await client.from('users').select('restaurant_id').eq('uid', user.id).single();
                final restaurantId = profile['restaurant_id'];

                await client.from('shifts').insert({
                  'title': titleController.text,
                  'start_time': startTime.toIso8601String(),
                  'end_time': endTime.toIso8601String(),
                  'restaurant_id': restaurantId,
                });

                if (context.mounted) {
                  Navigator.pop(context);
                }
                ref.invalidate(shiftsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shift created!')),
                  );
                }
              },
              child: const Text('Add'),
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
                final client = Supabase.instance.client;
                await client
                    .from('shifts')
                    .update({
                  'title': titleController.text,
                  'start_time': startTime.toIso8601String(),
                  'end_time': endTime.toIso8601String(),
                })
                    .eq('id', shift.id);

                if (context.mounted) {
                  Navigator.pop(context);
                }
                ref.invalidate(shiftsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shift updated!')),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}