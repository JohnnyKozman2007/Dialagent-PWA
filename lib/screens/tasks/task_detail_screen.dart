import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task_model.dart';
import '../../providers/user_provider.dart';

class TaskDetailScreen extends ConsumerWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final currentUser = userAsync.value;
    final isOwnerOrManager =
        currentUser?.role == 'Owner' || currentUser?.role == 'Manager';

    Future<void> deleteTask() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await Supabase.instance.client.from('tasks').delete().eq('id', task.id);
        if (context.mounted) Navigator.pop(context);
      }
    }

    // Format due date nicely
    String? dueDateLabel;
    if (task.dueDate != null) {
      final d = task.dueDate!;
      dueDateLabel =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        actions: [
          if (isOwnerOrManager)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit functionality coming soon')),
                );
              },
            ),
          if (isOwnerOrManager)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: deleteTask,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status chip
            Row(
              children: [
                Chip(
                  label: Text(
                    task.status.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: task.status == 'completed'
                      ? Colors.green
                      : task.status == 'in-progress'
                          ? Colors.orange
                          : Colors.blueGrey,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (task.description.isNotEmpty) ...[
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(task.description),
              const SizedBox(height: 16),
            ],
            const Text(
              'Assigned to',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(task.assignedToName ?? 'Unassigned'),
            if (dueDateLabel != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Due Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(dueDateLabel),
            ],
            // Staff: no claim/unclaim — tasks are assigned by Manager/Owner
            // Owner/Manager: edit/delete handled via AppBar actions above
          ],
        ),
      ),
    );
  }
}
