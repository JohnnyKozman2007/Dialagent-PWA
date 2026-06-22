import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_restaurant_app/models/task_model.dart';
import 'package:my_restaurant_app/providers/task_provider.dart';
import 'package:my_restaurant_app/providers/user_provider.dart';
import 'package:my_restaurant_app/screens/tasks/task_form_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  final Task task;
  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final currentUser = userAsync.value;
    final isAssignedToMe = task.assignedTo == currentUser?.uid;
    final isOwnerOrManager = currentUser?.role == 'owner' || currentUser?.role == 'manager';

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        actions: [
          if (isOwnerOrManager)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskFormScreen(initialTask: task),
                  ),
                );
              },
            ),
          if (isOwnerOrManager)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
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
                  await ref.read(deleteTaskProvider(task.id).future);
                  if (context.mounted) Navigator.pop(context);
                }
              },
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
                  onPressed: () async {
                    await ref.read(claimTaskProvider(task.id).future);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isAssignedToMe ? 'Task unclaimed' : 'Task claimed')),
                      );
                    }
                  },
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
