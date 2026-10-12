import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';

class PurchaseOrderItemsTable extends StatelessWidget {
  final List<InventoryEntryItemEntity> items;
  final ValueChanged<int> onRemoveItem;
  final Function(int index, double qty) onUpdateQuantity;
  final Function(int index, double cost) onUpdateCost;
  final VoidCallback onAddNewRow;

  const PurchaseOrderItemsTable({
    super.key,
    required this.items,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
    required this.onUpdateCost,
    required this.onAddNewRow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCost = items.fold<double>(0.0, (sum, i) => sum + i.subtotal);
    final totalUnits = items.fold<double>(0.0, (sum, i) => sum + i.quantity);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header de la Sección
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÍTEMS DE LA ORDEN',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? const Color(0xFFE2E8F0)
                                      : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${items.length} producto${items.length == 1 ? '' : 's'} agregado${items.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: onAddNewRow,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Agregar Producto'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isDark
                              ? const Color(0xFF312E81)
                              : const Color(0xFFEEF2FF),
                      foregroundColor:
                          isDark
                              ? const Color(0xFFC7D2FE)
                              : const Color(0xFF4F46E5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),

            // Encabezados de Columna
            Container(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text('PRODUCTO / VARIANTE', style: _headerStyle),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'CANTIDAD',
                      textAlign: TextAlign.center,
                      style: _headerStyle,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'COSTO UNIT.',
                      textAlign: TextAlign.right,
                      style: _headerStyle,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'SUBTOTAL',
                      textAlign: TextAlign.right,
                      style: _headerStyle,
                    ),
                  ),
                  SizedBox(width: 48), // Espacio de acción
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),

            // Filas o Estado Vacío
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(36.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 44,
                        color:
                            isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tu orden está vacía',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color:
                              isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Presiona "Agregar Producto" para añadir artículos a esta orden de compra.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder:
                    (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color:
                          isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                    ),
                itemBuilder: (context, index) {
                  return _PurchaseOrderRow(
                    key: ValueKey(
                      'po_row_${items[index].productId}_${items[index].variantId}_$index',
                    ),
                    index: index,
                    item: items[index],
                    isDark: isDark,
                    onUpdateQuantity: (qty) => onUpdateQuantity(index, qty),
                    onUpdateCost: (cost) => onUpdateCost(index, cost),
                    onRemove: () => onRemoveItem(index),
                  );
                },
              ),

              // Pie de Tabla con Resumen Integrado (Estilo ERP Pro)
              Divider(
                height: 1,
                thickness: 1,
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              Container(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _StatBadge(
                          label: 'Items',
                          value: '${items.length}',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        _StatBadge(
                          label: 'Unidades',
                          value: totalUnits.toStringAsFixed(0),
                          isDark: isDark,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'TOTAL ESTIMADO: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          'S/ ${totalCost.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color:
                                isDark
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Color(0xFF64748B),
    letterSpacing: 0.6,
  );
}

class _PurchaseOrderRow extends StatefulWidget {
  final int index;
  final InventoryEntryItemEntity item;
  final bool isDark;
  final ValueChanged<double> onUpdateQuantity;
  final ValueChanged<double> onUpdateCost;
  final VoidCallback onRemove;

  const _PurchaseOrderRow({
    super.key,
    required this.index,
    required this.item,
    required this.isDark,
    required this.onUpdateQuantity,
    required this.onUpdateCost,
    required this.onRemove,
  });

  @override
  State<_PurchaseOrderRow> createState() => _PurchaseOrderRowState();
}

class _PurchaseOrderRowState extends State<_PurchaseOrderRow> {
  bool _isHovered = false;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _costCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(0),
    );
    _costCtrl = TextEditingController(
      text: widget.item.unitCost.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(covariant _PurchaseOrderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      final text = widget.item.quantity.toStringAsFixed(0);
      if (_qtyCtrl.text != text) {
        _qtyCtrl.text = text;
      }
    }
    if (oldWidget.item.unitCost != widget.item.unitCost) {
      final text = widget.item.unitCost.toStringAsFixed(2);
      if (_costCtrl.text != text) {
        _costCtrl.text = text;
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final subtotal = item.quantity * item.unitCost;
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color:
            _isHovered
                ? (isDark
                    ? const Color(0xFF334155).withValues(alpha: 0.4)
                    : const Color(0xFFF1F5F9))
                : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Producto & Miniatura
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child:
                          item.imageUrl != null &&
                                  item.imageUrl!.trim().isNotEmpty
                              ? CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      color:
                                          isDark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFF1F5F9),
                                    ),
                                errorWidget:
                                    (context, url, error) => Container(
                                      color:
                                          isDark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFF1F5F9),
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                              )
                              : Container(
                                color:
                                    isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFF1F5F9),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.variantLabel.isNotEmpty &&
                            item.variantLabel != 'Default') ...[
                          const SizedBox(height: 2),
                          Text(
                            item.variantLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Input Cantidad
            Expanded(
              flex: 2,
              child: Center(
                child: SizedBox(
                  width: 80,
                  height: 34,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _inputDecorationCompact(isDark),
                    onChanged: (val) {
                      final qty = double.tryParse(val.trim());
                      if (qty != null && qty > 0) {
                        widget.onUpdateQuantity(qty);
                      }
                    },
                  ),
                ),
              ),
            ),

            // Input Costo Unitario
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 105,
                  height: 34,
                  child: TextFormField(
                    controller: _costCtrl,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _inputDecorationCompact(isDark, prefix: 'S/ '),
                    onChanged: (val) {
                      final cost = double.tryParse(val.trim());
                      if (cost != null && cost >= 0) {
                        widget.onUpdateCost(cost);
                      }
                    },
                  ),
                ),
              ),
            ),

            // Subtotal
            Expanded(
              flex: 2,
              child: Text(
                'S/ ${subtotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),

            // Eliminar
            SizedBox(
              width: 48,
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: AppColors.danger,
                  ),
                  tooltip: 'Eliminar ítem',
                  splashRadius: 18,
                  onPressed: widget.onRemove,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecorationCompact(bool isDark, {String? prefix}) {
    return InputDecoration(
      prefixText: prefix,
      prefixStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
