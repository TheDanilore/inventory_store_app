import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/product_form_provider.dart';
import 'package:inventory_store_app/shared/widgets/app_text_field.dart';

class ProductBasicInfoSection extends StatelessWidget {
  const ProductBasicInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductFormProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información Básica',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: provider.nombreCtrl,
            label: 'Nombre del producto',
            icon: Icons.inventory_2_outlined,
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          provider.isLoadingCategories
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<String>(
                initialValue: provider.selectedCategoryId,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Sin categoría'),
                  ),
                  ...provider.categories.map(
                    (cat) =>
                        DropdownMenuItem(value: cat.id, child: Text(cat.name)),
                  ),
                ],
                onChanged: provider.setSelectedCategory,
              ),
          const SizedBox(height: 16),
          AppTextField(
            controller: provider.descCtrl,
            label: 'Descripción general',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
