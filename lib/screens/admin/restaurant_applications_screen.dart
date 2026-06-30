import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';

class RestaurantApplicationsScreen extends StatefulWidget {
  const RestaurantApplicationsScreen({super.key});

  @override
  State<RestaurantApplicationsScreen> createState() => _RestaurantApplicationsScreenState();
}

class _RestaurantApplicationsScreenState extends State<RestaurantApplicationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String uid, {required bool isApproved, required bool isRejected, String? reason}) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isApproved': isApproved,
        'isRejected': isRejected,
        'rejectionReason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApproved ? 'Application approved successfully!' : 'Application updated.'),
            backgroundColor: isApproved ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context, UserModel owner) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject the application for "${owner.restaurantName.isNotEmpty ? owner.restaurantName : owner.email}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g. Missing required details, invalid address',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateStatus(owner.uid, isApproved: false, isRejected: true, reason: reasonController.text.trim());
    }
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Applications'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Approved'),
            Tab(icon: Icon(Icons.cancel_outlined), text: 'Rejected'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Owner')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading applications: ${snapshot.error}'));
          }

          final allOwners = snapshot.data?.docs.map((doc) {
                return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
              }).toList() ??
              [];

          final pendingOwners = allOwners.where((o) => !o.isApproved && !o.isRejected).toList();
          final approvedOwners = allOwners.where((o) => o.isApproved).toList();
          final rejectedOwners = allOwners.where((o) => !o.isApproved && o.isRejected).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildApplicationList(pendingOwners, 'No pending applications', context, showApprove: true, showReject: true),
              _buildApplicationList(approvedOwners, 'No approved restaurants', context, showApprove: false, showReject: true),
              _buildApplicationList(rejectedOwners, 'No rejected applications', context, showApprove: true, showReject: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildApplicationList(
    List<UserModel> list,
    String emptyMessage,
    BuildContext context, {
    required bool showApprove,
    required bool showReject,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final owner = list[index];
        final createdDate = owner.createdAt;
        final dateStr = '${createdDate.year}-${createdDate.month.toString().padLeft(2, '0')}-${createdDate.day.toString().padLeft(2, '0')}';

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Restaurant Name & Email)
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text(
                        owner.restaurantName.isNotEmpty ? owner.restaurantName[0].toUpperCase() : 'R',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            owner.restaurantName.isNotEmpty ? owner.restaurantName : 'New Restaurant Application',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            owner.email,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: owner.isApproved
                            ? Colors.green.shade50
                            : (owner.isRejected ? Colors.red.shade50 : Colors.orange.shade50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: owner.isApproved
                              ? Colors.green
                              : (owner.isRejected ? Colors.red : Colors.orange),
                        ),
                      ),
                      child: Text(
                        owner.isApproved ? 'Approved' : (owner.isRejected ? 'Rejected' : 'Pending'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: owner.isApproved
                              ? Colors.green.shade800
                              : (owner.isRejected ? Colors.red.shade800 : Colors.orange.shade800),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Details (Address, Cuisine, Tables, Phone, Created Date)
                _buildDetailRow(Icons.calendar_today, 'Applied Date', dateStr),
                if (owner.phone != null && owner.phone!.isNotEmpty)
                  _buildDetailRow(Icons.phone, 'Phone', owner.phone!),
                if (owner.address != null && owner.address!.isNotEmpty)
                  _buildDetailRow(Icons.location_on, 'Address', owner.address!),
                if (owner.cuisineType != null && owner.cuisineType!.isNotEmpty)
                  _buildDetailRow(Icons.restaurant, 'Cuisine Type', owner.cuisineType!),
                if (owner.tableCount != null)
                  _buildDetailRow(Icons.table_restaurant, 'Table Count', '${owner.tableCount} tables'),

                // Rejection Reason (if rejected and exists)
                if (owner.isRejected && owner.rejectionReason != null && owner.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.15)),
                    ),
                    child: Text(
                      'Rejection Reason: ${owner.rejectionReason}',
                      style: const TextStyle(fontSize: 13, color: Colors.red, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],

                // Action Buttons
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showReject)
                      TextButton.icon(
                        onPressed: () => _showRejectDialog(context, owner),
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        label: const Text('Reject', style: TextStyle(color: Colors.red)),
                      ),
                    if (showReject && showApprove) const SizedBox(width: 8),
                    if (showApprove)
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus(owner.uid, isApproved: true, isRejected: false, reason: null),
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: const Text('Approve', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          elevation: 1,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
