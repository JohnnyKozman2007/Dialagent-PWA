import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_provider.dart';
import 'task_form_screen.dart';
import 'task_detail_screen.dart';

class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({super.key});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  String _filterStatus = 'all';
  // Assignee filter only applies to Owner/Manager — Staff always see only their tasks
  String _filterAssignee = 'all';

  Future<void> _markTaskDone(Task task) async {
    await Supabase.instance.client
        .from('tasks')
        .update({
      'status': 'completed',
    }).eq('id', task.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Task marked as done!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final userAsync = ref.watch(userProvider);
    final currentUser = userAsync.value;
    final role = currentUser?.role ?? 'Staff';
    final isManagerOrOwner = role == 'Owner' || role == 'Manager';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          // Status filter — visible to everyone
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _filterStatus = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'in-progress', child: Text('In Progress')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
            ],
          ),
          // Assignee filter — only meaningful for Owner/Manager
          if (isManagerOrOwner)
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
        error: (error, stack) {
          if (error.toString().contains('failed-precondition')) {
            return _buildIndexError(context, error);
          }
          return Center(child: Text('Error: $error'));
        },
        data: (tasks) {
          List<Task> filtered = tasks.where((task) {
            if (_filterStatus != 'all' && task.status != _filterStatus) return false;
            // Assignee filter only applies to Manager/Owner — Staff always see only their tasks
            if (isManagerOrOwner &&
                _filterAssignee == 'mine' &&
                task.assignedTo != currentUser?.uid) {
              return false;
            }
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.task_alt, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    isManagerOrOwner
                        ? 'No tasks found. Tap + to create one.'
                        : 'No tasks assigned to you yet.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
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
      floatingActionButton: isManagerOrOwner
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

  Widget _buildIndexError(BuildContext context, Object error) {
    final errorString = error.toString();
    final linkStart = errorString.indexOf('https://');
    final linkEnd = errorString.indexOf(' ', linkStart);
    String link = linkStart != -1
        ? errorString.substring(linkStart, linkEnd != -1 ? linkEnd : errorString.length)
        : '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Database Connection Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please create the missing composite index for tasks.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (link.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Index creation link copied to clipboard')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Index Link'),
              ),
            const SizedBox(height: 16),
            Text(
              'If you have the link, open it in your browser and create the index.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
