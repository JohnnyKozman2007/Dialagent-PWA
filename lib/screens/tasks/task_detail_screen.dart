import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task_model.dart';
import '../../providers/user_provider.dart';

class TaskDetailScreen extends ConsumerWidget {
  final Task task;
  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final currentUser = userAsync.value;
    final isAssignedToMe = task.assignedTo == currentUser?.uid;
    final isOwnerOrManager = currentUser?.role == 'Owner' || currentUser?.role == 'Manager';

    Future<void> deleteTask() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
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

    Future<void> toggleClaim() async {
      final newAssignedTo = isAssignedToMe ? null : currentUser?.uid;
      final newAssignedToName = isAssignedToMe ? '' : currentUser?.email ?? '';
      await Supabase.instance.client.from('tasks').update({
        'assigned_to': newAssignedTo,
        'assigned_to_name': newAssignedToName,
      }).eq('id', task.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAssignedToMe ? 'Unclaimed' : 'Claimed')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        actions: [
          if (isOwnerOrManager)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // For simplicity, we'll just show a message; you could pass task to form if needed.
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
            Text('Description: ${task.description}'),
            const SizedBox(height: 8),
            Text('Status: ${task.status}'),
            const SizedBox(height: 8),
            Text('Assigned to: ${task.assignedToName ?? 'Unassigned'}'),
            if (task.dueDate != null) Text('Due: ${task.dueDate}'),
            const Spacer(),
            if (!isOwnerOrManager && task.status != 'completed')
              Center(
                child: ElevatedButton.icon(
                  onPressed: toggleClaim,
                  icon: Icon(isAssignedToMe ? Icons.person_remove : Icons.person_add),
                  label: Text(isAssignedToMe ? 'Unclaim' : 'Claim'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
