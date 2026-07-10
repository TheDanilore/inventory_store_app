import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_cubit.dart';

class ProductBatchSection extends StatelessWidget {
  const ProductBatchSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();
    final state = context.watch<ProductFormCubit>().state;

    if (state.productType == 'service') {
      return const SizedBox.shrink();
    }

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
            'Gestión por Lotes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  state.batchManagementEnabled
                      ? Colors.teal.withValues(alpha: 0.07)
                      : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  color:
                      state.batchManagementEnabled ? Colors.teal : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.batchManagementEnabled
                            ? 'Gestión por lotes habilitada'
                            : 'Sin gestión por lotes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              state.batchManagementEnabled
                                  ? Colors.teal.shade700
                                  : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Requerirá número de lote y vencimiento al ingresar stock en el Módulo de Inventario.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: state.batchManagementEnabled,
                  onChanged: cubit.setBatchManagement,
                  activeThumbColor: Colors.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
