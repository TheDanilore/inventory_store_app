import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class AdminOrderCard extends StatelessWidget {
  final OrderEntity order;
  final bool isProcessing;
  final bool isGeneratingPDF;
  final bool isSelected;
  final bool isLoyaltyEnabled;
  final VoidCallback onTap;
  final Function(OrderEntity, String) onUpdateStatus;
  final VoidCallback onPrint;

  const AdminOrderCard({
    super.key,
    required this.order,
    required this.isProcessing,
    this.isGeneratingPDF = false,
    this.isSelected = false,
    required this.isLoyaltyEnabled,
    required this.onTap,
    required this.onUpdateStatus,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final date = (order.createdAt ?? DateTime.now()).toLocal();
    final dateString = DateFormat('dd MMM yyyy, hh:mm a', 'es').format(date);
    final customerName = order.displayCustomerName;
    final shortId = order.id.substring(0, 8).toUpperCase();

    final isCredit = order.paymentMethod == 'CRÉDITO';

    // Calcular estado de pago dinámico
    String paymentStatus = order.paymentStatus;
    double amountPaid = order.amountPaid;
    if (status == 'COMPLETED' && !isCredit) {
      paymentStatus = 'PAID';
      amountPaid = order.totalAmount;
    }

    final totalAmount = order.totalAmount;
    final pendingAmount = totalAmount - amountPaid;
    final warehouseName = order.warehouseName;

    // Chip de puntos pendientes (crédito completado con puntos a ganar)
    final showPendingPointsChip =
        isLoyaltyEnabled &&
        status == 'COMPLETED' &&
        isCredit &&
        paymentStatus != 'PAID' &&
        order.pointsEarned > 0;

    return MouseRegion(
      cursor:
          isProcessing ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAFCFF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : AppColors.cardShadow(opacity: 0.03),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: isProcessing ? null : onTap,
              child: Stack(
                children: [
                  if (isSelected)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(15),
                            bottomLeft: Radius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isSelected ? 18 : 16,
                      14,
                      16,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Indicador de procesamiento ────────────────────────────
                        if (isProcessing)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: LinearProgressIndicator(
                              color: AppColors.teal,
                              minHeight: 2,
                            ),
                          ),

                        // ── Fila 1: Info Cliente e ID ─────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ID del pedido
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.tag_rounded,
                                          size: 11,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          shortId,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textSecondary,
                                            fontFamily: 'monospace',
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 7),

                                  // Cliente
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: AppColors.teal.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          size: 14,
                                          color: AppColors.teal,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          customerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                            color: AppColors.textPrimary,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Fecha
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 13,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateString,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Método de pago
                                  Row(
                                    children: [
                                      Icon(
                                        isCredit
                                            ? Icons.credit_card_rounded
                                            : Icons.payments_outlined,
                                        size: 13,
                                        color:
                                            isCredit
                                                ? Colors.deepOrange.shade400
                                                : AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        order.paymentMethod,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color:
                                              isCredit
                                                  ? Colors.deepOrange.shade600
                                                  : AppColors.textSecondary,
                                          fontWeight:
                                              isCredit
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (warehouseName != null &&
                                      warehouseName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.warehouse_outlined,
                                          size: 13,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          warehouseName,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // Chip: puntos pendientes de otorgar
                                  if (showPendingPointsChip) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.amber.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '🪙',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${order.pointsEarned} monedas pendientes',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.amber.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Monto y Tags de Estado
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'S/ ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.teal,
                                        ),
                                      ),
                                      TextSpan(
                                        text: totalAmount.toStringAsFixed(2),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.3,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _StatusTag(status: status),
                                const SizedBox(height: 6),
                                _PaymentStatusTag(paymentStatus: paymentStatus),
                              ],
                            ),
                          ],
                        ),

                        // ── Progreso de pagos (Si es parcial o crédito) ───────────
                        if (status == 'COMPLETED' && isCredit) ...[
                          const SizedBox(height: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Pagado: S/ ${amountPaid.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  Text(
                                    'Resta: S/ ${pendingAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          pendingAmount > 0
                                              ? AppColors.error
                                              : AppColors.success,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value:
                                      totalAmount > 0
                                          ? (amountPaid / totalAmount).clamp(
                                            0.0,
                                            1.0,
                                          )
                                          : 0,
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    pendingAmount <= 0
                                        ? AppColors.success
                                        : AppColors.teal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(
                          height: 10,
                        ), // ── Botones de Acción Rápida ──────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Imprimir Ticket (con animación si está generando)
                            _AnimatedSoftButton(
                              onPressed:
                                  isProcessing || isGeneratingPDF
                                      ? null
                                      : onPrint,
                              icon: const Icon(Icons.print_rounded),
                              label: 'Ticket',
                              color: Colors.blueGrey.shade700,
                              isLoading: isGeneratingPDF,
                            ),
                            const SizedBox(width: 8),

                            if (status == 'PENDING') ...[
                              // Botón Cancelar Borrador
                              _AnimatedSoftButton(
                                onPressed:
                                    isProcessing
                                        ? null
                                        : () =>
                                            onUpdateStatus(order, 'CANCELLED'),
                                icon: const Icon(Icons.cancel_outlined),
                                label: 'Cancelar',
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),

                              // Botón Completar
                              _AnimatedSoftButton(
                                onPressed:
                                    isProcessing
                                        ? null
                                        : () =>
                                            onUpdateStatus(order, 'COMPLETED'),
                                icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                ),
                                label: 'Cobrar',
                                color: Colors.green.shade700,
                              ),
                            ],
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

// ─── Helpers: Etiquetas de estado ──────────────────────────────────────────

class _StatusTag extends StatelessWidget {
  final String status;
  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'COMPLETED':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = 'COMPLETADO';
        icon = Icons.check_circle_rounded;
        break;
      case 'PENDING':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        label = 'BORRADOR';
        icon = Icons.edit_note_rounded;
        break;
      case 'CANCELLED':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = 'CANCELADO';
        icon = Icons.cancel_rounded;
        break;
      case 'RETURNED':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        label = 'DEVUELTO';
        icon = Icons.rotate_left_rounded;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusTag extends StatelessWidget {
  final String paymentStatus;
  const _PaymentStatusTag({required this.paymentStatus});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (paymentStatus) {
      case 'PAID':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = 'PAGADO';
        icon = Icons.done_all_rounded;
        break;
      case 'PARTIAL':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        label = 'PARCIAL';
        icon = Icons.donut_large_rounded;
        break;
      case 'PENDING':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        label = 'POR COBRAR';
        icon = Icons.hourglass_empty_rounded;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = paymentStatus;
        icon = Icons.payments_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers: Botón Animado Tinted ──────────────────────────────────────────

class _AnimatedSoftButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color color;
  final bool isLoading;

  const _AnimatedSoftButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    this.isLoading = false,
  });

  @override
  State<_AnimatedSoftButton> createState() => _AnimatedSoftButtonState();
}

class _AnimatedSoftButtonState extends State<_AnimatedSoftButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => _controller.forward(),
        onTapUp:
            isDisabled
                ? null
                : (_) {
                  _controller.reverse();
                  widget.onPressed!();
                },
        onTapCancel: isDisabled ? null : () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isDisabled
                      ? Colors.grey.shade100
                      : widget.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.color,
                    ),
                  )
                else
                  IconTheme(
                    data: IconThemeData(
                      size: 18,
                      color: isDisabled ? Colors.grey.shade400 : widget.color,
                    ),
                    child: widget.icon,
                  ),
                const SizedBox(width: 6),
                Text(
                  widget.isLoading ? 'Procesando...' : widget.label,
                  style: TextStyle(
                    color: isDisabled ? Colors.grey.shade500 : widget.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
