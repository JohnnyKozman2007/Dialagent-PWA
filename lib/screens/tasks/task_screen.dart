import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_restaurant_app/models/task_model.dart';
import 'package:my_restaurant_app/providers/task_provider.dart';
import 'package:my_restaurant_app/screens/tasks/task_form_screen.dart';
import 'package:my_restaurant_app/screens/tasks/task_detail_screen.dart';
import 'package:my_restaurant_app/providers/user_provider.dart';

class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  String _filterStatus = 'all'; // 'all', 'pending', 'in-progress', 'completed'
  String _filterAssignee = 'all'; // 'all', 'mine'

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(taskListProvider);
    final currentUser = ref.watch(userProvider);

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
        error: (error, stack) {
          // Check if it's a Firestore index error (code 9)
          if (error.toString().contains('failed-precondition')) {
            return _buildIndexError(context, error);
          }
          return Center(child: Text('Error: $error'));
        },
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
                  trailing: task.status == 'completed'
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildIndexError(BuildContext context, Object error) {
    // Extract the index creation link from error message
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
              'Firestore Index Required',
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Index creation link copied to clipboard')),
                  );
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
