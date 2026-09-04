import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class KardexCard extends StatelessWidget {
  final KardexMovementEntity item;
  final bool isLast;

  const KardexCard({super.key, required this.item, this.isLast = false});

  Widget _buildBadge(String type) {
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
    final isEntry = upperType.contains('INGRESO') || upperType.contains('DEVOLUCIÓN');
    final isReturn = upperType.contains('DEVOLUCIÓN');
    final isSale = upperType.contains('VENTA');

    final Color iconColor = isEntry
        ? (isReturn ? Colors.purple : Colors.green)
        : (isSale ? Colors.blue : Colors.red);

    final IconData iconData = isEntry ? Icons.arrow_downward : Icons.arrow_upward;

    // Construcción de la línea de metadata del producto y variante
    final List<String> metaParts = [];
    if (item.attrsText != null &&
        item.attrsText!.isNotEmpty &&
        item.attrsText != 'Única') {
      metaParts.add(item.attrsText!);
    }
    if (item.sku != null && item.sku!.isNotEmpty) {
      metaParts.add('SKU: ${item.sku}');
    }
    if (item.batchNumber != null &&
        item.batchNumber!.isNotEmpty &&
        item.batchNumber != 'DEFAULT') {
      metaParts.add('Lote: ${item.batchNumber}');
    }
    if (item.warehouseName != null && item.warehouseName!.isNotEmpty) {
      metaParts.add(item.warehouseName!);
    }

    final String displayName = (item.productName != null && item.productName!.isNotEmpty)
        ? item.productName!
        : item.description;

    // Formatear referencia si es UUID
    String formattedReference = item.reference;
    if (formattedReference.isNotEmpty && formattedReference.length == 36 && formattedReference.contains('-')) {
      formattedReference = '#${formattedReference.substring(0, 8)}';
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Línea de tiempo visual ──
          SizedBox(
            width: 28,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!isLast)
                  Positioned(
                    top: 24,
                    bottom: 0,
                    child: Container(width: 2, color: AppColors.border),
                  ),
                Positioned(
                  top: 22,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.35),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Card de Movimiento ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow(),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header de la card: Fecha + Badge de Tipo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatDate(item.date),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        _buildBadge(item.type),
                      ],
                    ),
                    const Divider(height: 18, color: AppColors.border),

                    // Cuerpo del producto con thumbnail real de variante
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail con fallback
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: item.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: AppColors.background,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      iconData,
                                      color: iconColor,
                                      size: 24,
                                    ),
                                  )
                                : Icon(iconData, color: iconColor, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Información del producto y variante
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: AppColors.textPrimary,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (metaParts.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  metaParts.join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (formattedReference.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.tag_rounded,
                                      size: 13,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        formattedReference,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Fila de Métricas: Cantidad, Costo Unitario y Saldo Final
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Metric(
                            label: 'Cantidad',
                            value: '${isEntry ? "+" : "-"}${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} uds.',
                            valueColor: isEntry ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                          _Metric(
                            label: 'Costo Unit.',
                            value: 'S/ ${item.unitCost.toStringAsFixed(2)}',
                          ),
                          _Metric(
                            label: 'Saldo Kardex',
                            value: '${item.balance.toStringAsFixed(item.balance % 1 == 0 ? 0 : 2)} uds.',
                            valueColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year  $hour:$minute';
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Metric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
