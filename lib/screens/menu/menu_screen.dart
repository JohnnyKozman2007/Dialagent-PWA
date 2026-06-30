import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../providers/user_provider.dart';
import '../../providers/menu_provider.dart';
import '../../models/user_model.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedCategoryId; // null means 'All'
  
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _menuItems = [];
  UserModel? _currentUser;
  bool _canEdit = false;

  // --- Category Actions ---
  Future<void> _addCategory() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Menu Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Starters, Mains, Drinks',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                await Supabase.instance.client.from('menu_categories').insert({
                  'name': name,
                  'restaurant_name': _currentUser!.restaurantName,
                });
                ref.invalidate(menuCategoriesProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Category "$name" created!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Error Creating Category'),
                      content: SelectableText('$e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final controller = TextEditingController(text: category['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                await Supabase.instance.client
                    .from('menu_categories')
                    .update({'name': name})
                    .eq('id', category['id']);
                ref.invalidate(menuCategoriesProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category updated!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating category: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category['name']}"?'),
        content: const Text(
          'Are you sure you want to delete this category?\n\n'
          'Note: Any items currently in this category will no longer have a category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client
            .from('menu_categories')
            .delete()
            .eq('id', category['id']);
        ref.invalidate(menuCategoriesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting category: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // --- Menu Item Actions ---
  Future<void> _showItemForm([Map<String, dynamic>? item]) async {
    final isEdit = item != null;
    final nameController = TextEditingController(text: item?['name']);
    final descController = TextEditingController(text: item?['description']);
    final priceController = TextEditingController(text: item?['price']?.toString());
    String? selectedCat = item?['category_id']?.toString() ?? 
        (_categories.isNotEmpty ? _categories[0]['id'].toString() : null);

    XFile? selectedImage;
    String? existingImageUrl = item?['image_url'];
    bool isPickingImage = false;

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Dish Details' : 'Add New Dish',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Dish Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.restaurant),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                            hintText: '0.00',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            final p = double.tryParse(value);
                            if (p == null || p < 0) {
                              return 'Invalid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: selectedCat,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.folder),
                          ),
                          items: _categories
                              .map((c) => DropdownMenuItem(
                                    value: c['id'].toString(),
                                    child: Text(
                                      c['name'],
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setModalState(() {
                              selectedCat = val;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Select a category' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                      hintText: 'Ingredients, allergens, or description...',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Image picker section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: FutureBuilder<Uint8List>(
                                  future: selectedImage!.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    return const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : existingImageUrl != null && existingImageUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      existingImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, _, __) => const Icon(
                                        Icons.restaurant,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.image_outlined, color: Colors.grey, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: isPickingImage
                                  ? null
                                  : () async {
                                      setModalState(() => isPickingImage = true);
                                      try {
                                        final picker = ImagePicker();
                                        final XFile? image = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          maxWidth: 800,
                                          maxHeight: 800,
                                          imageQuality: 85,
                                        );
                                        if (image != null) {
                                          setModalState(() {
                                            selectedImage = image;
                                          });
                                        }
                                      } catch (e) {
                                        debugPrint('Error picking image: $e');
                                      } finally {
                                        setModalState(() => isPickingImage = false);
                                      }
                                    },
                              icon: isPickingImage
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.photo_library),
                              label: const Text('Select Image'),
                            ),
                            if (selectedImage != null || existingImageUrl != null)
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    selectedImage = null;
                                    existingImageUrl = null;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Remove Image'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final name = nameController.text.trim();
                      final price = double.parse(priceController.text.trim());
                      final desc = descController.text.trim();

                      Navigator.pop(context);
                      setState(() => _isLoading = true);

                      try {
                        String? imageUrl = existingImageUrl;

                        // Upload selected local image if available
                        if (selectedImage != null) {
                          // Try to create the bucket just in case
                          try {
                            await Supabase.instance.client.storage.createBucket(
                              'menu-images',
                              const BucketOptions(public: true),
                            );
                          } catch (_) {
                            // Bucket already exists or unauthorized, safe to ignore
                          }

                          final bytes = await selectedImage!.readAsBytes();
                          final fileExt = selectedImage!.name.split('.').last;
                          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

                          await Supabase.instance.client.storage
                              .from('menu-images')
                              .uploadBinary(
                                fileName,
                                bytes,
                                fileOptions: FileOptions(
                                  contentType: 'image/$fileExt',
                                ),
                              )
                              .timeout(const Duration(seconds: 15));

                          imageUrl = Supabase.instance.client.storage
                              .from('menu-images')
                              .getPublicUrl(fileName);
                        }

                        final payload = {
                          'name': name,
                          'price': price,
                          'description': desc.isNotEmpty ? desc : null,
                          'image_url': imageUrl,
                          'category_id': selectedCat,
                          'restaurant_name': _currentUser!.restaurantName,
                        };

                        if (isEdit) {
                          await Supabase.instance.client
                              .from('menu_items')
                              .update(payload)
                              .eq('id', item['id']);
                        } else {
                          await Supabase.instance.client
                              .from('menu_items')
                              .insert(payload);
                        }

                        ref.invalidate(menuCategoriesProvider);
                        ref.invalidate(menuItemsProvider);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit ? 'Dish updated successfully!' : 'Dish added to menu!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Error Saving Dish'),
                              content: SelectableText('$e'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isEdit ? 'Save Changes' : 'Add to Menu',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${item['name']}"?'),
        content: const Text('Are you sure you want to remove this item from your menu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client
            .from('menu_items')
            .delete()
            .eq('id', item['id']);
        ref.invalidate(menuItemsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dish removed from menu.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting dish: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // --- Rendering UI ---
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        _currentUser = user;
        _canEdit = user.permissions.canManageMenu || user.role == 'Owner' || user.role == 'Manager';

        return categoriesAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text('Error loading categories: $err'))),
          data: (categoriesList) {
            _categories = categoriesList;

            return itemsAsync.when(
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (err, stack) => Scaffold(body: Center(child: Text('Error loading items: $err'))),
              data: (itemsList) {
                _menuItems = itemsList;

                // Filter items based on selected category & search query
                final filteredItems = _menuItems.where((item) {
                  final matchesCategory = _selectedCategoryId == null ||
                      item['category_id']?.toString() == _selectedCategoryId;
                  
                  final matchesSearch = _searchQuery.isEmpty ||
                      item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (item['description'] != null &&
                          item['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase()));

                  return matchesCategory && matchesSearch;
                }).toList();

                return DefaultTabController(
                  length: _categories.length + 1,
                  child: Stack(
                    children: [
                      Scaffold(
                        appBar: AppBar(
                          title: Text(_currentUser != null && _currentUser!.restaurantName.isNotEmpty
                              ? '${_currentUser!.restaurantName} Menu'
                              : 'Restaurant Menu'),
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => context.go('/dashboard'),
                          ),
                          actions: [
                            if (_canEdit) ...[
                              IconButton(
                                icon: const Icon(Icons.create_new_folder),
                                tooltip: 'New Category',
                                onPressed: _addCategory,
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: 'Add Dish',
                                onPressed: () {
                                  if (_categories.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please create a category first before adding dishes!'),
                                      ),
                                    );
                                  } else {
                                    _showItemForm();
                                  }
                                },
                              ),
                            ]
                          ],
                        ),
                        body: Column(
                          children: [
                            // Modern Glassmorphic Search Container
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: TextField(
                                    onChanged: (val) => setState(() => _searchQuery = val),
                                    decoration: const InputDecoration(
                                      hintText: 'Search dishes, ingredients...',
                                      prefixIcon: Icon(Icons.search),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Horizontal Category Selection
                            if (_categories.isNotEmpty) ...[
                              TabBar(
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                indicatorColor: Theme.of(context).primaryColor,
                                labelColor: Theme.of(context).primaryColor,
                                unselectedLabelColor: Colors.grey,
                                onTap: (index) {
                                  setState(() {
                                    if (index == 0) {
                                      _selectedCategoryId = null;
                                    } else {
                                      _selectedCategoryId = _categories[index - 1]['id'].toString();
                                    }
                                  });
                                },
                                tabs: [
                                  const Tab(text: 'All Items'),
                                  ..._categories.map((c) => Tab(
                                        child: Row(
                                          children: [
                                            Text(c['name']),
                                            if (_canEdit) ...[
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: () => _editCategory(c),
                                                child: const Icon(Icons.edit, size: 14),
                                              ),
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: () => _deleteCategory(c),
                                                child: const Icon(Icons.delete, size: 14, color: Colors.red),
                                              ),
                                            ]
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ],

                            // Grid of dishes
                            Expanded(
                              child: filteredItems.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.no_meals, size: 64, color: Colors.grey),
                                          const SizedBox(height: 16),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? 'No matches found'
                                                : 'No dishes added to this section',
                                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    )
                                  : GridView.builder(
                                      padding: const EdgeInsets.all(16.0),
                                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 300,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 0.85,
                                      ),
                                      itemCount: filteredItems.length,
                                      itemBuilder: (context, index) {
                                        final item = filteredItems[index];
                                        final imageUrl = item['image_url'] as String?;
                                        final price = item['price'] as num;

                                        return Card(
                                          clipBehavior: Clip.antiAlias,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              // Image fallback or loader
                                              Expanded(
                                                child: Container(
                                                  color: Colors.grey[200],
                                                  child: imageUrl != null && imageUrl.isNotEmpty
                                                      ? Image.network(
                                                          imageUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, _, __) => const Icon(
                                                            Icons.restaurant,
                                                            size: 48,
                                                            color: Colors.grey,
                                                          ),
                                                        )
                                                      : const Icon(
                                                          Icons.restaurant,
                                                          size: 48,
                                                          color: Colors.grey,
                                                        ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(12.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item['name'],
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        Text(
                                                          '\$${price.toStringAsFixed(2)}',
                                                          style: TextStyle(
                                                            color: Theme.of(context).primaryColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      item['description'] ?? 'No description provided.',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (_canEdit) ...[
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.end,
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.edit, size: 18),
                                                            onPressed: () => _showItemForm(item),
                                                            constraints: const BoxConstraints(),
                                                            padding: EdgeInsets.zero,
                                                          ),
                                                          const SizedBox(width: 16),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                                            onPressed: () => _deleteItem(item),
                                                            constraints: const BoxConstraints(),
                                                            padding: EdgeInsets.zero,
                                                          ),
                                                        ],
                                                      )
                                                    ],
                                                  ],
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
                      ),
                      if (_isLoading)
                        const Opacity(
                          opacity: 0.5,
                          child: ModalBarrier(dismissible: false, color: Colors.black54),
                        ),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
