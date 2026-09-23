import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

class ProductBasicInfoSection extends StatelessWidget {
  final TextEditingController nombreCtrl;
  final TextEditingController descCtrl;

  const ProductBasicInfoSection({
    super.key,
    required this.nombreCtrl,
    required this.descCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();

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
            controller: nombreCtrl,
            label: 'Nombre del producto',
            icon: Icons.inventory_2_outlined,
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 500;

              final categoryField = BlocBuilder<ProductFormCubit, ProductFormState>(
                buildWhen:
                    (p, c) =>
                        p.isLoadingCategories != c.isLoadingCategories ||
                        p.categories != c.categories ||
                        p.selectedCategoryId != c.selectedCategoryId,
                builder: (context, state) {
                  if (state.isLoadingCategories) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return DropdownButtonFormField<String>(
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
                  );
                },
              );

              final brandField = BlocBuilder<ProductFormCubit, ProductFormState>(
                buildWhen:
                    (p, c) =>
                        p.isLoadingBrands != c.isLoadingBrands ||
                        p.brands != c.brands ||
                        p.selectedBrandId != c.selectedBrandId,
                builder: (context, state) {
                  if (state.isLoadingBrands) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: state.selectedBrandId,
                    decoration: InputDecoration(
                      labelText: 'Marca / Fabricante',
                      prefixIcon: const Icon(Icons.verified_outlined),
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
                        child: Text('Sin marca'),
                      ),
                      ...state.brands.map(
                        (brand) => DropdownMenuItem(
                          value: brand.id!,
                          child: Text(brand.name),
                        ),
                      ),
                    ],
                    onChanged: cubit.setSelectedBrand,
                  );
                },
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: categoryField),
                    const SizedBox(width: 16),
                    Expanded(child: brandField),
                  ],
                );
              }

              return Column(
                children: [
                  categoryField,
                  const SizedBox(height: 16),
                  brandField,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: descCtrl,
            label: 'Descripción general',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
