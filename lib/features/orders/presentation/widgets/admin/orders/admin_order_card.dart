import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_badges.dart';

/// Card de pedido para la vista de tarjetas.
///
/// Estructura fija (igual en todos los estados) para que la grilla se vea
/// ordenada y nada se corte:
///   1. ID + fecha ................... total
///   2. Cliente
///   3. Badges: estado + cobro
///   4. Meta (método · sucursal)  /  barra de progreso si es crédito
///   ── footer fijo abajo ──
///   5. [Ticket]  ............  Cancelar · Cobrar   |   Ver detalle ›
///
/// Funciona con altura acotada (grilla con mainAxisExtent) y con altura libre
/// (lista en móvil).
class AdminOrderCard extends StatefulWidget {
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
  State<AdminOrderCard> createState() => _AdminOrderCardState();
}

class _AdminOrderCardState extends State<AdminOrderCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isProcessing = widget.isProcessing;
    final isSelected = widget.isSelected;

    final status = order.status.toUpperCase();
    final isDraft = isDraftStatus(status);
    final payment = OrderPaymentInfo.from(order);
    final isCredit = isCreditPayment(order.paymentMethod);
    final paid = payment?.paid ?? 0.0;
    final remaining = payment?.remaining ?? 0.0;
    final total = order.totalAmount;

    final showCreditProgress =
        payment != null && isCredit && status == 'COMPLETED';
    final showPoints =
        widget.isLoyaltyEnabled &&
        showCreditProgress &&
        remaining > 0 &&
        order.pointsEarned > 0;

    final date = (order.createdAt ?? DateTime.now()).toLocal();
    final sameYear = date.year == DateTime.now().year;
    final dateString = DateFormat(
      sameYear ? 'dd MMM, hh:mm a' : 'dd MMM yyyy, hh:mm a',
      'es',
    ).format(date);

    final primaryText = isDark ? Colors.white : AppColors.textPrimary;
    final baseSurface = isDark ? AppColors.darkSurface : Colors.white;
    final surface =
        isSelected
            ? Color.alphaBlend(
              AppColors.teal.withValues(alpha: 0.05),
              baseSurface,
            )
            : baseSurface;
    final borderColor =
        isSelected
            ? AppColors.teal
            : _isHovered
            ? AppColors.teal.withValues(alpha: 0.35)
            : (isDark ? AppColors.darkBorder : AppColors.border);

    // Meta: método de pago · sucursal (una sola línea, nunca crece)
    final method = order.paymentMethod.trim();
    final hasMethod =
        method.isNotEmpty && method.toUpperCase() != 'POR ACORDAR';
    final warehouse = (order.warehouseName ?? '').trim();
    final ref = (order.paymentReference ?? '').trim();
    final metaParts = <String>[
      if (hasMethod) (isCredit ? 'Crédito' : method),
      if (ref.isNotEmpty) 'Op: $ref',
      if (warehouse.isNotEmpty) warehouse,
    ];

    return RepaintBoundary(
      child: MouseRegion(
        cursor:
            isProcessing ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            0,
            _isHovered && !isProcessing ? -2 : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: (isSelected || _isHovered) ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isSelected
                        ? AppColors.teal.withValues(alpha: 0.12)
                        : Colors.black.withValues(
                          alpha: _isHovered ? 0.07 : 0.03,
                        ),
                blurRadius: isSelected ? 18 : (_isHovered ? 14 : 8),
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isProcessing ? null : widget.onTap,
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final bounded = c.hasBoundedHeight;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize:
                                bounded ? MainAxisSize.max : MainAxisSize.min,
                            children: [
                              // 1. ID + fecha ................ total
                              Row(
                                children: [
                                  _IdChip(shortId: orderShortId(order.id)),
                                  if (order.documentNumber != null &&
                                      order.documentNumber!
                                          .trim()
                                          .isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (order.documentType.toUpperCase() ==
                                                    'FACTURA')
                                                ? const Color(0xFFF3E8FF)
                                                : ((order.documentType
                                                            .toUpperCase() ==
                                                        'BOLETA')
                                                    ? const Color(0xFFEFF6FF)
                                                    : const Color(0xFFECFDF5)),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color:
                                              (order.documentType
                                                          .toUpperCase() ==
                                                      'FACTURA')
                                                  ? const Color(0xFFD8B4FE)
                                                  : ((order.documentType
                                                              .toUpperCase() ==
                                                          'BOLETA')
                                                      ? const Color(0xFFBFDBFE)
                                                      : const Color(
                                                        0xFFA7F3D0,
                                                      )),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        order.documentNumber!.trim(),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w800,
                                          color:
                                              (order.documentType
                                                          .toUpperCase() ==
                                                      'FACTURA')
                                                  ? const Color(0xFF7E22CE)
                                                  : ((order.documentType
                                                              .toUpperCase() ==
                                                          'BOLETA')
                                                      ? const Color(0xFF1D4ED8)
                                                      : const Color(
                                                        0xFF047857,
                                                      )),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dateString,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'S/ ',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.teal,
                                          ),
                                        ),
                                        TextSpan(
                                          text: total.toStringAsFixed(2),
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                            color: primaryText,
                                            letterSpacing: -0.4,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 2. Cliente
                              Row(
                                children: [
                                  _CustomerAvatar(
                                    name: order.displayCustomerName,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order.displayCustomerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        color: primaryText,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // 3. Badges (estado + cobro)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  OrderStatusBadge(status: order.status),
                                  if (payment != null)
                                    OrderPaymentBadge(info: payment),
                                ],
                              ),

                              // 4. Meta
                              if (metaParts.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      isCredit
                                          ? Icons.credit_card_rounded
                                          : (hasMethod
                                              ? Icons.payments_outlined
                                              : Icons.storefront_outlined),
                                      size: 13,
                                      color:
                                          isCredit
                                              ? Colors.deepOrange.shade400
                                              : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        metaParts.join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight:
                                              isCredit
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                          color:
                                              isCredit
                                                  ? Colors.deepOrange.shade600
                                                  : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    if (showPoints)
                                      Tooltip(
                                        message:
                                            '${order.pointsEarned} monedas pendientes',
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            left: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.amber.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            '🪙 ${order.pointsEarned}',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.amber.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],

                              // Progreso de pago (crédito completado)
                              if (showCreditProgress) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Pagado: S/ ${paid.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Resta: S/ ${remaining.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            remaining > 0
                                                ? AppColors.error
                                                : AppColors.success,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value:
                                        total > 0
                                            ? (paid / total)
                                                .clamp(0.0, 1.0)
                                                .toDouble()
                                            : 0.0,
                                    minHeight: 5,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      remaining <= 0
                                          ? AppColors.success
                                          : AppColors.teal,
                                    ),
                                  ),
                                ),
                              ],

                              // Footer pegado abajo (grilla) o separado (lista)
                              if (bounded)
                                const Spacer()
                              else
                                const SizedBox(height: 12),

                              // 5. Acciones
                              Row(
                                children: [
                                  _TicketButton(
                                    isLoading: widget.isGeneratingPDF,
                                    onPressed:
                                        isProcessing || widget.isGeneratingPDF
                                            ? null
                                            : widget.onPrint,
                                  ),
                                  const Spacer(),
                                  if (isDraft) ...[
                                    TextButton.icon(
                                      onPressed:
                                          isProcessing
                                              ? null
                                              : () => widget.onUpdateStatus(
                                                order,
                                                'CANCELLED',
                                              ),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Cancelar'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red.shade700,
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    FilledButton.icon(
                                      onPressed:
                                          isProcessing
                                              ? null
                                              : () => widget.onUpdateStatus(
                                                order,
                                                'COMPLETED',
                                              ),
                                      icon: const Icon(
                                        Icons.payments_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Cobrar'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.teal,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Ver detalle',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: AppColors.textMuted,
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Barra lateral de selección
                    if (isSelected)
                      const Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 4,
                        child: ColoredBox(color: AppColors.teal),
                      ),

                    // Indicador de procesamiento (no cambia el layout)
                    if (isProcessing)
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: LinearProgressIndicator(
                          color: AppColors.teal,
                          minHeight: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Piezas ─────────────────────────────────────────────────────────────────

class _IdChip extends StatelessWidget {
  final String shortId;
  const _IdChip({required this.shortId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        '#$shortId',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
          fontFamily: 'monospace',
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final String name;
  const _CustomerAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppColors.teal,
        ),
      ),
    );
  }
}

class _TicketButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  const _TicketButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Imprimir ticket',
      onPressed: onPressed,
      icon:
          isLoading
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.print_rounded, size: 18),
      style: IconButton.styleFrom(
        foregroundColor: const Color(0xFF475569),
        backgroundColor: const Color(0xFFF1F5F9),
        minimumSize: const Size(36, 36),
        fixedSize: const Size(36, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
