import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/task_model.dart';
import '../../providers/user_provider.dart';

class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({super.key});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final roleAsync = ref.watch(userRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          roleAsync.when(
            data: (role) {
              if (role == 'Owner' || role == 'Manager') {
                return IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showAddTaskDialog,
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: roleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (String role) {
          final isManager = role == 'Owner' || role == 'Manager';
          return StreamBuilder<QuerySnapshot>(
            stream: _getTasksStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // 🔥 HANDLE INDEX ERROR GRACEFULLY
                final error = snapshot.error.toString();
                if (error.contains('index')) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.build, size: 64, color: Colors.orange),
                          const SizedBox(height: 16),
                          const Text(
                            'Firestore Index Required',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'The database needs an index to sort tasks.\nPlease click the link below to create it.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          if (error.contains('https://')) {
                            InkWell(
                              onTap: () {
                                // Extract the URL from the error
                                final start = error.indexOf('https://');
                                final end = error.indexOf(' ', start);
                                final url = end > start
                                    ? error.substring(start, end)
                                    : error.substring(start);
                                // Open the link
                                _openLink(url);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.link,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Create Index',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          },
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              setState(() {});
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final tasks = snapshot.data?.docs
                  .map((doc) => TaskModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList() ?? [];

              if (tasks.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No tasks yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      Text(
                        'Tap the + button to create one',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final isAssignedToMe = task.assignedTo == user?.uid;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.description),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildStatusChip(task.status),
                              const SizedBox(width: 8),
                              if (task.assignedTo != null)
                                Text(
                                  '👤 ${task.assignedToName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: isManager
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEditTaskDialog(task),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteTask(task.id),
                                ),
                              ],
                            )
                          : (task.assignedTo == null || isAssignedToMe
                              ? ElevatedButton(
                                  onPressed: () => _toggleTaskAssignment(task),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAssignedToMe
                                        ? Colors.orange
                                        : Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(isAssignedToMe ? 'Unclaim' : 'Claim'),
                                )
                              : const SizedBox.shrink()),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getTasksStream() async* {
    final user = FirebaseAuth.instance.currentUser;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final restaurantId = doc.data()?['restaurantId'];

    if (restaurantId == null || restaurantId.isEmpty) {
      yield* FirebaseFirestore.instance
          .collection('tasks')
          .where('restaurantId', isEqualTo: '')
          .snapshots();
      return;
    }

    // 🔥 FIXED: Use orderBy with the correct field
    yield* FirebaseFirestore.instance
        .collection('tasks')
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 🔥 Helper to open the index creation link
  void _openLink(String url) {
    // In Flutter Web, this works with the url_launcher package
    // For now, just copy to clipboard or show the URL
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copy this link and open it in your browser: $url'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'in-progress':
        color = Colors.orange;
        label = 'In Progress';
        break;
      case 'done':
        color = Colors.green;
        label = 'Done';
        break;
      default:
        color = Colors.grey;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _toggleTaskAssignment(TaskModel task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isAssignedToMe = task.assignedTo == user.uid;
    final updates = isAssignedToMe
        ? {'assignedTo': null, 'assignedToName': ''}
        : {'assignedTo': user.uid, 'assignedToName': user.email ?? 'User'};

    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(task.id)
        .update(updates);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAssignedToMe ? 'Task unclaimed' : 'Task claimed!'),
        backgroundColor: isAssignedToMe ? Colors.orange : Colors.green,
      ),
    );
  }

  void _showAddTaskDialog() {
    _titleController.clear();
    _descController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .get();
              final restaurantId = doc.data()?['restaurantId'] ?? '';

              await FirebaseFirestore.instance.collection('tasks').add({
                'title': _titleController.text.trim(),
                'description': _descController.text.trim(),
                'restaurantId': restaurantId,
                'assignedTo': null,
                'assignedToName': '',
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Task created!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditTaskDialog(TaskModel task) {
    _titleController.text = task.title;
    _descController.text = task.description;
    String newStatus = task.status;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: newStatus,
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'in-progress', child: Text('In Progress')),
                DropdownMenuItem(value: 'done', child: Text('Done')),
              ],
              onChanged: (value) => newStatus = value!,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('tasks')
                  .doc(task.id)
                  .update({
                'title': _titleController.text.trim(),
                'description': _descController.text.trim(),
                'status': newStatus,
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Task updated!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(String taskId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
