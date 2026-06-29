import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  String selectedRole = 'Staff';
  bool isLoading = false;
  final List<String> roles = ['Staff', 'Manager'];

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Get the owner's document
      final ownerDoc = await Supabase.instance.client
          .from('profiles')
          .select('restaurant_id')
          .eq('id', user.id)
          .maybeSingle();

      String? restaurantId = ownerDoc?['restaurant_id'];

      // 🔥 FIX: If restaurantId is missing, use the owner's UID
      if (restaurantId == null || restaurantId.isEmpty) {
        restaurantId = user.id;
        // Save it back to the owner's document so future invites work
        await Supabase.instance.client
            .from('profiles')
            .update({'restaurant_id': restaurantId})
            .eq('id', user.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restaurant ID assigned. You can now invite staff.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      final email = emailController.text.trim().toLowerCase();

      // Check if user already exists in profiles
      final existingUser = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (existingUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This email is already registered.')),
        );
        setState(() => isLoading = false);
        return;
      }

      // Check if invite already exists
      final existingInvite = await Supabase.instance.client
          .from('invites')
          .select('id')
          .eq('email', email)
          .eq('used', false)
          .maybeSingle();

      if (existingInvite != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An invite already exists for this email.')),
        );
        setState(() => isLoading = false);
        return;
      }

      // Create invite with restaurantId
      await Supabase.instance.client.from('invites').insert({
        'email': email,
        'role': selectedRole,
        'restaurant_id': restaurantId,
        'used': false,
        'created_by': user.id,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Invite sent to $email as $selectedRole'),
          backgroundColor: Colors.green,
        ),
      );

      emailController.clear();
      setState(() => selectedRole = 'Staff');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Staff'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.mail_outline, size: 60, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Invite a new team member',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'They will receive an email to create their account.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              const Text('Email Address *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: 'john@example.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Email is required';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              const Text('Role *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRole,
                    isExpanded: true,
                    items: roles.map((role) {
                      return DropdownMenuItem(value: role, child: Text(role));
                    }).toList(),
                    onChanged: (value) => setState(() => selectedRole = value!),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Staff: Can view menu, take shifts, and tasks\n'
                '• Manager: Can manage shifts, tables, and orders',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _sendInvite,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'SEND INVITE',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
