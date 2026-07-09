import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_state.dart';

class ProductDetailsSection extends StatelessWidget {
  const ProductDetailsSection({super.key});

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
            'Detalles y Especificaciones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Agrega detalles como Marca, Material, Medidas, etc.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              TextButton.icon(
                onPressed: cubit.addDetailRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir detalle'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.detailRows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Sin detalles adicionales',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.detailRows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final row = state.detailRows[idx];
                return Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: row.keyCtrl,
                        decoration: InputDecoration(
                          hintText: 'Propiedad (ej: Material)',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ':',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: row.valueCtrl,
                        decoration: InputDecoration(
                          hintText: 'Valor (ej: Acero)',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      onPressed: () => cubit.removeDetailRow(idx),
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
