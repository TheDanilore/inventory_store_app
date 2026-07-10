import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_cubit.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';

class ProductBasicInfoSection extends StatelessWidget {
  const ProductBasicInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();
    final state = context.watch<ProductFormCubit>().state;

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
            controller: cubit.nombreCtrl,
            label: 'Nombre del producto',
            icon: Icons.inventory_2_outlined,
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          state.isLoadingCategories
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<String>(
                initialValue: state.selectedCategoryId,
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
                  ...state.categories.map(
                    (cat) =>
                        DropdownMenuItem(value: cat.id!, child: Text(cat.name)),
                  ),
                ],
                onChanged: cubit.setSelectedCategory,
              ),
          const SizedBox(height: 16),
          AppTextField(
            controller: cubit.descCtrl,
            label: 'Descripción general',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
