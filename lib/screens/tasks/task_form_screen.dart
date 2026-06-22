import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_restaurant_app/models/task_model.dart';
import 'package:my_restaurant_app/providers/task_provider.dart';
import 'package:my_restaurant_app/providers/user_provider.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final Task? initialTask;
  const TaskFormScreen({Key? key, this.initialTask}) : super(key: key);

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _dueDateController;
  DateTime? _selectedDueDate;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(text: task?.description ?? '');
    _selectedDueDate = task?.dueDate;
    _status = task?.status ?? 'pending';
    _dueDateController = TextEditingController(
      text: _selectedDueDate != null ? _formatDate(_selectedDueDate!) : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
        _dueDateController.text = _formatDate(picked);
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userAsync = ref.read(userProvider);
    final user = userAsync.value;
    if (user == null) return;

    final task = Task(
      id: widget.initialTask?.id ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      restaurantId: user.restaurantId!,
      assignedTo: widget.initialTask?.assignedTo,
      assignedToName: widget.initialTask?.assignedToName,
      status: _status,
      createdAt: widget.initialTask?.createdAt ?? DateTime.now(),
      dueDate: _selectedDueDate,
      syncedToCalendar: false,
      calendarEventId: null,
    );

    if (widget.initialTask == null) {
      await ref.read(createTaskProvider(task).future);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task created')));
    } else {
      await ref.read(updateTaskProvider(task).future);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task updated')));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTask == null ? 'Create Task' : 'Edit Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Enter a title' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? 'Enter a description' : null,
              ),
              TextFormField(
                controller: _dueDateController,
                decoration: const InputDecoration(labelText: 'Due Date (optional)'),
                readOnly: true,
                onTap: () => _selectDate(context),
              ),
              DropdownButtonFormField<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'in-progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                ],
                onChanged: (value) => setState(() => _status = value!),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: Text(widget.initialTask == null ? 'Create' : 'Update'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
