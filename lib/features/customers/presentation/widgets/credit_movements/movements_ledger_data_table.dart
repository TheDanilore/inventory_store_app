import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';

class MovementsLedgerDataTable extends StatelessWidget {
  final List<CreditMovementEntity> movements;
  final void Function(String orderId) onOpenOrder;
  final void Function(String text, String label) onCopy;

  const MovementsLedgerDataTable({
    super.key,
    required this.movements,
    required this.onOpenOrder,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'FECHA Y HORA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'CONCEPTO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'REFERENCIA / PEDIDO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'MEDIO / CUENTA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'RESPONSABLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'MONTO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'VER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Table Rows (Iteración directa optimizada sin anidar viewports de scroll)
          for (int i = 0; i < movements.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            DesktopLedgerRow(
              key: ValueKey(movements[i].id),
              movement: movements[i],
              onOpenOrder: onOpenOrder,
              onCopy: onCopy,
            ),
          ],
        ],
      ),
    );
  }
}

class DesktopLedgerRow extends StatefulWidget {
  final CreditMovementEntity movement;
  final void Function(String orderId) onOpenOrder;
  final void Function(String text, String label) onCopy;

  const DesktopLedgerRow({
    super.key,
    required this.movement,
    required this.onOpenOrder,
    required this.onCopy,
  });

  @override
  State<DesktopLedgerRow> createState() => _DesktopLedgerRowState();
}

class _DesktopLedgerRowState extends State<DesktopLedgerRow> {
  bool _isHovered = false;

  void _showContextMenu(TapDownDetails details) {
    final m = widget.movement;
    final position = RelativeRect.fromRect(
      details.globalPosition & const Size(40, 40),
      Offset.zero & MediaQuery.of(context).size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      items: [
        if (m.orderId != null)
          PopupMenuItem(
            value: 'order',
            child: Row(
              children: const [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 10),
                Text('Ver detalle del pedido'),
              ],
            ),
          ),
        if (m.orderNumber != null)
          PopupMenuItem(
            value: 'copy_order',
            child: Row(
              children: const [
                Icon(Icons.copy_rounded, size: 18, color: AppColors.textMuted),
                SizedBox(width: 10),
                Text('Copiar número de pedido'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'copy_amount',
          child: Row(
            children: const [
              Icon(
                Icons.attach_money_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 10),
              Text('Copiar monto'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'order':
          if (m.orderId != null) widget.onOpenOrder(m.orderId!);
          break;
        case 'copy_order':
          if (m.orderNumber != null) {
            widget.onCopy(m.orderNumber!, 'Nº de Pedido');
          }
          break;
        case 'copy_amount':
          widget.onCopy(m.amount.toStringAsFixed(2), 'Monto');
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movement;
    final isCharge = m.movementType == 'CHARGE';
    final sign = isCharge ? '+' : '-';
    final amountColor =
        isCharge ? const Color(0xFFEA580C) : const Color(0xFF16A34A);

    final dateStr =
        m.createdAt != null
            ? DateFormat('d MMM yyyy', 'es').format(m.createdAt!.toLocal())
            : '--';
    final timeStr =
        m.createdAt != null
            ? DateFormat.jm().format(m.createdAt!.toLocal())
            : '--:--';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: _showContextMenu,
        onTap: m.orderId != null ? () => widget.onOpenOrder(m.orderId!) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          child: Row(
            children: [
              // 1. Fecha y Hora
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Concepto / Tipo Badge
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isCharge
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isCharge
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCharge
                              ? Icons.shopping_cart_rounded
                              : Icons.payments_rounded,
                          size: 13,
                          color: amountColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isCharge ? 'Cargo por venta' : 'Abono registrado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Referencia / Pedido
              Expanded(
                flex: 2,
                child:
                    m.orderNumber != null
                        ? InkWell(
                          onTap:
                              m.orderId != null
                                  ? () => widget.onOpenOrder(m.orderId!)
                                  : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  '#${m.orderNumber!.length > 10 ? m.orderNumber!.substring(0, 8) : m.orderNumber}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        )
                        : Text(
                          m.notes != null && m.notes!.isNotEmpty
                              ? m.notes!
                              : '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
              ),

              // 4. Medio / Cuenta
              Expanded(
                flex: 2,
                child: Text(
                  m.orderPaymentMethod ?? m.paymentMethod ?? 'Caja / General',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 5. Responsable
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        m.createdByName ?? 'Desconocido',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 6. Monto
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$sign S/ ${m.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: amountColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              // 7. Acciones
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child:
                      m.orderId != null
                          ? IconButton(
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 17,
                            ),
                            tooltip: 'Ver pedido asociado',
                            splashRadius: 16,
                            color: AppColors.textSecondary,
                            onPressed: () => widget.onOpenOrder(m.orderId!),
                          )
                          : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
