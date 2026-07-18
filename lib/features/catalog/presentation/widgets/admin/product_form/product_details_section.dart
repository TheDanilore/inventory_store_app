import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';

/// Sección de Detalles y Especificaciones.
///
/// Gestiona un [Map] local de [TextEditingController] indexados por [DetailModel.id].
/// Esto permite que los controllers sobrevivan los rebuilds del estado del Cubit
/// sin necesidad de que el Cubit los conozca.
class ProductDetailsSection extends StatefulWidget {
  const ProductDetailsSection({super.key});

  @override
  State<ProductDetailsSection> createState() => _ProductDetailsSectionState();
}

class _ProductDetailsSectionState extends State<ProductDetailsSection> {
  final Map<String, TextEditingController> _keyControllers = {};
  final Map<String, TextEditingController> _valueControllers = {};

  @override
  void dispose() {
    for (final ctrl in _keyControllers.values) {
      ctrl.dispose();
    }
    for (final ctrl in _valueControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Sincroniza los controllers con el estado del Cubit:
  /// - Crea controllers para nuevas filas.
  /// - Elimina controllers de filas removidas.
  void _syncControllers(List<DetailModel> rows) {
    final ids = rows.map((r) => r.id).toSet();

    // Eliminar controllers huérfanos
    _keyControllers.keys.toList().forEach((id) {
      if (!ids.contains(id)) {
        _keyControllers.remove(id)?.dispose();
        _valueControllers.remove(id)?.dispose();
      }
    });

    // Crear controllers faltantes
    for (final row in rows) {
      if (!_keyControllers.containsKey(row.id)) {
        _keyControllers[row.id] = TextEditingController(text: row.key);
        _valueControllers[row.id] = TextEditingController(text: row.value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();

    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen: (p, c) => p.detailRows != c.detailRows,
      builder: (context, state) {
        _syncControllers(state.detailRows);

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
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
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
                    final keyCtrl = _keyControllers[row.id]!;
                    final valueCtrl = _valueControllers[row.id]!;

                    return Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: keyCtrl,
                            onChanged: (_) => cubit.markAsDirty(),
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
                            controller: valueCtrl,
                            onChanged: (_) => cubit.markAsDirty(),
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
      },
    );
  }
}
