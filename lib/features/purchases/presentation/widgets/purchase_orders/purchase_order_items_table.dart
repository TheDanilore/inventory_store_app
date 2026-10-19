import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';

// Anchos fijos de las columnas numéricas: encabezados y filas quedan
// alineados sin importar el ancho del panel. El producto ocupa el resto.
const double _kQtyW = 100;
const double _kCostW = 120;
const double _kSubtotalW = 104;
const double _kActionW = 48;

class PurchaseOrderItemsTable extends StatelessWidget {
  final List<InventoryEntryItemEntity> items;
  final ValueChanged<int> onRemoveItem;
  final Function(int index, double qty) onUpdateQuantity;
  final Function(int index, double cost) onUpdateCost;
  final VoidCallback onAddNewRow;
  final VoidCallback? onScanBarcode;

  /// Si se pasa, los productos con lote muestran un chip para editarlo.
  final ValueChanged<int>? onEditBatch;

  final String title;
  final String emptyTitle;
  final String emptyMessage;

  /// Pie con unidades y total. Ocultarlo si la pantalla ya muestra el total.
  final bool showFooter;

  const PurchaseOrderItemsTable({
    super.key,
    required this.items,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
    required this.onUpdateCost,
    required this.onAddNewRow,
    this.onScanBarcode,
    this.onEditBatch,
    this.title = 'Ítems de la orden',
    this.emptyTitle = 'Aún no hay productos',
    this.emptyMessage = 'Agrega los productos de esta orden para empezar.',
    this.showFooter = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = _Palette.of(isDark);
    final totalCost = items.fold<double>(0.0, (sum, i) => sum + i.subtotal);
    final totalUnits = items.fold<double>(0.0, (sum, i) => sum + i.quantity);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(p),
            Divider(height: 1, thickness: 1, color: p.border),
            if (items.isEmpty)
              _buildEmpty(p)
            else ...[
              _buildColumnHeaders(p),
              Divider(height: 1, thickness: 1, color: p.border),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder:
                    (context, index) =>
                        Divider(height: 1, thickness: 1, color: p.border),
                itemBuilder: (context, index) {
                  return _PurchaseOrderRow(
                    key: ValueKey(
                      'po_row_${items[index].productId}_${items[index].variantId}_$index',
                    ),
                    item: items[index],
                    palette: p,
                    onUpdateQuantity: (qty) => onUpdateQuantity(index, qty),
                    onUpdateCost: (cost) => onUpdateCost(index, cost),
                    onEditBatch:
                        onEditBatch == null ? null : () => onEditBatch!(index),
                    onRemove: () => onRemoveItem(index),
                  );
                },
              ),
              if (showFooter) ...[
                Divider(height: 1, thickness: 1, color: p.border),
                _buildFooter(p, totalUnits, totalCost),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_Palette p) {
    final count = items.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_rounded, size: 18, color: p.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: p.textStrong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? 'Sin productos'
                      : '$count producto${count == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12.5, color: p.textMuted),
                ),
              ],
            ),
          ),
          // Con la lista vacía, la acción vive en el estado vacío.
          if (items.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onScanBarcode != null) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onScanBarcode!();
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Escanear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.accent,
                      side: BorderSide(color: p.accent.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: onAddNewRow,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Agregar producto'),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accentSoft,
                    foregroundColor: p.accent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(_Palette p) {
    final style = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: p.textMuted,
    );
    return Container(
      color: p.subtle,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text('Producto', style: style)),
          SizedBox(
            width: _kQtyW,
            child: Text('Cantidad', textAlign: TextAlign.center, style: style),
          ),
          SizedBox(
            width: _kCostW,
            child: Text(
              'Costo unitario',
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          SizedBox(
            width: _kSubtotalW,
            child: Text('Subtotal', textAlign: TextAlign.right, style: style),
          ),
          const SizedBox(width: _kActionW),
        ],
      ),
    );
  }

  Widget _buildEmpty(_Palette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_shopping_cart_rounded,
                  size: 28,
                  color: p.accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: p.textStrong,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: p.textMuted),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (onScanBarcode != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onScanBarcode!();
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text('Escanear código'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.accent,
                        side: BorderSide(color: p.accent.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: onAddNewRow,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar producto'),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accentFilled,
                      foregroundColor: p.onAccentFilled,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(_Palette p, double totalUnits, double totalCost) {
    final units =
        totalUnits % 1 == 0
            ? totalUnits.toInt().toString()
            : totalUnits.toStringAsFixed(2);
    return Container(
      color: p.subtle,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${items.length} producto${items.length == 1 ? '' : 's'} · $units unidad${totalUnits == 1 ? '' : 'es'}',
            style: TextStyle(fontSize: 13, color: p.textMuted),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Total estimado  ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.textMuted,
                ),
              ),
              Text(
                'S/ ${totalCost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: p.textStrong,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Colores de la tabla. Los acentos salen de [AppColors.primary] en modo claro.
class _Palette {
  final Color surface;
  final Color subtle;
  final Color border;
  final Color textStrong;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color accentFilled;
  final Color onAccentFilled;
  final Color warning;
  final Color danger;

  _Palette({
    required this.surface,
    required this.subtle,
    required this.border,
    required this.textStrong,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.accentFilled,
    required this.onAccentFilled,
    required this.warning,
    required this.danger,
  });

  factory _Palette.of(bool isDark) {
    if (isDark) {
      return _Palette(
        surface: const Color(0xFF1E293B),
        subtle: const Color(0xFF0F172A),
        border: const Color(0xFF334155),
        textStrong: Colors.white,
        textMuted: const Color(0xFF94A3B8),
        accent: const Color(0xFFC7D2FE),
        accentSoft: const Color(0xFF312E81),
        accentFilled: const Color(0xFF6366F1),
        onAccentFilled: Colors.white,
        warning: AppColors.warning,
        danger: AppColors.danger,
      );
    }
    return _Palette(
      surface: Colors.white,
      subtle: const Color(0xFFF8FAFC),
      border: const Color(0xFFE2E8F0),
      textStrong: const Color(0xFF0F172A),
      textMuted: const Color(0xFF64748B),
      accent: AppColors.primary,
      accentSoft: AppColors.primary.withValues(alpha: 0.08),
      accentFilled: AppColors.primary,
      onAccentFilled: Colors.white,
      warning: AppColors.warning,
      danger: AppColors.danger,
    );
  }
}

class _PurchaseOrderRow extends StatefulWidget {
  final InventoryEntryItemEntity item;
  final _Palette palette;
  final ValueChanged<double> onUpdateQuantity;
  final ValueChanged<double> onUpdateCost;
  final VoidCallback? onEditBatch;
  final VoidCallback onRemove;

  const _PurchaseOrderRow({
    super.key,
    required this.item,
    required this.palette,
    required this.onUpdateQuantity,
    required this.onUpdateCost,
    required this.onRemove,
    this.onEditBatch,
  });

  @override
  State<_PurchaseOrderRow> createState() => _PurchaseOrderRowState();
}

class _PurchaseOrderRowState extends State<_PurchaseOrderRow> {
  bool _isHovered = false;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _costCtrl;
  final _qtyFocus = FocusNode();
  final _costFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: _fmtQty(widget.item.quantity));
    _costCtrl = TextEditingController(
      text: widget.item.unitCost.toStringAsFixed(2),
    );
    _qtyFocus.addListener(_onQtyFocusChange);
    _costFocus.addListener(_onCostFocusChange);
  }

  @override
  void didUpdateWidget(covariant _PurchaseOrderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_qtyFocus.hasFocus &&
        oldWidget.item.quantity != widget.item.quantity) {
      _qtyCtrl.text = _fmtQty(widget.item.quantity);
    }
    if (!_costFocus.hasFocus &&
        oldWidget.item.unitCost != widget.item.unitCost) {
      _costCtrl.text = widget.item.unitCost.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _qtyFocus.removeListener(_onQtyFocusChange);
    _costFocus.removeListener(_onCostFocusChange);
    _qtyFocus.dispose();
    _costFocus.dispose();
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  void _onQtyFocusChange() {
    if (!_qtyFocus.hasFocus) _qtyCtrl.text = _fmtQty(widget.item.quantity);
  }

  void _onCostFocusChange() {
    if (!_costFocus.hasFocus) {
      _costCtrl.text = widget.item.unitCost.toStringAsFixed(2);
    }
  }

  static String _fmtQty(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _selectAll(TextEditingController c) {
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final p = widget.palette;
    final subtotal = item.quantity * item.unitCost;
    final isZeroCost = item.unitCost <= 0;
    final hasVariant =
        item.variantLabel.isNotEmpty &&
        item.variantLabel != 'Default' &&
        item.variantLabel != 'Variante Única';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color:
            _isHovered
                ? p.textMuted.withValues(alpha: 0.07)
                : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Producto
            Expanded(
              child: Row(
                children: [
                  _Thumb(url: item.imageUrl, palette: p),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: p.textStrong,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasVariant) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.variantLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: p.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.usesBatches && widget.onEditBatch != null) ...[
                          const SizedBox(height: 6),
                          _BatchChip(
                            batchNumber: item.batchNumber,
                            expiryDate: item.expiryDate,
                            palette: p,
                            onTap: widget.onEditBatch!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Cantidad
            SizedBox(
              width: _kQtyW,
              child: Center(
                child: SizedBox(
                  width: 84,
                  height: 38,
                  child: TextField(
                    controller: _qtyCtrl,
                    focusNode: _qtyFocus,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,3}'),
                      ),
                    ],
                    textAlignVertical: TextAlignVertical.center,
                    onTap: () => _selectAll(_qtyCtrl),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _decoration(p),
                    onChanged: (val) {
                      final qty = double.tryParse(
                        val.trim().replaceAll(',', '.'),
                      );
                      if (qty != null && qty > 0) {
                        widget.onUpdateQuantity(qty);
                      }
                    },
                  ),
                ),
              ),
            ),

            // Costo unitario
            SizedBox(
              width: _kCostW,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 104,
                  height: 38,
                  child: TextField(
                    controller: _costCtrl,
                    focusNode: _costFocus,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    textAlignVertical: TextAlignVertical.center,
                    onTap: () => _selectAll(_costCtrl),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _decoration(
                      p,
                      prefix: 'S/ ',
                      accent: isZeroCost ? p.warning : null,
                    ),
                    onChanged: (val) {
                      final cost = double.tryParse(
                        val.trim().replaceAll(',', '.'),
                      );
                      if (cost != null && cost >= 0) {
                        widget.onUpdateCost(cost);
                      }
                    },
                  ),
                ),
              ),
            ),

            // Subtotal
            SizedBox(
              width: _kSubtotalW,
              child: Text(
                'S/ ${subtotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: p.textStrong,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),

            // Quitar
            SizedBox(
              width: _kActionW,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: _isHovered ? p.danger : p.textMuted,
                  ),
                  tooltip: 'Quitar producto',
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

  InputDecoration _decoration(_Palette p, {String? prefix, Color? accent}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      prefixText: prefix,
      prefixStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: p.textMuted,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      filled: true,
      fillColor: p.surface,
      border: border(accent ?? p.border),
      enabledBorder: border(accent ?? p.border),
      focusedBorder: border(accent ?? p.accentFilled, 1.5),
    );
  }
}

class _BatchChip extends StatelessWidget {
  final String batchNumber;
  final DateTime? expiryDate;
  final _Palette palette;
  final VoidCallback onTap;

  const _BatchChip({
    required this.batchNumber,
    required this.expiryDate,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pending = batchNumber.isEmpty || batchNumber == 'DEFAULT';
    final color = pending ? palette.warning : palette.textMuted;

    String label;
    if (pending) {
      label = 'Asignar lote';
    } else if (expiryDate != null) {
      final d = expiryDate!;
      final date =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      label = 'Lote $batchNumber · vence $date';
    } else {
      label = 'Lote $batchNumber';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tag_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_rounded, size: 12, color: color),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  final _Palette palette;
  const _Thumb({required this.url, required this.palette});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    final placeholder = Container(
      color: palette.subtle,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 20,
        color: palette.textMuted,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 44,
        height: 44,
        child:
            hasUrl
                ? CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => Container(color: palette.subtle),
                  errorWidget: (context, _, _) => placeholder,
                )
                : placeholder,
      ),
    );
  }
}
