import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';

class OrderDetailFiscalCard extends StatelessWidget {
  final OrderEntity order;

  const OrderDetailFiscalCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final docType = order.documentType;
    final hasNumber =
        order.documentNumber != null && order.documentNumber!.trim().isNotEmpty;
    if (docType == 'NINGUNO' && !hasNumber) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String docTitle;
    final Color badgeColor;
    final Color badgeTextColor;
    final Color badgeBorderColor;

    switch (docType.toUpperCase()) {
      case 'FACTURA':
        docTitle = 'Factura Electrónica';
        badgeColor =
            isDark
                ? const Color(0xFF4C1D95).withValues(alpha: 0.35)
                : const Color(0xFFF3E8FF);
        badgeTextColor =
            isDark ? const Color(0xFFA78BFA) : const Color(0xFF7E22CE);
        badgeBorderColor =
            isDark
                ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                : const Color(0xFFD8B4FE);
        break;
      case 'BOLETA':
        docTitle = 'Boleta de Venta';
        badgeColor =
            isDark
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                : const Color(0xFFEFF6FF);
        badgeTextColor =
            isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
        badgeBorderColor =
            isDark
                ? const Color(0xFF2563EB).withValues(alpha: 0.5)
                : const Color(0xFFBFDBFE);
        break;
      case 'NOTA_VENTA':
        docTitle = 'Nota de Venta';
        badgeColor =
            isDark
                ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                : const Color(0xFFECFDF5);
        badgeTextColor =
            isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
        badgeBorderColor =
            isDark
                ? const Color(0xFF059669).withValues(alpha: 0.5)
                : const Color(0xFFA7F3D0);
        break;
      default:
        docTitle = 'Comprobante';
        badgeColor =
            isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9);
        badgeTextColor =
            isDark ? AppColors.darkTextPrimary : const Color(0xFF334155);
        badgeBorderColor =
            isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1);
    }

    final docNum = order.documentNumber ?? order.displayReceiptNumber;
    final date = order.documentDate ?? order.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow:
            isDark
                ? const []
                : const [
                  BoxShadow(
                    color: Color(0x040F172A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_rounded,
                      size: 12.5,
                      color: badgeTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      docTitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: badgeTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: docNum));
                  AppSnackbar.show(
                    context,
                    message: 'Comprobante $docNum copiado',
                    type: SnackbarType.info,
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        docNum,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          color:
                              isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.copy_rounded,
                        size: 10,
                        color:
                            isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (date != null)
                Text(
                  DateFormat('dd/MM/yyyy', 'es').format(date.toLocal()),
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (order.customerDocumentNumber != null &&
              order.customerDocumentNumber!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${order.customerDocumentType ?? "DOC"}: ${order.customerDocumentNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                  ),
                ),
                if (order.customerAddress != null &&
                    order.customerAddress!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '·',
                    style: TextStyle(
                      color:
                          isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerAddress!,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (order.paymentReference != null &&
              order.paymentReference!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.tag_rounded,
                  size: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Nº Operación / Voucher: ${order.paymentReference!.trim()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: order.paymentReference!.trim()),
                    );
                    AppSnackbar.show(
                      context,
                      message:
                          'Nº Operación ${order.paymentReference!.trim()} copiado',
                      type: SnackbarType.info,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
