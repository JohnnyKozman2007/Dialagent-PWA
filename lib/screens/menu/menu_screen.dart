import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _menuItems = [];
  String _searchQuery = '';
  String? _selectedCategoryId; // null means 'All'

  @override
  void initState() {
    super.initState();
    _loadMenuData();
  }

  Future<void> _loadMenuData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      // Get restaurant ID
      final profile = await client.from('users').select('restaurant_id').eq('uid', user.id).single();
      final restaurantId = profile['restaurant_id'];
      if (restaurantId == null) return;

      // Fetch categories
      final catData = await client
          .from('menu_categories')
          .select()
          .eq('restaurant_id', restaurantId)
          .order('name', ascending: true);

      // Fetch items
      final itemData = await client
          .from('menu_items')
          .select()
          .eq('restaurant_id', restaurantId)
          .order('name', ascending: true);

      setState(() {
        _categories = List<Map<String, dynamic>>.from(catData);
        _menuItems = List<Map<String, dynamic>>.from(itemData);
      });
    } catch (e) {
      debugPrint('Error loading menu data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Category Actions ---
  Future<void> _addCategory(String name) async {
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final profile = await client.from('users').select('restaurant_id').eq('uid', user.id).single();
      final restaurantId = profile['restaurant_id'];

      await client.from('menu_categories').insert({
        'name': name,
        'restaurant_id': restaurantId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category added!'), backgroundColor: Colors.green),
      );
      await _loadMenuData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCategory(String id) async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      await client.from('menu_categories').delete().eq('id', id);
      if (_selectedCategoryId == id) {
        _selectedCategoryId = null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted!')),
      );
      await _loadMenuData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Item Actions ---
  Future<void> _addOrUpdateItem({
    String? itemId,
    required String name,
    required String description,
    required double price,
    required String categoryId,
    String? imageUrl,
  }) async {
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final profile = await client.from('users').select('restaurant_id').eq('uid', user.id).single();
      final restaurantId = profile['restaurant_id'];

      final itemPayload = {
        'name': name,
        'description': description,
        'price': price,
        'category_id': categoryId,
        'image_url': imageUrl?.isEmpty == true ? null : imageUrl,
        'restaurant_id': restaurantId,
      };

      if (itemId == null) {
        await client.from('menu_items').insert(itemPayload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added!'), backgroundColor: Colors.green),
        );
      } else {
        await client.from('menu_items').update(itemPayload).eq('id', itemId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated!'), backgroundColor: Colors.green),
        );
      }

      await _loadMenuData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(String id) async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      await client.from('menu_items').delete().eq('id', id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted!')),
      );
      await _loadMenuData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(userRoleProvider);

    return roleAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (role) {
        final isManager = role == 'Owner' || role == 'Manager';

        // Filter items
        final filteredItems = _menuItems.where((item) {
          final matchesCategory = _selectedCategoryId == null || item['category_id'] == _selectedCategoryId;
          final matchesSearch = item['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item['description'].toLowerCase().contains(_searchQuery.toLowerCase());
          return matchesCategory && matchesSearch;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Restaurant Menu'),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/dashboard'),
            ),
            actions: [
              if (isManager) ...[
                IconButton(
                  icon: const Icon(Icons.category),
                  tooltip: 'Add Category',
                  onPressed: () => _showCategoryDialog(),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Menu Item',
                  onPressed: () => _showItemDialog(),
                ),
              ],
            ],
          ),
          body: _isLoading && _categories.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search menu items...',
                          prefixIcon: const Icon(Icons.search, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),

                    // Categories Tab Row
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('All Items'),
                            selected: _selectedCategoryId == null,
                            onSelected: (val) {
                              setState(() {
                                _selectedCategoryId = null;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ..._categories.map((cat) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onLongPress: isManager
                                    ? () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Category?'),
                                            content: Text('Are you sure you want to delete category "${cat['name']}"? This will delete all items inside it.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _deleteCategory(cat['id']);
                                                },
                                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    : null,
                                child: ChoiceChip(
                                  label: Text(cat['name']),
                                  selected: _selectedCategoryId == cat['id'],
                                  onSelected: (val) {
                                    setState(() {
                                      _selectedCategoryId = val ? cat['id'] : null;
                                    });
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                    const Divider(height: 20),

                    // Items list
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Text(
                                _searchQuery.isEmpty ? 'No items in this category' : 'No items found',
                                style: const TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                                final imgUrl = item['image_url'] as String?;

                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 3,
                                  child: Stack(
                                    children: [
                                      Row(
                                        children: [
                                          // Image or Placeholder
                                          Container(
                                            width: 100,
                                            height: double.infinity,
                                            color: Colors.teal.shade50,
                                            child: imgUrl != null && imgUrl.isNotEmpty
                                                ? Image.network(
                                                    imgUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        const Icon(Icons.fastfood, color: Colors.teal, size: 36),
                                                  )
                                                : const Icon(Icons.fastfood, color: Colors.teal, size: 36),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    item['name'] ?? '',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item['description'] ?? '',
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    '\$${price.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                        fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isManager)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: PopupMenuButton<String>(
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                              const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete', style: TextStyle(color: Colors.red))),
                                            ],
                                            onSelected: (action) {
                                              if (action == 'edit') {
                                                _showItemDialog(item: item);
                                              } else if (action == 'delete') {
                                                _deleteItem(item['id']);
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.more_vert, size: 18, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // --- Dialogs ---
  void _showCategoryDialog() {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Menu Category'),
        content: TextField(
          controller: catController,
          decoration: const InputDecoration(
            hintText: 'e.g. Appetizers, Desserts',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addCategory(catController.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showItemDialog({Map<String, dynamic>? item}) {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one Category first!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final nameController = TextEditingController(text: item?['name']);
    final descController = TextEditingController(text: item?['description']);
    final priceController = TextEditingController(text: item?['price']?.toString());
    final imgController = TextEditingController(text: item?['image_url']);
    String selectedCatId = item?['category_id'] ?? _categories.first['id'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Add Menu Item' : 'Edit Menu Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  value: selectedCatId,
                  items: _categories.map((cat) {
                    return DropdownMenuItem(value: cat['id'] as String, child: Text(cat['name']));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedCatId = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price (\$)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imgController,
                  decoration: const InputDecoration(
                    labelText: 'Optional Image URL',
                    hintText: 'https://example.com/dish.jpg',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final double? price = double.tryParse(priceController.text.trim());
                if (price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid price')),
                  );
                  return;
                }
                Navigator.pop(context);
                _addOrUpdateItem(
                  itemId: item?['id'],
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  price: price,
                  categoryId: selectedCatId,
                  imageUrl: imgController.text.trim(),
                );
              },
              child: Text(item == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
