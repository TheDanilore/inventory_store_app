import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail/order_detail_state.dart';

class OrderDetailMetadataStrip extends StatelessWidget {
  final OrderDetailState state;
  final OrderEntity displayOrder;
  final String manualCustomerName;
  final VoidCallback onToggleEditing;

  const OrderDetailMetadataStrip({
    super.key,
    required this.state,
    required this.displayOrder,
    required this.manualCustomerName,
    required this.onToggleEditing,
  });

  String _getCustomerLabel(
    String? customerId,
    List<Map<String, dynamic>> profiles,
    OrderEntity? order,
  ) {
    if (customerId != null && customerId.isNotEmpty) {
      try {
        final profile = profiles.firstWhere((p) => p['id'] == customerId);
        final name = (profile['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) return name;
      } catch (e, st) {
        LoggerService.w(
          'Error parseando cliente',
          error: e,
          stackTrace: st,
          tag: 'OrderDetailMetadataStrip',
        );
      }
    }
    if (order != null &&
        order.displayCustomerName.isNotEmpty &&
        order.displayCustomerName != 'Cliente General') {
      return order.displayCustomerName;
    }
    final manual = manualCustomerName.trim();
    return manual.isNotEmpty ? manual : 'Cliente mostrador';
  }

  @override
  Widget build(BuildContext context) {
    final order = state.order ?? displayOrder;
    final effectiveCustomerId =
        (state.selectedCustomerId != null &&
                state.selectedCustomerId!.isNotEmpty)
            ? state.selectedCustomerId
            : ((order.customerId != null && order.customerId!.isNotEmpty)
                ? order.customerId
                : null);
    final isRegistered =
        effectiveCustomerId != null && effectiveCustomerId.isNotEmpty;
    final selectedCustomerLabel = _getCustomerLabel(
      effectiveCustomerId,
      state.profiles,
      order,
    );
    final cleanName =
        selectedCustomerLabel.trim().isNotEmpty
            ? selectedCustomerLabel.trim()
            : 'Cliente mostrador';
    final parts = cleanName.split(' ').where((p) => p.isNotEmpty).toList();
    final initials =
        parts.isNotEmpty
            ? parts.take(2).map((p) => p[0]).join().toUpperCase()
            : '?';
    final orderStatus = order.status.toUpperCase();
    final isCancelled = orderStatus == 'CANCELLED';
    final isReturned = orderStatus == 'RETURNED';
    final isDraft = orderStatus == 'PENDING' || orderStatus == 'DRAFT';
    final safePaymentMethod =
        state.paymentMethod.isNotEmpty ? state.paymentMethod : 'POR ACORDAR';
    final isPaid = order.paymentStatus.toUpperCase() == 'PAID';
    final pending = order.totalAmount - order.amountPaid;

    final Color paymentStatusDotColor;
    final String paymentStatusText;
    final Color paymentStatusTextColor;

    if (isCancelled) {
      paymentStatusDotColor = AppColors.danger;
      paymentStatusText = 'Anulado / Cancelado';
      paymentStatusTextColor = AppColors.danger;
    } else if (isReturned) {
      paymentStatusDotColor = const Color(0xFF6D28D9);
      paymentStatusText = 'Devuelto';
      paymentStatusTextColor = const Color(0xFF6D28D9);
    } else if (isDraft) {
      paymentStatusDotColor = AppColors.warningDark;
      paymentStatusText = 'Sin pago (Borrador)';
      paymentStatusTextColor = AppColors.warningDark;
    } else if (isPaid) {
      paymentStatusDotColor = AppColors.successDark;
      paymentStatusText = 'Pagado';
      paymentStatusTextColor = AppColors.successDark;
    } else {
      paymentStatusDotColor = AppColors.warningDark;
      paymentStatusText =
          pending > 0
              ? 'Por Cobrar: S/ ${pending.toStringAsFixed(2)}'
              : 'Pendiente';
      paymentStatusTextColor = AppColors.warningDark;
    }

    IconData paymentIcon;
    Color paymentColor;
    final upperMethod = safePaymentMethod.toUpperCase();
    if (state.accounts.any((a) => a['name'] == safePaymentMethod)) {
      final accType =
          state.accounts.firstWhere(
                (a) => a['name'] == safePaymentMethod,
                orElse: () => {'type': 'OTRO'},
              )['type']
              as String;
      switch (accType) {
        case 'CAJA':
          paymentIcon = Icons.point_of_sale_rounded;
          paymentColor = const Color(0xFFF59E0B);
          break;
        case 'BANCO':
          paymentIcon = Icons.account_balance_rounded;
          paymentColor = const Color(0xFF2563EB);
          break;
        case 'DIGITAL':
          paymentIcon = Icons.smartphone_rounded;
          paymentColor = const Color(0xFF7C3AED);
          break;
        default:
          paymentIcon = Icons.wallet_rounded;
          paymentColor = const Color(0xFF6B7280);
      }
    } else if (upperMethod.contains('YAPE') || upperMethod.contains('PLIN')) {
      paymentIcon = Icons.smartphone_rounded;
      paymentColor = const Color(0xFF7C3AED);
    } else if (upperMethod.contains('BCP') ||
        upperMethod.contains('BBVA') ||
        upperMethod.contains('INTERBANK') ||
        upperMethod.contains('BANCO') ||
        upperMethod.contains('TRANSFERENCIA')) {
      paymentIcon = Icons.account_balance_rounded;
      paymentColor = const Color(0xFF2563EB);
    } else if (upperMethod.contains('EFECTIVO') ||
        upperMethod.contains('CAJA')) {
      paymentIcon = Icons.point_of_sale_rounded;
      paymentColor = const Color(0xFFF59E0B);
    } else {
      paymentIcon =
          safePaymentMethod == 'CRÉDITO'
              ? Icons.handshake_rounded
              : Icons.payment_rounded;
      paymentColor =
          safePaymentMethod == 'CRÉDITO' ? AppColors.teal : AppColors.textMuted;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow:
            isDark
                ? const []
                : const [
                  BoxShadow(
                    color: Color(0x060F172A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
      ),
      child: Row(
        children: [
          // --- COLUMNA 1: CLIENTE ---
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap:
                    isRegistered
                        ? () {
                          AppFeedbackService.selectionClick();
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                          context.go(
                            '/customers/customer-detail/$effectiveCustomerId',
                          );
                        }
                        : null,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 2,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color:
                              isRegistered
                                  ? (isDark
                                      ? AppColors.teal.withValues(alpha: 0.18)
                                      : AppColors.teal.withValues(alpha: 0.12))
                                  : (isDark
                                      ? AppColors.darkSurfaceElevated
                                      : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              isRegistered
                                  ? Border.all(
                                    color: AppColors.teal.withValues(
                                      alpha: isDark ? 0.45 : 0.25,
                                    ),
                                    width: 1,
                                  )
                                  : (isDark
                                      ? Border.all(color: AppColors.darkBorder)
                                      : null),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              color:
                                  isRegistered
                                      ? (isDark
                                          ? AppColors.teal
                                          : AppColors.tealDark)
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    cleanName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color:
                                          isRegistered
                                              ? (isDark
                                                  ? AppColors.teal
                                                  : AppColors.tealDark)
                                              : (isDark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors.textPrimary),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isRegistered) ...[
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: 'Ver perfil del cliente',
                                    child: Icon(
                                      Icons.open_in_new_rounded,
                                      size: 12,
                                      color: (isDark
                                              ? AppColors.teal
                                              : AppColors.tealDark)
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (order.customerDocumentNumber != null &&
                                      order.customerDocumentNumber!.isNotEmpty)
                                  ? '${order.customerDocumentType ?? "DOC"}: ${order.customerDocumentNumber}'
                                  : (isRegistered
                                      ? 'Cliente registrado'
                                      : 'Cliente mostrador'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color:
                                    isRegistered
                                        ? (isDark
                                            ? AppColors.teal
                                            : AppColors.tealDark)
                                        : (isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.textMuted),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (order.warehouseName != null &&
                                order.warehouseName!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.storefront_outlined,
                                    size: 11,
                                    color:
                                        isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      order.warehouseName!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color:
                                            isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isRegistered)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Divisor vertical
          Container(
            width: 1,
            height: 32,
            color: isDark ? AppColors.darkBorder : AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),

          // --- COLUMNA 2: PAGO ---
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: paymentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(paymentIcon, size: 17, color: paymentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        safePaymentMethod,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color:
                              isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: paymentStatusDotColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              paymentStatusText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: paymentStatusTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (order.paymentReference != null &&
                          order.paymentReference!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: order.paymentReference!.trim(),
                              ),
                            );
                            AppSnackbar.show(
                              context,
                              message:
                                  'Nº Operación ${order.paymentReference!.trim()} copiado',
                              type: SnackbarType.info,
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? AppColors.darkSurfaceElevated
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color:
                                    isDark
                                        ? AppColors.darkBorder
                                        : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tag_rounded,
                                  size: 11,
                                  color:
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Nº Op: ${order.paymentReference!.trim()}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 9.5,
                                  color:
                                      isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- BOTÓN EDITAR SI ESTÁ PERMITIDO ---
          if (state.canToggleEdit) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.teal,
              ),
              tooltip: 'Editar datos del pedido',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.tealLight.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(30, 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: onToggleEditing,
            ),
          ],
        ],
      ),
    );
  }
}
