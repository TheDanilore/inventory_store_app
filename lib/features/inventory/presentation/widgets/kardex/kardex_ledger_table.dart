import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';

class KardexLedgerTable extends StatelessWidget {
  final List<KardexMovementEntity> items;
  final KardexMovementEntity? selectedItem;
  final ValueChanged<KardexMovementEntity> onSelect;

  const KardexLedgerTable({
    super.key,
    required this.items,
    this.selectedItem,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(opacity: 0.02),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header Row ──
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: const [
                SizedBox(
                  width: 120,
                  child: Text(
                    'FECHA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'TIPO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'PRODUCTO / VARIANTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'LOTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    'ALMACÉN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'DOC / REF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'CANTIDAD',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'COSTO U.',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'SALDO',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(width: 32),
              ],
            ),
          ),

          // ── Rows ──
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = selectedItem?.id == item.id;
              return _LedgerRow(
                item: item,
                isSelected: isSelected,
                onTap: () => onSelect(item),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatefulWidget {
  final KardexMovementEntity item;
  final bool isSelected;
  final VoidCallback onTap;

  const _LedgerRow({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LedgerRow> createState() => _LedgerRowState();
}

class _LedgerRowState extends State<_LedgerRow> {
  bool _isHovered = false;

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
      label = 'DEVOL.';
    } else if (isSale) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      label = 'VENTA';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
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
    final String dateFormatted = DateFormat('dd/MM/yy HH:mm').format(item.date);

    final String displayName =
        (item.productName != null && item.productName!.isNotEmpty)
            ? item.productName!
            : item.description;

    String refShort = item.reference;
    if (refShort.length > 10) {
      refShort = '#${refShort.substring(0, 8)}';
    }

    final Color rowBg = widget.isSelected
        ? AppColors.primary.withValues(alpha: 0.08)
        : (_isHovered
            ? AppColors.background
            : AppColors.surface);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: rowBg,
          child: Row(
            children: [
              // Fecha
              SizedBox(
                width: 120,
                child: Text(
                  dateFormatted,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              // Tipo Badge
              SizedBox(
                width: 90,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildTypeBadge(item.type),
                ),
              ),

              // Producto & Variante
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 28,
                        height: 28,
                        color: AppColors.background,
                        child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget:
                                  (context, url, error) => const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                            )
                            : const Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.attrsText != null &&
                              item.attrsText!.isNotEmpty &&
                              item.attrsText != 'Única')
                            Text(
                              item.attrsText!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Lote
              SizedBox(
                width: 100,
                child: Text(
                  (item.batchNumber != null &&
                          item.batchNumber!.isNotEmpty &&
                          item.batchNumber != 'DEFAULT')
                      ? item.batchNumber!
                      : '—',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: (item.batchNumber != null &&
                            item.batchNumber != 'DEFAULT')
                        ? Colors.purple.shade700
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Almacén
              SizedBox(
                width: 110,
                child: Text(
                  item.warehouseName ?? 'Almacén',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Documento / Ref
              SizedBox(
                width: 90,
                child: Text(
                  refShort,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Cantidad
              SizedBox(
                width: 90,
                child: Text(
                  '$deltaSign${quantityAbs.toInt()} uds.',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: deltaColor,
                  ),
                ),
              ),

              // Costo Unitario
              SizedBox(
                width: 90,
                child: Text(
                  'S/ ${item.unitCost.toStringAsFixed(2)}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              // Saldo Kardex
              SizedBox(
                width: 90,
                child: Text(
                  '${item.balance.toInt()} uds.',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // Botón de detalle
              SizedBox(
                width: 32,
                child: Icon(
                  widget.isSelected
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.more_horiz_rounded,
                  size: 14,
                  color: widget.isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
