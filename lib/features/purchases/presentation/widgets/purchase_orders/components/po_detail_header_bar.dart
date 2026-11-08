import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/detail_sheet_header.dart';

/// Barra de cabecera modular para el detalle de la orden de compra.
class PODetailHeaderBar extends StatelessWidget {
  final String shortCode;
  final String fullId;
  final String status;
  final bool isDialog;
  final bool isProcessing;
  final VoidCallback onExport;
  final VoidCallback onClose;

  const PODetailHeaderBar({
    super.key,
    required this.shortCode,
    required this.fullId,
    required this.status,
    required this.isDialog,
    required this.isProcessing,
    required this.onExport,
    required this.onClose,
  });

  static Color statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.warning;
      case 'SENT':
        return Colors.blue.shade400;
      case 'PARTIAL':
        return Colors.orange.shade400;
      case 'RECEIVED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pendiente';
      case 'SENT':
        return 'Enviado';
      case 'PARTIAL':
        return 'Parcial';
      case 'RECEIVED':
        return 'Recibido';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration:
          isDialog
              ? const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              )
              : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Copiar ID completo ($fullId)',
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: fullId));
                    AppSnackbar.show(
                      context,
                      message: 'ID de orden copiado: $fullId',
                      type: SnackbarType.info,
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shortCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: statusLabel(status),
                color: statusColor(status),
              ),
              const Spacer(),
              if (isNarrow) ...[
                IconButton(
                  onPressed: isProcessing ? null : onExport,
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Exportar / Imprimir Orden',
                  visualDensity: VisualDensity.compact,
                ),
              ] else ...[
                Tooltip(
                  message: 'Comprobar, imprimir o exportar orden',
                  child: OutlinedButton.icon(
                    onPressed: isProcessing ? null : onExport,
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Exportar / Imprimir',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
              if (isDialog) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'ESC',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Cerrar detalle (Esc)',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

