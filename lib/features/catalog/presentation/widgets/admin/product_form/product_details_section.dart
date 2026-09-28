import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';

/// Sección de Detalles y Especificaciones.
///
/// Cada fila es un widget autónomo [_DetailItemRow] con ciclo de vida
/// independiente para sus [TextEditingController], eliminando mutaciones de controllers
/// durante la fase de build y evitando fugas de memoria.
class ProductDetailsSection extends StatelessWidget {
  const ProductDetailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();

    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen: (p, c) => p.detailRows != c.detailRows,
      builder: (context, state) {
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
                  Expanded(
                    child: Text(
                      'Especifica propiedades fijas como Marca, Material, Garantía, etc.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: cubit.addDetailRow,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Añadir detalle',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.detailRows.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    'Sin detalles adicionales. Agrega uno con el botón superior.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
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
                    return _DetailItemRow(
                      key: ValueKey(row.id),
                      row: row,
                      index: idx,
                      onChanged: (updated) => cubit.updateDetailRow(idx, updated),
                      onRemove: () => cubit.removeDetailRow(idx),
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

/// Fila individual de detalle con controladores encapsulados en su propio estado.
class _DetailItemRow extends StatefulWidget {
  final DetailModel row;
  final int index;
  final ValueChanged<DetailModel> onChanged;
  final VoidCallback onRemove;

  const _DetailItemRow({
    super.key,
    required this.row,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_DetailItemRow> createState() => _DetailItemRowState();
}

class _DetailItemRowState extends State<_DetailItemRow> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _valCtrl;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.row.key);
    _valCtrl = TextEditingController(text: widget.row.value);
  }

  @override
  void didUpdateWidget(covariant _DetailItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.row.key != _keyCtrl.text) {
      _keyCtrl.text = widget.row.key;
    }
    if (widget.row.value != _valCtrl.text) {
      _valCtrl.text = widget.row.value;
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: TextField(
            controller: _keyCtrl,
            onChanged: (val) => widget.onChanged(widget.row.copyWith(key: val)),
            decoration: InputDecoration(
              hintText: 'Propiedad (ej: Material)',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              isDense: true,
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            ':',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: TextField(
            controller: _valCtrl,
            onChanged: (val) => widget.onChanged(widget.row.copyWith(value: val)),
            decoration: InputDecoration(
              hintText: 'Valor (ej: Acero)',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: widget.onRemove,
          icon: Icon(
            Icons.delete_outline_rounded,
            color: Colors.red.shade400,
            size: 19,
          ),
          tooltip: 'Eliminar detalle',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          splashRadius: 16,
        ),
      ],
    );
  }
}
