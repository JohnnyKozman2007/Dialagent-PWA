import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_provider.dart';
import 'task_form_screen.dart';
import 'task_detail_screen.dart';

class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  String _filterStatus = 'all';
  String _filterAssignee = 'all';

  Future<void> _markTaskDone(Task task) async {
    await Supabase.instance.client
        .from('tasks')
        .update({
      'status': 'completed',
    })
        .eq('id', task.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Task marked as done!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final userAsync = ref.watch(userProvider);
    final currentUser = userAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _filterStatus = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'in-progress', child: Text('In Progress')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () {
              setState(() {
                _filterAssignee = _filterAssignee == 'all' ? 'mine' : 'all';
              });
            },
            tooltip: _filterAssignee == 'all' ? 'Show only mine' : 'Show all',
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (tasks) {
          List<Task> filtered = tasks.where((task) {
            if (_filterStatus != 'all' && task.status != _filterStatus) return false;
            if (_filterAssignee == 'mine' && task.assignedTo != currentUser?.uid) return false;
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No tasks found'));
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final task = filtered[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text('Status: ${task.status}  |  ${task.assignedToName ?? 'Unassigned'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.status != 'completed' && task.assignedTo == currentUser?.uid)
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                          onPressed: () => _markTaskDone(task),
                          tooltip: 'Mark as Done',
                        ),
                      if (task.status == 'completed')
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskDetailScreen(task: task),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: (currentUser?.role == 'Owner' || currentUser?.role == 'Manager')
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TaskFormScreen()),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }


}
