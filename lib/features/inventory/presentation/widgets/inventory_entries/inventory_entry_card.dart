import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';

/// Tarjeta táctil y pro-tool para visualizar una entrada de inventario.
/// Encapsulada con [RepaintBoundary] para aislar animaciones de hover
/// y selección sin invalidar capas de renderizado en dispositivos de bajos recursos.
class InventoryEntryCard extends StatefulWidget {
  final InventoryEntryEntity entry;
  final VoidCallback onTap;
  final bool isSelected;

  const InventoryEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  State<InventoryEntryCard> createState() => _InventoryEntryCardState();
}

class _InventoryEntryCardState extends State<InventoryEntryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final entry = widget.entry;
    final hasDoc =
        entry.documentType != 'NINGUNO' &&
        entry.documentNumber != null &&
        entry.documentNumber!.isNotEmpty;

    final mode = (entry.paymentMode ?? 'CONTADO').trim().toUpperCase();
    final String paymentLabel;
    final IconData paymentIcon;
    final Color paymentColor;
    final Color paymentBgColor;

    if (mode == 'AJUSTE' || mode.contains('AJUSTE')) {
      paymentLabel = 'Ajuste';
      paymentIcon = Icons.tune_rounded;
      paymentColor = const Color(0xFFB45309);
      paymentBgColor = const Color(0xFFFFFBEB);
    } else if (mode.contains('CREDIT') || mode.contains('CRÉDITO')) {
      paymentLabel = 'Crédito';
      paymentIcon = Icons.credit_card_rounded;
      paymentColor = const Color(0xFF1D4ED8);
      paymentBgColor = const Color(0xFFEFF6FF);
    } else if (mode == 'DONACION' || mode == 'DONACIÓN') {
      paymentLabel = 'Donación';
      paymentIcon = Icons.volunteer_activism_rounded;
      paymentColor = const Color(0xFF86198F);
      paymentBgColor = const Color(0xFFFDF4FF);
    } else if (mode == 'TRANSFERENCIA') {
      paymentLabel = 'Transferencia';
      paymentIcon = Icons.account_balance_rounded;
      paymentColor = const Color(0xFF0F766E);
      paymentBgColor = const Color(0xFFF0FDFA);
    } else {
      paymentLabel = 'Contado';
      paymentIcon = Icons.payments_rounded;
      paymentColor = AppColors.successDark;
      paymentBgColor = AppColors.successLight;
    }

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            color:
                widget.isSelected
                    ? AppColors.teal.withValues(alpha: 0.04)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  widget.isSelected
                      ? AppColors.teal
                      : _isHovered
                      ? AppColors.teal.withValues(alpha: 0.35)
                      : const Color(0xFFE2E8F0),
              width: (widget.isSelected || _isHovered) ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: widget.isSelected ? 0.08 : (_isHovered ? 0.06 : 0.025),
                ),
                blurRadius: (widget.isSelected || _isHovered) ? 14 : 8,
                offset: Offset(0, (widget.isSelected || _isHovered) ? 4 : 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  if (widget.isSelected)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 3.5,
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.move_to_inbox_rounded,
                                color: AppColors.tealDark,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.supplierName ?? 'Sin proveedor',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    entry.createdAt != null
                                        ? fmt.format(entry.createdAt!)
                                        : '—',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'S/ ${entry.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${entry.itemCount} prod. (${entry.totalQuantity.toInt()} uds.)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (entry.warehouseName != null)
                              _Pill(
                                icon: Icons.storefront_rounded,
                                label: entry.warehouseName!,
                                color: AppColors.textSecondary,
                                bgColor: AppColors.background,
                              ),
                            _Pill(
                              icon: paymentIcon,
                              label: paymentLabel,
                              color: paymentColor,
                              bgColor: paymentBgColor,
                            ),
                            if (hasDoc)
                              _Pill(
                                icon: Icons.receipt_rounded,
                                label:
                                    '${entry.documentType}: ${entry.documentNumber}',
                                color: AppColors.textSecondary,
                                bgColor: AppColors.background,
                              ),
                            if (entry.purchaseOrderId != null)
                              _Pill(
                                icon: Icons.link_rounded,
                                label:
                                    'Orden #${entry.purchaseOrderId!.length >= 8 ? entry.purchaseOrderId!.substring(0, 8).toUpperCase() : entry.purchaseOrderId!.toUpperCase()}',
                                color: const Color(0xFF7E22CE),
                                bgColor: const Color(0xFFFAF5FF),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
