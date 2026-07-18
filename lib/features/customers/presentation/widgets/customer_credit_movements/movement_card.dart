import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class MovementCard extends StatefulWidget {
  final CreditMovementEntity movement;
  final Function(String orderId) onOpenOrder;

  const MovementCard({
    super.key,
    required this.movement,
    required this.onOpenOrder,
  });

  @override
  State<MovementCard> createState() => _MovementCardState();
}

class _MovementCardState extends State<MovementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final movement = widget.movement;
    final isCharge = movement.movementType == 'CHARGE';
    final color = isCharge ? Colors.orange.shade700 : Colors.green.shade700;
    final bgColor = isCharge ? Colors.orange.shade50 : Colors.green.shade50;
    final icon =
        isCharge ? Icons.shopping_cart_rounded : Icons.payments_rounded;
    final sign = isCharge ? '+' : '-';

    // Formato AM/PM
    final timeStr =
        movement.createdAt != null
            ? DateFormat.jm().format(movement.createdAt!.toLocal())
            : '--:--';

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: EdgeInsets.zero,
      child: Semantics(
        label:
            '${isCharge ? "Cargo por venta" : "Pago registrado"} de S/ ${movement.amount.toStringAsFixed(2)} '
            '${movement.orderNumber != null ? "en el pedido ${movement.orderNumber!}" : ""} '
            'a las $timeStr. Toca para ${_expanded ? "ocultar" : "ver"} detalles.',
        button: true,
        child: InkWell(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),

                // Info central
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCharge ? 'Cargo por venta' : 'Pago registrado',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 4),

                      if (isCharge && movement.orderTotalAmount != null)
                        Text(
                          'Venta: S/ ${movement.orderTotalAmount!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),

                      if (movement.orderNumber != null)
                        Text(
                          'Pedido #${_expanded ? movement.orderNumber : movement.orderNumber!.substring(0, 8)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),

                      if (!isCharge && movement.orderPaymentMethod != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _MethodChip(
                            method: movement.orderPaymentMethod!,
                          ),
                        ),

                      AnimatedCrossFade(
                        firstChild: _buildNotes(
                          movement.notes,
                          expanded: false,
                        ),
                        secondChild: _buildNotes(
                          movement.notes,
                          expanded: true,
                        ),
                        crossFadeState:
                            _expanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 250),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              movement.createdByName ?? 'Desconocido',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Acción sugerida al expandir (opcional)
                      if (_expanded && movement.orderId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton(
                            onPressed:
                                () => widget.onOpenOrder(movement.orderId!),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: AppColors.primary,
                            ),
                            child: const Text(
                              'Ver pedido',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Monto y hora (ahora monto es más jerárquico)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$sign S/ ${movement.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotes(String? notes, {required bool expanded}) {
    if (notes == null || notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        notes,
        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        maxLines: expanded ? null : 2,
        overflow: expanded ? null : TextOverflow.ellipsis,
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String method;
  const _MethodChip({required this.method});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    if (method.toUpperCase() == 'YAPE' || method.toUpperCase() == 'PLIN') {
      chipColor = Colors.purple.shade700;
    } else if (method.toUpperCase().contains('TARJETA')) {
      chipColor = Colors.blue.shade700;
    } else if (method.toUpperCase().contains('EFECTIVO')) {
      chipColor = Colors.green.shade700;
    } else {
      chipColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 11,
          color: chipColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
