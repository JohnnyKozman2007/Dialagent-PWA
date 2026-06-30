import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart'; // ✅ import added

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key}); // ✅ no initialTask parameter

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('New Task')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await Supabase.instance.client.from('tasks').insert({
                      'title': _titleController.text,
                      'description': _descController.text,
                      'restaurant_id': user.restaurantId,
                      'assigned_to': null,
                      'assigned_to_name': '',
                      'status': 'pending',
                      'created_at': DateTime.now().toIso8601String(),
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
