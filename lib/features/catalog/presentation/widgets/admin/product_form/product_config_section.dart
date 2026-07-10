import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductConfigSection extends StatelessWidget {
  const ProductConfigSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();
    final state = context.watch<ProductFormCubit>().state;
    final bool isService = state.productType == 'service';

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
            'Configuración',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: state.productType,
            decoration: InputDecoration(
              labelText: 'Tipo de Producto',
              prefixIcon: const Icon(Icons.category_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'good',
                child: Text('Bien Físico (Producto)'),
              ),
              DropdownMenuItem(value: 'service', child: Text('Servicio')),
              DropdownMenuItem(
                value: 'digital',
                child: Text('Producto Digital'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                cubit.setProductType(val);
              }
            },
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: Text(
                'Control de Stock',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isService ? Colors.grey : AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                isService
                    ? 'Los servicios no llevan control de inventario'
                    : 'Llevar el conteo de inventario para este producto',
                style: TextStyle(
                  fontSize: 12,
                  color: isService ? Colors.grey : AppColors.textSecondary,
                ),
              ),
              value: isService ? false : state.stockControl,
              onChanged: isService ? null : (val) => cubit.setStockControl(val),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
