import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';

/// Tarjeta de un producto dentro de la entrada de inventario (móvil).
///
/// Cantidad y costo se editan en la misma tarjeta (sin diálogos) y el
/// subtotal se actualiza al instante. Quitar el producto no pide
/// confirmación: la pantalla ofrece "Deshacer".
class EntryItemCard extends StatefulWidget {
  final InventoryEntryItemEntity item;
  final ValueChanged<double> onUpdateQuantity;
  final ValueChanged<double> onUpdateCost;
  final VoidCallback? onEditBatch;
  final VoidCallback onRemove;

  const EntryItemCard({
    super.key,
    required this.item,
    required this.onUpdateQuantity,
    required this.onUpdateCost,
    required this.onRemove,
    this.onEditBatch,
  });

  @override
  State<EntryItemCard> createState() => _EntryItemCardState();
}

class _EntryItemCardState extends State<EntryItemCard> {
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
  void didUpdateWidget(covariant EntryItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza desde afuera solo si el usuario no está escribiendo ahí.
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

  // Al salir del campo, muestra el valor realmente guardado.
  void _onQtyFocusChange() {
    if (!_qtyFocus.hasFocus) {
      _qtyCtrl.text = _fmtQty(widget.item.quantity);
    }
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

  void _step(int delta) {
    AppFeedbackService.selectionClick();
    final next = widget.item.quantity + delta;
    if (next < 1) return;
    widget.onUpdateQuantity(next);
    _qtyCtrl.text = _fmtQty(next);
  }

  void _selectAll(TextEditingController c) {
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final textTheme = Theme.of(context).textTheme;
    final subtotal = item.quantity * item.unitCost;
    final isZeroCost = item.unitCost <= 0;

    final hasVariant =
        item.variantLabel.isNotEmpty &&
        item.variantLabel != 'Default' &&
        item.variantLabel != 'Variante Única';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Producto + quitar ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(url: item.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (hasVariant)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.variantLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      if (item.usesBatches && widget.onEditBatch != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _BatchChip(
                            batchNumber: item.batchNumber,
                            expiryDate: item.expiryDate,
                            onTap: widget.onEditBatch!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Quitar producto',
                onPressed: widget.onRemove,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 22,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Cantidad y costo ──
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Caption('Cantidad'),
                      const SizedBox(height: 6),
                      _MiniStepper(
                        controller: _qtyCtrl,
                        focusNode: _qtyFocus,
                        canDecrease: item.quantity > 1,
                        onDecrease: () => _step(-1),
                        onIncrease: () => _step(1),
                        onTap: () => _selectAll(_qtyCtrl),
                        onChanged: (val) {
                          final qty = double.tryParse(
                            val.trim().replaceAll(',', '.'),
                          );
                          if (qty != null && qty > 0) {
                            widget.onUpdateQuantity(qty);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Caption(
                        'Costo unitario',
                        color: isZeroCost ? AppColors.warning : null,
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _costCtrl,
                          focusNode: _costFocus,
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
                          onChanged: (val) {
                            final cost = double.tryParse(
                              val.trim().replaceAll(',', '.'),
                            );
                            if (cost != null && cost >= 0) {
                              widget.onUpdateCost(cost);
                            }
                          },
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: _fieldDecoration(
                            accent: isZeroCost ? AppColors.warning : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Subtotal ──
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isZeroCost ? 'Costo en S/ 0.00' : 'Subtotal',
                    style: textTheme.bodySmall?.copyWith(
                      color:
                          isZeroCost
                              ? AppColors.warning
                              : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'S/ ${subtotal.toStringAsFixed(2)}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _fieldDecoration({Color? accent}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      isDense: true,
      prefixText: 'S/ ',
      prefixStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      border: border(accent ?? AppColors.border),
      enabledBorder: border(accent ?? AppColors.border),
      focusedBorder: border(accent ?? AppColors.primary, 1.5),
    );
  }
}

class _Caption extends StatelessWidget {
  final String text;
  final Color? color;
  const _Caption(this.text, {this.color});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: color ?? AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _MiniStepper extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canDecrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  const _MiniStepper({
    required this.controller,
    required this.focusNode,
    required this.canDecrease,
    required this.onDecrease,
    required this.onIncrease,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            semanticLabel: 'Disminuir cantidad',
            enabled: canDecrease,
            onTap: onDecrease,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
              ],
              onTap: onTap,
              onChanged: onChanged,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            semanticLabel: 'Aumentar cantidad',
            enabled: true,
            onTap: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 38,
            height: 40,
            decoration: BoxDecoration(
              color:
                  enabled
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _BatchChip extends StatelessWidget {
  final String batchNumber;
  final DateTime? expiryDate;
  final VoidCallback onTap;

  const _BatchChip({
    required this.batchNumber,
    required this.expiryDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pending = batchNumber.isEmpty || batchNumber == 'DEFAULT';
    final color = pending ? AppColors.warning : AppColors.textSecondary;

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
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
  const _Thumb({this.url});

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final hasUrl = url != null && url!.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child:
            hasUrl
                ? CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => const SizedBox.shrink(),
                  errorWidget:
                      (context, _, _) => const Icon(
                        Icons.inventory_2_outlined,
                        size: 22,
                        color: AppColors.textMuted,
                      ),
                )
                : const Icon(
                  Icons.inventory_2_outlined,
                  size: 22,
                  color: AppColors.textMuted,
                ),
      ),
    );
  }
}
