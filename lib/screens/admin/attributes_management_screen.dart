import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/attributes_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/attributes/attribute_form_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/attributes/attribute_value_dialog.dart';
import 'package:inventory_store_app/screens/admin/widgets/attributes/attributes_skeleton.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

class AttributesManagementScreen extends StatefulWidget {
  const AttributesManagementScreen({super.key});

  @override
  State<AttributesManagementScreen> createState() =>
      _AttributesManagementScreenState();
}

class _AttributesManagementScreenState
    extends State<AttributesManagementScreen> {
  void _showAttributeForm([Map<String, dynamic>? attribute]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AttributeFormSheet(attribute: attribute),
    );
  }

  void _showAddValueForm(String attributeId, String attributeName) {
    showDialog(
      context: context,
      builder:
          (context) => AttributeValueDialog(
            attributeId: attributeId,
            attributeName: attributeName,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Atributos de Variantes',
      showBackButton: true,
      body: Consumer<AttributesProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () => provider.fetchAttributes(),
            color: AppColors.primary,
            child:
                provider.isLoading
                    ? const AttributesSkeleton(itemCount: 4)
                    : provider.attributes.isEmpty
                    ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay propiedades registradas',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                    : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.attributes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final attr = provider.attributes[index];
                        final values =
                            (attr['attribute_values'] as List?) ?? [];

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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                      onPressed: () => _showAttributeForm(attr),
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
                                        deleteIcon:
                                            provider.isSaving
                                                ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                                : const Icon(
                                                  Icons.close,
                                                  size: 14,
                                                ),
                                        onDeleted:
                                            provider.isSaving
                                                ? null
                                                : () => provider
                                                    .deleteAttributeValue(
                                                      context,
                                                      v['id'],
                                                      v['value'],
                                                    ),
                                        backgroundColor: Colors.grey.shade100,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.1),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAttributeForm(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva Propiedad',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
