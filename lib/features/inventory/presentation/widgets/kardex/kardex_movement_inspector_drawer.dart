import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';

class KardexMovementInspectorDrawer extends StatelessWidget {
  final KardexMovementEntity item;
  final VoidCallback? onClose;

  const KardexMovementInspectorDrawer({
    super.key,
    required this.item,
    this.onClose,
  });

  static Future<void> showAsBottomSheet(
    BuildContext context,
    KardexMovementEntity item,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull handle iOS
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: KardexMovementInspectorDrawer(
                    item: item,
                    onClose: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.info,
    );
  }

  Widget _buildTypeBadge(String type) {
    final upperType = type.toUpperCase();
    final isEntry = upperType.contains('INGRESO');
    final isReturn = upperType.contains('DEVOLUCIÓN');
    final isSale = upperType.contains('VENTA');

    Color bgColor = Colors.red.shade50;
    Color textColor = Colors.red.shade700;
    String label = 'SALIDA';

    if (isEntry) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      label = 'INGRESO';
    } else if (isReturn) {
      bgColor = Colors.purple.shade50;
      textColor = Colors.purple.shade700;
      label = 'DEVOLUCIÓN';
    } else if (isSale) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      label = 'VENTA';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upperType = item.type.toUpperCase();
    final isEntry =
        upperType.contains('INGRESO') || upperType.contains('DEVOLUCIÓN');
    final isReturn = upperType.contains('DEVOLUCIÓN');
    final isSale = upperType.contains('VENTA');

    final Color deltaColor = isEntry
        ? (isReturn ? Colors.purple.shade700 : Colors.green.shade700)
        : (isSale ? Colors.blue.shade700 : Colors.red.shade700);

    final String deltaSign = isEntry ? '+' : '-';
    final double quantityAbs = item.quantity.abs();
    final double totalValue = quantityAbs * item.unitCost;
    final String formattedDate = DateFormat('dd/MM/yyyy · HH:mm').format(item.date);

    final String displayName =
        (item.productName != null && item.productName!.isNotEmpty)
            ? item.productName!
            : item.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header de Inspección ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildTypeBadge(item.type),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (onClose != null)
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.textSecondary,
                tooltip: 'Cerrar inspector',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Hero de Producto & Variante ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 54,
                  height: 54,
                  color: AppColors.surface,
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget:
                            (context, url, error) => const Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.textSecondary,
                              size: 24,
                            ),
                      )
                      : const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.attrsText != null &&
                            item.attrsText!.isNotEmpty &&
                            item.attrsText != 'Única')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.attrsText!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        if (item.sku != null && item.sku!.isNotEmpty)
                          InkWell(
                            onTap: () => _copyToClipboard(context, item.sku!, 'SKU'),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'SKU: ${item.sku}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Grid de Impacto Financiero & Unidades ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.02),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cantidad Operada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: deltaColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$deltaSign${quantityAbs.toInt()} uds.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: deltaColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.border),
              _DetailRow(
                label: 'Costo Unitario',
                value: 'S/ ${item.unitCost.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Valor Total Operado',
                value: 'S/ ${totalValue.toStringAsFixed(2)}',
                valueWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Saldo Kardex Resultante',
                value: '${item.balance.toInt()} uds.',
                valueColor: AppColors.textPrimary,
                valueWeight: FontWeight.w800,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Trazabilidad & Logística ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.02),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trazabilidad Logística',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Almacén',
                value: item.warehouseName ?? 'Almacén Principal',
                icon: Icons.store_rounded,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Lote Asignado',
                value:
                    (item.batchNumber != null &&
                            item.batchNumber!.isNotEmpty &&
                            item.batchNumber != 'DEFAULT')
                        ? item.batchNumber!
                        : 'Stock sin lote',
                icon: Icons.layers_rounded,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.tag_rounded,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Referencia / Doc',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _copyToClipboard(
                      context,
                      item.reference,
                      'Referencia',
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Text(
                            item.reference.length > 16
                                ? '#${item.reference.substring(0, 10)}...'
                                : item.reference,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (item.description.isNotEmpty &&
                  item.description != displayName) ...[
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Observación',
                  value: item.description,
                  icon: Icons.notes_rounded,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Botones de Acción Rápida ──
        OutlinedButton.icon(
          onPressed: () {
            _copyToClipboard(context, item.reference, 'Referencia');
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copiar Número de Referencia'),
        ),
        const SizedBox(height: 8),
        if (item.variantId.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () {
              // Navegar al detalle de producto
              context.push(
                '/admin/product/${item.productName}?variantId=${item.variantId}',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Ver Producto en Catálogo'),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final FontWeight? valueWeight;

  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.valueWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: valueWeight ?? FontWeight.w600,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
