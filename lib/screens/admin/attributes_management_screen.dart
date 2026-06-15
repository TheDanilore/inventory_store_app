import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

class AttributesManagementScreen extends StatefulWidget {
  const AttributesManagementScreen({super.key});

  @override
  State<AttributesManagementScreen> createState() =>
      _AttributesManagementScreenState();
}

class _AttributesManagementScreenState
    extends State<AttributesManagementScreen> {
  List<Map<String, dynamic>> _attributes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttributes();
  }

  Future<void> _fetchAttributes() async {
    setState(() => _isLoading = true);
    try {
      // Usamos el join de Supabase para traer los valores anidados en la misma consulta
      final res = await Supabase.instance.client
          .from('attributes')
          .select('*, attribute_values(*)')
          .order('name');

      setState(() {
        _attributes = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAttributeValue(String valueId) async {
    try {
      await Supabase.instance.client
          .from('attribute_values')
          .delete()
          .eq('id', valueId);
      _fetchAttributes();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Este valor está siendo usado por productos.',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _showAttributeForm({Map<String, dynamic>? attribute}) {
    final nameCtrl = TextEditingController(text: attribute?['name'] ?? '');
    final descCtrl = TextEditingController(
      text: attribute?['description'] ?? '',
    );

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
              const Text(
                'Propiedad (Ej: Color, Talla)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre de la propiedad *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
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
                        'description': descCtrl.text.trim(),
                      };
                      if (attribute != null) {
                        await Supabase.instance.client
                            .from('attributes')
                            .update(payload)
                            .eq('id', attribute['id']);
                      } else {
                        await Supabase.instance.client
                            .from('attributes')
                            .insert(payload);
                      }
                      if (mounted) {
                        Navigator.pop(context);
                        _fetchAttributes();
                      }
                    } catch (e) {
                      if (mounted) {
                        AppSnackbar.show(
                          context,
                          message: 'El nombre ya existe',
                          backgroundColor: Colors.red,
                        );
                      }
                    }
                  },
                  child: Text(
                    attribute != null ? 'Actualizar' : 'Crear Propiedad',
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

  void _showAddValueForm(String attributeId, String attributeName) {
    final valueCtrl = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Añadir valor a $attributeName'),
            content: TextField(
              controller: valueCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ej: Rojo, XL, Madera...',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (valueCtrl.text.trim().isEmpty) return;
                  try {
                    await Supabase.instance.client
                        .from('attribute_values')
                        .insert({
                          'attribute_id': attributeId,
                          'value': valueCtrl.text.trim(),
                        });
                    if (mounted) {
                      Navigator.pop(context);
                      _fetchAttributes();
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackbar.show(
                        context,
                        message: 'El valor ya existe para esta propiedad',
                        backgroundColor: Colors.red,
                      );
                    }
                  }
                },
                child: const Text('Añadir'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Atributos de Variantes',
      showBackButton: true,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _attributes.isEmpty
              ? const Center(child: Text('No hay propiedades registradas'))
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _attributes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final attr = _attributes[index];
                  final values = (attr['attribute_values'] as List?) ?? [];

                  return Card(
                    elevation: 2,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.category_outlined,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    attr['name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed:
                                    () => _showAttributeForm(attribute: attr),
                              ),
                            ],
                          ),
                          if (attr['description'] != null &&
                              attr['description'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 12,
                                top: 4,
                              ),
                              child: Text(
                                attr['description'],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const Divider(),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...values.map(
                                (v) => InputChip(
                                  label: Text(
                                    v['value'],
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted:
                                      () => _deleteAttributeValue(v['id']),
                                  backgroundColor: Colors.grey.shade100,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              ActionChip(
                                label: const Text('Añadir valor'),
                                avatar: const Icon(
                                  Icons.add,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.1,
                                ),
                                labelStyle: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                onPressed:
                                    () => _showAddValueForm(
                                      attr['id'],
                                      attr['name'],
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAttributeForm(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva Propiedad',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
