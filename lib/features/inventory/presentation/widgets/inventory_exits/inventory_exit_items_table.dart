import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';

class InventoryExitItemsTable extends StatelessWidget {
  final List<ExitItemUI> items;
  final ValueChanged<int> onRemoveItem;
  final Function(int index, double qty) onUpdateQuantity;
  final VoidCallback onAddNewRow;

  const InventoryExitItemsTable({
    super.key,
    required this.items,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
    required this.onAddNewRow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalLoss = items.fold<double>(0.0, (sum, i) => sum + i.totalCost);
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
            // Header
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
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.outbox_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÍTEMS A RETIRAR',
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
                            '${items.length} producto${items.length == 1 ? '' : 's'} a dar de baja',
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
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFFEE2E2),
                      foregroundColor:
                          isDark
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFDC2626),
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
                  Expanded(flex: 2, child: Text('LOTE', style: _headerStyle)),
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
                      'PÉRDIDA',
                      textAlign: TextAlign.right,
                      style: _headerStyle,
                    ),
                  ),
                  SizedBox(width: 48),
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
                        Icons.outbox_rounded,
                        size: 44,
                        color:
                            isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sin productos a retirar',
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
                        'Presiona "Agregar Producto" para registrar las salidas de almacén.',
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
                  return _ExitRow(
                    key: ValueKey(
                      'exit_row_${items[index].product.id}_${items[index].variant.id}_$index',
                    ),
                    index: index,
                    item: items[index],
                    isDark: isDark,
                    onUpdateQuantity: (qty) => onUpdateQuantity(index, qty),
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
                          label: 'Líneas',
                          value: '${items.length}',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        _StatBadge(
                          label: 'Unidades Retiradas',
                          value: totalUnits.toStringAsFixed(0),
                          isDark: isDark,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'PÉRDIDA ESTIMADA: ',
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
                          'S/ ${totalLoss.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: Color(0xFFEF4444),
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

class _ExitRow extends StatefulWidget {
  final int index;
  final ExitItemUI item;
  final bool isDark;
  final ValueChanged<double> onUpdateQuantity;
  final VoidCallback onRemove;

  const _ExitRow({
    super.key,
    required this.index,
    required this.item,
    required this.isDark,
    required this.onUpdateQuantity,
    required this.onRemove,
  });

  @override
  State<_ExitRow> createState() => _ExitRowState();
}

class _ExitRowState extends State<_ExitRow> {
  bool _isHovered = false;
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(covariant _ExitRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      final text = widget.item.quantity.toStringAsFixed(0);
      if (_qtyCtrl.text != text) {
        _qtyCtrl.text = text;
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  String? _resolveImageUrl() {
    if (widget.item.variant.images.isNotEmpty) {
      return widget.item.variant.images.first.imageUrl;
    }
    if (widget.item.product.images.isNotEmpty) {
      return widget.item.product.images
          .firstWhere(
            (img) => img.isMain,
            orElse: () => widget.item.product.images.first,
          )
          .imageUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final imageUrl = _resolveImageUrl();
    final batchNumber = item.selectedBatch?['batch_number'] ?? 'DEFAULT';
    final double maxAvailable =
        (item.selectedBatch?['available_quantity'] as num?)?.toDouble() ?? 0.0;

    final attrValues =
        item.variant.attributeValues.map((v) => v.value).toList();
    final attrsText = attrValues.join(' · ');

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
                          imageUrl != null && imageUrl.trim().isNotEmpty
                              ? CachedNetworkImage(
                                imageUrl: imageUrl,
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
                          item.product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (attrsText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            attrsText,
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

            // LOTE
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    batchNumber,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color:
                              isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color:
                              isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFEF4444),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim());
                      if (parsed != null && parsed > 0) {
                        final qty =
                            maxAvailable > 0 && parsed > maxAvailable
                                ? maxAvailable
                                : parsed;
                        widget.onUpdateQuantity(qty);
                      }
                    },
                  ),
                ),
              ),
            ),

            // Costo Unitario (Lectura)
            Expanded(
              flex: 2,
              child: Text(
                'S/ ${item.unitCost.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                ),
              ),
            ),

            // Pérdida Total
            Expanded(
              flex: 2,
              child: Text(
                'S/ ${item.totalCost.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: Color(0xFFEF4444),
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
