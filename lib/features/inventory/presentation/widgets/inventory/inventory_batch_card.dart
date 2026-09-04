import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

class InventoryBatchCard extends StatefulWidget {
  final InventoryBatchItem batch;
  final bool isSelected;
  final VoidCallback? onTap;

  const InventoryBatchCard({
    super.key,
    required this.batch,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<InventoryBatchCard> createState() => _InventoryBatchCardState();
}

class _InventoryBatchCardState extends State<InventoryBatchCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final statusConfig = _getStatusConfig(widget.batch);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapUp: (details) => _showContextMenu(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary.withValues(alpha: 0.02)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary
                  : _isHovered
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.border,
              width: widget.isSelected ? 1.8 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : _isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : AppColors.cardShadow(opacity: 0.02),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap ??
                    () {
                      context.push(
                        '/admin/product/${widget.batch.productId}?variantId=${widget.batch.variantId}',
                      );
                    },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Fila 1: Avatar + Título + Status Pill ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thumbnail
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: widget.batch.imageUrl != null &&
                                      widget.batch.imageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: widget.batch.imageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          Container(color: AppColors.background),
                                      errorWidget: (context, url, error) =>
                                          const Icon(
                                        Icons.broken_image_outlined,
                                        size: 18,
                                        color: AppColors.textMuted,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 20,
                                      color: AppColors.textMuted,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Nombre del Producto y Metadatos
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.batch.productName ??
                                      'Producto ${widget.batch.productId.substring(0, 8)}',
                                  style: TextStyle(
                                    fontWeight: widget.isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    fontSize: 14.5,
                                    color: AppColors.textPrimary,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (widget.batch.variantAttrs != null &&
                                        widget.batch.variantAttrs!.isNotEmpty &&
                                        widget.batch.variantAttrs != 'Única')
                                      widget.batch.variantAttrs!,
                                    if (widget.batch.sku != null &&
                                        widget.batch.sku!.isNotEmpty)
                                      'SKU: ${widget.batch.sku}',
                                    if (widget.batch.warehouseName != null)
                                      widget.batch.warehouseName!,
                                  ].join(' · '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status Pill con alto contraste WCAG
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusConfig.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusConfig.color.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusConfig.icon,
                                  size: 12,
                                  color: statusConfig.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusConfig.label,
                                  style: TextStyle(
                                    color: statusConfig.color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10.5,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Fila 2: Chips Operativos (Lote Monospace + Stock + Fecha) ──
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Chip de Lote Monospace
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.tag_rounded,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  widget.batch.batchNumber == 'DEFAULT'
                                      ? 'Sin lote'
                                      : widget.batch.batchNumber,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Chip de Stock Disponible
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.teal.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.inventory_2_rounded,
                                  size: 12,
                                  color: AppColors.teal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.batch.availableQuantity} uds.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.tealDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Chip de Caducidad
                          if (widget.batch.expiryDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: statusConfig.color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusConfig.color.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 11,
                                    color: statusConfig.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Vence: ${widget.batch.expiryDate!.substring(0, 10)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: statusConfig.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Proveedor si existe
                          if (widget.batch.supplierName != null &&
                              widget.batch.supplierName!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  size: 12,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.batch.supplierName!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(Offset position) async {
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'kardex',
          child: Row(
            children: const [
              Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Ver en Kárdex', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'product',
          child: Row(
            children: const [
              Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Ver Ficha de Producto', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: const [
              Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Copiar código de lote', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );

    if (value == null || !mounted) return;
    switch (value) {
      case 'kardex':
        context.push(
          '/admin/kardex?productId=${widget.batch.productId}&variantId=${widget.batch.variantId}&batchId=${widget.batch.id}&batchNumber=${Uri.encodeComponent(widget.batch.batchNumber)}&productName=${Uri.encodeComponent(widget.batch.productName ?? '')}&variantName=${Uri.encodeComponent(widget.batch.variantAttrs ?? widget.batch.sku ?? '')}',
        );
        break;
      case 'product':
        context.push(
          '/admin/product/${widget.batch.productId}?variantId=${widget.batch.variantId}',
        );
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: widget.batch.batchNumber));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lote ${widget.batch.batchNumber} copiado'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
    }
  }

  _StatusConfig _getStatusConfig(InventoryBatchItem b) {
    switch (b.status) {
      case 'vencido':
        return _StatusConfig(
          color: AppColors.danger,
          icon: Icons.block_rounded,
          label: 'VENCIDO',
        );
      case 'critico':
        final d = b.daysRemaining ?? 0;
        return _StatusConfig(
          color: AppColors.warning,
          icon: Icons.warning_amber_rounded,
          label: d == 0 ? 'HOY' : d == 1 ? 'MAÑANA' : 'EN $d DÍAS',
        );
      case 'proximo':
        return _StatusConfig(
          color: AppColors.info,
          icon: Icons.schedule_rounded,
          label: 'EN ${b.daysRemaining} DÍAS',
        );
      case 'normal':
        return _StatusConfig(
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
          label: 'NORMAL',
        );
      default:
        return _StatusConfig(
          color: AppColors.textSecondary,
          icon: Icons.remove_circle_outline_rounded,
          label: 'SIN VTO.',
        );
    }
  }
}

class _StatusConfig {
  final Color color;
  final IconData icon;
  final String label;

  _StatusConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}
