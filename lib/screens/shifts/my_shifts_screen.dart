import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../models/shift_model.dart';
import '../../providers/shift_provider.dart';
import '../../services/api_service.dart';

class MyShiftsScreen extends ConsumerStatefulWidget {
  const MyShiftsScreen({super.key});

  @override
  ConsumerState<MyShiftsScreen> createState() => _MyShiftsScreenState();
}

class _MyShiftsScreenState extends ConsumerState<MyShiftsScreen> {
  Map<String, dynamic>? _currentTimecard;
  bool _isLoadingTimecard = false;
  ShiftModel? _selectedShiftForClockIn;

  @override
  void initState() {
    super.initState();
    _loadTimecard();
  }

  Future<void> _loadTimecard() async {
    setState(() => _isLoadingTimecard = true);
    try {
      final timecard = await ApiService.getCurrentTimecard();
      setState(() {
        _currentTimecard = timecard;
      });
    } catch (e) {
      debugPrint('Error loading timecard: $e');
    } finally {
      setState(() => _isLoadingTimecard = false);
    }
  }

  Future<void> _clockIn() async {
    setState(() => _isLoadingTimecard = true);
    try {
      final shift = _selectedShiftForClockIn;
      await ApiService.clockIn(shift?.id, shift?.startTime);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🕒 Clocked in successfully!'), backgroundColor: Colors.green),
      );
      await _loadTimecard();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clocking in: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoadingTimecard = false);
    }
  }

  Future<void> _clockOut() async {
    if (_currentTimecard == null) return;
    setState(() => _isLoadingTimecard = true);
    try {
      await ApiService.clockOut(_currentTimecard!['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🏁 Clocked out successfully!'), backgroundColor: Colors.orange),
      );
      await _loadTimecard();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clocking out: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoadingTimecard = false);
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final shiftsAsync = ref.watch(shiftsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shifts & Clock In/Out'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: Column(
        children: [
          // --- Clock In/Out UI Card ---
          _isLoadingTimecard
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator(color: Colors.teal)),
                )
              : Card(
                  margin: const EdgeInsets.all(16.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Timecard Terminal',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _currentTimecard != null
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _currentTimecard != null ? '● CLOCKED IN' : '○ CLOCKED OUT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _currentTimecard != null ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_currentTimecard != null) ...[
                          Text(
                            'Active Session started at: ${_formatTime(DateTime.parse(_currentTimecard!['clock_in_time']).toLocal())}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          if (_currentTimecard!['minutes_late'] > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '⚠️ You were flagged late by ${_currentTimecard!['minutes_late']} mins.',
                              style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _clockOut,
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('CLOCK OUT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Ready to begin your shift? Select your assigned shift today (optional) and click Clock In:',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          shiftsAsync.when(
                            loading: () => const SizedBox(),
                            error: (e, s) => const SizedBox(),
                            data: (List<ShiftModel> allShifts) {
                              final todayMyShifts = allShifts.where((s) {
                                final isMe = s.assignedTo == user?.id;
                                final isToday = s.startTime.day == DateTime.now().day &&
                                    s.startTime.month == DateTime.now().month &&
                                    s.startTime.year == DateTime.now().year;
                                return isMe && isToday;
                              }).toList();

                              if (todayMyShifts.isEmpty) {
                                return const Text(
                                  'No shifts scheduled for you today. Clocking in will log unscheduled hours.',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                                );
                              }

                              return DropdownButtonFormField<ShiftModel>(
                                decoration: const InputDecoration(
                                  labelText: 'Select Scheduled Shift',
                                  border: OutlineInputBorder(),
                                ),
                                value: _selectedShiftForClockIn,
                                items: todayMyShifts.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text('${s.title} (${_formatTime(s.startTime)} - ${_formatTime(s.endTime)})'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedShiftForClockIn = val;
                                  });
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _clockIn,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('CLOCK IN'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

          const Divider(height: 1),

          // --- My Shift List ---
          Expanded(
            child: shiftsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (List<ShiftModel> shifts) {
                final myShifts = shifts.where((s) => s.assignedTo == user?.id).toList();

                if (myShifts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'You have no shifts assigned',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          'Check the shift board for available shifts',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: myShifts.length,
                  itemBuilder: (context, index) {
                    final shift = myShifts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const Icon(Icons.schedule, color: Colors.teal),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Confirmed',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}