import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:intl/intl.dart';

/// Diálogo modal de consulta rápida de Lotes y Stock sin salir de la caja POS.
class PosQuickStockDialog extends StatefulWidget {
  final List<ProductEntity> products;
  final ValueChanged<ProductEntity>? onAddToCart;

  const PosQuickStockDialog({
    super.key,
    required this.products,
    this.onAddToCart,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ProductEntity> products,
    ValueChanged<ProductEntity>? onAddToCart,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => PosQuickStockDialog(
        products: products,
        onAddToCart: onAddToCart,
      ),
    );
  }

  @override
  State<PosQuickStockDialog> createState() => _PosQuickStockDialogState();
}

class _PosQuickStockDialogState extends State<PosQuickStockDialog> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      if (_filter.isEmpty) return true;
      final query = _filter.toLowerCase();
      final nameMatches = p.name.toLowerCase().contains(query);
      final ingredientMatches = (p.details['active_ingredient'] as String? ?? '')
          .toLowerCase()
          .contains(query);
      final batchMatches = p.warehouseStockBatches.any(
        (b) => b.batchNumber.toLowerCase().contains(query),
      );
      return nameMatches || ingredientMatches || batchMatches;
    }).toList();

    final dateFormat = DateFormat('yyyy-MM-dd');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header del Diálogo ──────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF142B1A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: Color(0xFF142B1A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Consulta Rápida de Stock y Lotes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Verifica disponibilidad, lotes activos y vencimientos sin pausar la caja',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar (Esc)',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Campo de Búsqueda Rápida de Lotes ────────────────────────────
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _filter = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar por producto, ingrediente o código de lote...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Lista de Productos y sus Lotes ──────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: AppColors.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No se encontraron productos o lotes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          final batches = product.warehouseStockBatches;
                          final hasBatches = batches.isNotEmpty;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (product.details['active_ingredient'] != null &&
                                              (product.details['active_ingredient'] as String).isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.science_outlined,
                                                    size: 14,
                                                    color: Color(0xFF047857),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    product.details['active_ingredient'] as String,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF047857),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Stock total y precio
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: product.totalStock > 0
                                                ? AppColors.tealLight
                                                : AppColors.errorLight,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            product.totalStock > 0
                                                ? 'Stock: ${product.totalStock}'
                                                : 'Agotado',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: product.totalStock > 0
                                                  ? AppColors.tealDark
                                                  : AppColors.error,
                                            ),
                                          ),
                                        ),
                                        if (product.displaySalePrice != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'S/ ${product.displaySalePrice!.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),

                                // ── Lotes Disponibles (Estilo Referencia Imagen 2) ──
                                if (hasBatches) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    'LOTES DISPONIBLES',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: batches.map((b) {
                                      final isNearExpiry = b.expiryDate != null &&
                                          b.expiryDate!.isBefore(
                                            DateTime.now().add(const Duration(days: 90)),
                                          );

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isNearExpiry
                                                ? AppColors.warning.withValues(alpha: 0.4)
                                                : AppColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              b.batchNumber,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Cant: ${b.availableQuantity.toInt()}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            if (b.expiryDate != null) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '• Vence: ${dateFormat.format(b.expiryDate!)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isNearExpiry
                                                      ? AppColors.warningDark
                                                      : AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // ── Footer con Botón a Inventario Completo ──────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/inventory');
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Abrir Gestión de Inventario Completa'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF142B1A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
