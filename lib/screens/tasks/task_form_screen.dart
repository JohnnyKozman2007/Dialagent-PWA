import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  List<Map<String, dynamic>> _staffList = [];
  String? _selectedAssigneeId;
  String? _selectedAssigneeName;
  bool _isLoadingStaff = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoadingStaff = true);
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return;

      // Fetch current user's restaurant_id
      final profile = await client
          .from('users')
          .select('restaurant_id')
          .eq('uid', currentUser.id)
          .single();
      final restaurantId = profile['restaurant_id'];

      // Fetch all staff members in the same restaurant (exclude Owner and Admin)
      final snapshot = await client
          .from('users')
          .select('uid, email, role')
          .eq('restaurant_id', restaurantId)
          .inFilter('role', ['Staff', 'Manager']);

      setState(() {
        _staffList = List<Map<String, dynamic>>.from(snapshot as List);
        _isLoadingStaff = false;
      });
    } catch (e) {
      setState(() => _isLoadingStaff = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('New Task')),
      body: _isLoadingStaff
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Task Title *',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Clean kitchen station',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descController,
                      decoration: InputDecoration(
                        hintText: 'Optional details about this task...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Assign To *',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    if (_staffList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.orange.shade50,
                        ),
                        child: const Text(
                          '⚠️ No staff members found. Invite staff before creating tasks.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedAssigneeId,
                        decoration: InputDecoration(
                          hintText: 'Select a staff member',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _staffList.map((member) {
                          final roleLabel = member['role'] == 'Manager' ? ' (Manager)' : '';
                          return DropdownMenuItem<String>(
                            value: member['uid'] as String,
                            child: Text('${member['email']}$roleLabel'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedAssigneeId = val;
                            final member = _staffList.firstWhere(
                                (m) => m['uid'] == val,
                                orElse: () => {});
                            _selectedAssigneeName = member['email'] as String?;
                          });
                        },
                        validator: (val) =>
                            val == null ? 'Please assign this task to someone' : null,
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _staffList.isEmpty
                                  ? null
                                  : () async {
                                      if (!_formKey.currentState!.validate()) return;
                                      setState(() => _isSaving = true);
                                      try {
                                        await Supabase.instance.client
                                            .from('tasks')
                                            .insert({
                                          'title': _titleController.text.trim(),
                                          'description': _descController.text.trim(),
                                          'restaurant_id': user.restaurantId,
                                          'assigned_to': _selectedAssigneeId,
                                          'assigned_to_name': _selectedAssigneeName ?? '',
                                          'status': 'pending',
                                        });
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('✅ Task created and assigned!'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) setState(() => _isSaving = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'CREATE & ASSIGN TASK',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
