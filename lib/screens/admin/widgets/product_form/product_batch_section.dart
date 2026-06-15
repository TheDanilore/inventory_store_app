import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/product_form_provider.dart';

class ProductBatchSection extends StatelessWidget {
  const ProductBatchSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductFormProvider>();

    if (provider.productType == 'service') {
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
                  provider.batchManagementEnabled
                      ? Colors.teal.withValues(alpha: 0.07)
                      : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  color:
                      provider.batchManagementEnabled
                          ? Colors.teal
                          : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.batchManagementEnabled
                            ? 'Gestión por lotes habilitada'
                            : 'Sin gestión por lotes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              provider.batchManagementEnabled
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
                  value: provider.batchManagementEnabled,
                  onChanged: provider.setBatchManagement,
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
