import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

class CategoriesManagementScreen extends StatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  State<CategoriesManagementScreen> createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends State<CategoriesManagementScreen> {
  static const int _pageSize = 8;
  final _supabase = Supabase.instance.client;
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .order('name', ascending: true);
      setState(() {
        _categories =
            (response as List).map((e) => CategoryModel.fromJson(e)).toList();
        _currentPage = 0;
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Error cargando categorías: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showCategoryDialog([CategoryModel? category]) async {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(
      text: category?.description ?? '',
    );
    bool isActive = category?.isActive ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Categoría' : 'Nueva Categoría'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Activo'),
                      value: isActive,
                      onChanged: (val) {
                        setStateDialog(() => isActive = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    final data = {
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                      'is_active': isActive,
                    };

                    try {
                      if (isEditing) {
                        await _supabase
                            .from('categories')
                            .update(data)
                            .eq('id', category.id!);
                      } else {
                        await _supabase.from('categories').insert(data);
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _fetchCategories();
                    } catch (e) {
                      if (!context.mounted) return;
                      AppSnackbar.show(context, message: 'Error guardando: $e');
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _categories.length;
    final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
    final currentPage =
        _currentPage >= totalPages ? totalPages - 1 : _currentPage;
    final start = currentPage * _pageSize;
    final end =
        total == 0
            ? 0
            : ((start + _pageSize) > total ? total : (start + _pageSize));
    final pageItems =
        total == 0 ? <CategoryModel>[] : _categories.sublist(start, end);

    return AdminLayout(
      title: 'Gestión de Categorías',
      showBackButton: true,
      showProfileButton: false,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          'Mostrando ${total == 0 ? 0 : start + 1}-$end de $total',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Página ${total == 0 ? 0 : currentPage + 1} / $totalPages',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: pageItems.length,
                      itemBuilder: (context, index) {
                        final cat = pageItems[index];
                        return ListTile(
                          title: Text(cat.name),
                          subtitle: Text(cat.description ?? 'Sin descripción'),
                          trailing: Switch(
                            value: cat.isActive,
                            onChanged: null,
                          ),
                          onTap: () => _showCategoryDialog(cat),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    child: AdminPageBlocks(
                      currentPage: currentPage,
                      totalPages: totalPages,
                      onPageChanged:
                          (page) => setState(() => _currentPage = page),
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
