import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

class ActiveIngredientsScreen extends StatefulWidget {
  const ActiveIngredientsScreen({super.key});

  @override
  State<ActiveIngredientsScreen> createState() =>
      _ActiveIngredientsScreenState();
}

class _ActiveIngredientsScreenState extends State<ActiveIngredientsScreen> {
  List<Map<String, dynamic>> _ingredients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchIngredients();
  }

  Future<void> _fetchIngredients() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('active_ingredients')
          .select()
          .order('name');
      setState(() {
        _ingredients = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al cargar: $e',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteIngredient(String id) async {
    try {
      await Supabase.instance.client
          .from('active_ingredients')
          .delete()
          .eq('id', id);
      _fetchIngredients();
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Ingrediente eliminado',
          backgroundColor: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se puede eliminar porque está en uso.',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _showIngredientForm({Map<String, dynamic>? ingredient}) {
    final nameCtrl = TextEditingController(text: ingredient?['name'] ?? '');
    final descCtrl = TextEditingController(
      text: ingredient?['description'] ?? '',
    );
    final isEditing = ingredient != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Editar Componente' : 'Nuevo Componente Químico',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre del componente *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    try {
                      final payload = {
                        'name': nameCtrl.text.trim(),
                        'description':
                            descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                      };
                      if (isEditing) {
                        await Supabase.instance.client
                            .from('active_ingredients')
                            .update(payload)
                            .eq('id', ingredient['id']);
                      } else {
                        await Supabase.instance.client
                            .from('active_ingredients')
                            .insert(payload);
                      }
                      if (mounted) {
                        Navigator.pop(context);
                        _fetchIngredients();
                      }
                    } catch (e) {
                      if (mounted) {
                        AppSnackbar.show(
                          context,
                          message: 'Error: $e',
                          backgroundColor: Colors.red,
                        );
                      }
                    }
                  },
                  child: Text(
                    isEditing ? 'Guardar Cambios' : 'Crear Componente',
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Componentes Químicos',
      showBackButton: true,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _ingredients.isEmpty
              ? const Center(child: Text('No hay componentes registrados'))
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _ingredients.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _ingredients[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: const Icon(
                          Icons.science_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        item['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          item['description'] != null
                              ? Text(
                                item['description'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                              : null,
                      trailing: PopupMenuButton(
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showIngredientForm(ingredient: item);
                          }
                          if (val == 'delete') _deleteIngredient(item['id']);
                        },
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showIngredientForm(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nuevo Componente',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
