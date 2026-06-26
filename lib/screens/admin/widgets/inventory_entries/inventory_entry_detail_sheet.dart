import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/inventory_entry_model.dart';
import 'package:inventory_store_app/models/inventory_entry_item_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:inventory_store_app/shared/widgets/detail_sheet_header.dart';
import 'package:inventory_store_app/shared/widgets/product_item_card.dart';

class InventoryEntryDetailSheet extends StatefulWidget {
  final InventoryEntryModel entry;
  final Future<List<InventoryEntryItemModel>> Function() loadItems;

  final bool isBottomSheet;

  const InventoryEntryDetailSheet({
    super.key,
    required this.entry,
    required this.loadItems,
    this.isBottomSheet = true,
  });

  @override
  State<InventoryEntryDetailSheet> createState() =>
      _InventoryEntryDetailSheetState();
}

class _InventoryEntryDetailSheetState extends State<InventoryEntryDetailSheet> {
  List<InventoryEntryItemModel>? _items;

  /// `null` → cargando, `false` → error, `true` → datos disponibles
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  @override
  void didUpdateWidget(covariant InventoryEntryDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _items = null;
      });
      _fetchItems();
    }
  }

  // FIX: Antes usaba `.then()` sin `.catchError()`.
  // Un error silencioso dejaba `_loading = true` eternamente y
  // potencialmente lanzaba `Null check operator used on null value`
  // en `_items!.length` del ListView.
  Future<void> _fetchItems() async {
    try {
      final items = await widget.loadItems();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'No se pudieron cargar los productos: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final entry = widget.entry;

    // Migrado de DraggableScrollableSheet a Container de altura fija
    // para consistencia con los otros 3 detail sheets.
    return Container(
      height:
          widget.isBottomSheet
              ? MediaQuery.of(context).size.height * 0.85
              : null,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius:
            widget.isBottomSheet
                ? const BorderRadius.vertical(top: Radius.circular(28))
                : BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header compartido ────────────────────────────────────
          if (widget.isBottomSheet)
            DetailSheetHeader(title: 'Detalle de Entrada')
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'Detalle de Entrada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          const SizedBox(height: 8),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Card de metadata ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Proveedor (jerarquía corregida: label → nombre)
                        const Text(
                          'PROVEEDOR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.supplierName ?? 'Sin proveedor',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Divider(height: 20, color: AppColors.border),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ALMACÉN',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.warehouseName ?? 'Sin almacén',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'FECHA INGRESO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.createdAt != null
                                      ? fmt.format(entry.createdAt!.toLocal())
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: AppColors.border),

                        // Total con animación de conteo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL ENTRADA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: entry.totalAmount),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder:
                                  (_, value, _) => Text(
                                    'S/ ${value.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Sección de productos ─────────────────────────
                  const Text(
                    'Productos Ingresados',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Estados: cargando / error / datos
                  if (_loading)
                    const _ItemsSkeleton()
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_items == null || _items!.isEmpty)
                    const Text(
                      'No hay productos en esta entrada.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else
                    ...List.generate(_items!.length, (index) {
                      final item = _items![index];

                      // Etiqueta de variante + lote si aplica
                      final variantLabel =
                          item.usesBatches
                              ? '${item.variantAttrs} · Lote: ${item.batchNumber}'
                              : item.variantAttrs;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ProductItemCard(
                          imageUrl: item.imageUrl,
                          productName: item.productName,
                          variantLabel: variantLabel,
                          // Fecha de vencimiento como badge si aplica
                          badgeText:
                              item.usesBatches && item.expiryDate != null
                                  ? 'Vence: ${DateFormat('dd/MM/yyyy').format(item.expiryDate!)}'
                                  : null,
                          badgeColor: AppColors.warning,
                          trailing: ItemPriceColumnTrailing(
                            quantityText:
                                '${item.quantity.toStringAsFixed(0)} uds.',
                            unitCostText:
                                'S/ ${item.unitCost.toStringAsFixed(2)} c/u',
                            subtotalText:
                                'S/ ${item.subtotal.toStringAsFixed(2)}',
                          ),
                          animationDelay: Duration(milliseconds: 60 * index),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ItemsSkeleton extends StatelessWidget {
  const _ItemsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (_) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const AppShimmer(width: 52, height: 52, borderRadius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmer(width: 120, height: 14, borderRadius: 4),
                      SizedBox(height: 6),
                      AppShimmer(width: 80, height: 10, borderRadius: 4),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    AppShimmer(width: 50, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    AppShimmer(width: 70, height: 10, borderRadius: 4),
                    SizedBox(height: 6),
                    AppShimmer(width: 60, height: 14, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
