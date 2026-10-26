import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class OrderDetailHeaderRow extends StatelessWidget {
  final String orderId;
  final String? orderStatus;
  final String? documentType;
  final String? documentNumber;
  final bool isCompleted;
  final bool isEditing;
  final bool canToggleEdit;
  final VoidCallback onToggleEditing;
  final VoidCallback onShare;
  final VoidCallback? onClose;

  const OrderDetailHeaderRow({
    super.key,
    required this.orderId,
    this.orderStatus,
    this.documentType,
    this.documentNumber,
    required this.isCompleted,
    required this.isEditing,
    this.canToggleEdit = true,
    required this.onToggleEditing,
    required this.onShare,
    this.onClose,
  });

  void _copyOrderId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: orderId));
    AppSnackbar.show(
      context,
      message: 'ID de pedido copiado al portapapeles',
      type: SnackbarType.info,
    );
  }

  void _copyDocNumber(BuildContext context, String docNum) {
    Clipboard.setData(ClipboardData(text: docNum));
    AppSnackbar.show(
      context,
      message: 'Comprobante $docNum copiado al portapapeles',
      type: SnackbarType.info,
    );
  }

  String _formatDocType(String? type) {
    switch (type?.toUpperCase()) {
      case 'NOTA_VENTA':
        return 'Nota de Venta';
      case 'BOLETA':
        return 'Boleta';
      case 'FACTURA':
        return 'Factura';
      case 'TICKET':
        return 'Ticket';
      default:
        return 'Comprobante';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shortId =
        orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
    final bool hasDocNumber =
        documentNumber != null && documentNumber!.trim().isNotEmpty;
    final bool hasDocType =
        documentType != null &&
        documentType!.trim().isNotEmpty &&
        documentType!.toUpperCase() != 'NINGUNO';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detalle del Pedido',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _copyOrderId(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? AppColors.darkSurfaceElevated
                                  : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              size: 11,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ID: $shortId',
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(Copiar)',
                              style: TextStyle(
                                fontSize: 9.5,
                                color:
                                    isDark
                                        ? AppColors.teal
                                        : AppColors.tealDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasDocNumber || hasDocType) ...[
                    MouseRegion(
                      cursor:
                          hasDocNumber
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                      child: GestureDetector(
                        onTap:
                            hasDocNumber
                                ? () => _copyDocNumber(
                                  context,
                                  documentNumber!.trim(),
                                )
                                : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (documentType?.toUpperCase() == 'FACTURA')
                                    ? (isDark
                                        ? const Color(
                                          0xFF4C1D95,
                                        ).withValues(alpha: 0.35)
                                        : const Color(0xFFF3E8FF))
                                    : ((documentType?.toUpperCase() == 'BOLETA')
                                        ? (isDark
                                            ? const Color(
                                              0xFF1E3A8A,
                                            ).withValues(alpha: 0.35)
                                            : const Color(0xFFEFF6FF))
                                        : (isDark
                                            ? const Color(
                                              0xFF064E3B,
                                            ).withValues(alpha: 0.35)
                                            : const Color(0xFFECFDF5))),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  (documentType?.toUpperCase() == 'FACTURA')
                                      ? (isDark
                                          ? const Color(
                                            0xFF7C3AED,
                                          ).withValues(alpha: 0.5)
                                          : const Color(0xFFD8B4FE))
                                      : ((documentType?.toUpperCase() ==
                                              'BOLETA')
                                          ? (isDark
                                              ? const Color(
                                                0xFF2563EB,
                                              ).withValues(alpha: 0.5)
                                              : const Color(0xFFBFDBFE))
                                          : (isDark
                                              ? const Color(
                                                0xFF059669,
                                              ).withValues(alpha: 0.5)
                                              : const Color(0xFFA7F3D0))),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 11.5,
                                color:
                                    (documentType?.toUpperCase() == 'FACTURA')
                                        ? (isDark
                                            ? const Color(0xFFA78BFA)
                                            : const Color(0xFF7E22CE))
                                        : ((documentType?.toUpperCase() ==
                                                'BOLETA')
                                            ? (isDark
                                                ? const Color(0xFF60A5FA)
                                                : const Color(0xFF1D4ED8))
                                            : (isDark
                                                ? const Color(0xFF34D399)
                                                : const Color(0xFF047857))),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hasDocNumber
                                    ? documentNumber!.trim()
                                    : _formatDocType(documentType),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: hasDocNumber ? 'monospace' : null,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      (documentType?.toUpperCase() == 'FACTURA')
                                          ? (isDark
                                              ? const Color(0xFFA78BFA)
                                              : const Color(0xFF7E22CE))
                                          : ((documentType?.toUpperCase() ==
                                                  'BOLETA')
                                              ? (isDark
                                                  ? const Color(0xFF60A5FA)
                                                  : const Color(0xFF1D4ED8))
                                              : (isDark
                                                  ? const Color(0xFF34D399)
                                                  : const Color(0xFF047857))),
                                ),
                              ),
                              if (hasDocNumber) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${_formatDocType(documentType)})',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        (documentType?.toUpperCase() ==
                                                'FACTURA')
                                            ? (isDark
                                                ? const Color(0xFFA78BFA)
                                                : const Color(0xFF7E22CE))
                                            : ((documentType?.toUpperCase() ==
                                                    'BOLETA')
                                                ? (isDark
                                                    ? const Color(0xFF60A5FA)
                                                    : const Color(0xFF1D4ED8))
                                                : (isDark
                                                    ? const Color(0xFF34D399)
                                                    : const Color(0xFF047857))),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  _buildStatusBadge(orderStatus, isDark: isDark),
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Imprimir Ticket (Ctrl + P)',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: onShare,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurfaceElevated
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.print_rounded,
                          size: 15,
                          color:
                              isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ticket',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (canToggleEdit) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: isEditing ? 'Cancelar edición' : 'Editar pedido',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: onToggleEditing,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color:
                            isEditing
                                ? AppColors.error.withValues(alpha: 0.1)
                                : (isDark
                                    ? AppColors.darkSurfaceElevated
                                    : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              isEditing
                                  ? AppColors.error.withValues(alpha: 0.3)
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.border),
                        ),
                      ),
                      child: Icon(
                        isEditing ? Icons.close_rounded : Icons.edit_rounded,
                        size: 16,
                        color:
                            isEditing
                                ? AppColors.error
                                : (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (onClose != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppColors.darkSurfaceElevated
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  'ESC',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                ),
                tooltip: 'Cerrar detalle (Esc)',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String? status, {bool isDark = false}) {
    final rawStatus =
        status?.toUpperCase() ?? (isCompleted ? 'COMPLETED' : 'PENDING');
    final Color bg;
    final Color border;
    final Color text;
    final String label;
    final IconData icon;

    switch (rawStatus) {
      case 'COMPLETED':
        bg =
            isDark
                ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                : const Color(0xFFECFDF5);
        border =
            isDark
                ? const Color(0xFF059669).withValues(alpha: 0.5)
                : const Color(0xFFA7F3D0);
        text = isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
        label = 'COMPLETADO';
        icon = Icons.check_circle_rounded;
        break;
      case 'DRAFT':
      case 'PENDING':
        bg =
            isDark
                ? const Color(0xFF78350F).withValues(alpha: 0.35)
                : const Color(0xFFFFFBEB);
        border =
            isDark
                ? const Color(0xFFD97706).withValues(alpha: 0.5)
                : const Color(0xFFFDE68A);
        text = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        label = 'BORRADOR';
        icon = Icons.edit_note_rounded;
        break;
      case 'CANCELLED':
        bg =
            isDark
                ? const Color(0xFF881337).withValues(alpha: 0.35)
                : const Color(0xFFFEF2F2);
        border =
            isDark
                ? const Color(0xFFE11D48).withValues(alpha: 0.5)
                : const Color(0xFFFECACA);
        text = isDark ? const Color(0xFFFB7185) : const Color(0xFFDC2626);
        label = 'CANCELADO';
        icon = Icons.cancel_rounded;
        break;
      case 'RETURNED':
        bg =
            isDark
                ? const Color(0xFF4C1D95).withValues(alpha: 0.35)
                : const Color(0xFFF5F3FF);
        border =
            isDark
                ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                : const Color(0xFFDDD6FE);
        text = isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9);
        label = 'DEVUELTO';
        icon = Icons.rotate_left_rounded;
        break;
      default:
        bg = isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9);
        border = isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1);
        text = isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);
        label = rawStatus;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: text,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
