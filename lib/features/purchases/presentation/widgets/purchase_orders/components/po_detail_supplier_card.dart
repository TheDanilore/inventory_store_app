import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/financial_summary_card.dart';

/// Tarjeta de datos de proveedor, método de pago y balance financiero de la orden.
class PODetailSupplierCard extends StatelessWidget {
  final String supplierName;
  final String documentType;
  final String? documentNumber;
  final String paymentMethod;
  final bool canEditPaymentMethod;
  final VoidCallback onEditPaymentMethod;
  final DateTime createdAt;
  final double totalAmount;
  final double amountPaid;
  final String status;
  final double pending;
  final bool isProcessingAction;
  final VoidCallback onShowPaymentDialog;

  const PODetailSupplierCard({
    super.key,
    required this.supplierName,
    required this.documentType,
    this.documentNumber,
    required this.paymentMethod,
    required this.canEditPaymentMethod,
    required this.onEditPaymentMethod,
    required this.createdAt,
    required this.totalAmount,
    required this.amountPaid,
    required this.status,
    required this.pending,
    required this.isProcessingAction,
    required this.onShowPaymentDialog,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label PROVEEDOR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PROVEEDOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Doc: ${documentType.isNotEmpty ? documentType : "N/A"}${documentNumber != null && documentNumber!.isNotEmpty ? " • $documentNumber" : ""}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            supplierName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),

          const Divider(height: 24, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MÉTODO DE PAGO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        paymentMethod,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (canEditPaymentMethod) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: isProcessingAction ? null : onEditPaymentMethod,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'FECHA EMISIÓN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'dd/MM/yyyy HH:mm',
                      'es',
                    ).format(createdAt.toLocal()),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Card financiera con desglose ──
          FinancialSummaryCard(
            columns: [
              FinancialColumn(
                label: 'TOTAL',
                amount: totalAmount,
                amountColor:
                    status == 'CANCELLED'
                        ? AppColors.textMuted
                        : AppColors.primary,
              ),
              FinancialColumn(
                label: 'PAGADO',
                amount: amountPaid,
                amountColor: AppColors.success,
              ),
              FinancialColumn(
                label: 'DEUDA',
                amount: status == 'CANCELLED' ? 0.0 : pending,
                amountColor:
                    (status != 'CANCELLED' && pending > 0)
                        ? AppColors.danger
                        : AppColors.textSecondary,
                alignment: CrossAxisAlignment.end,
              ),
            ],
          ),
          if (status != 'CANCELLED' && pending > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.payments_rounded,
                  size: 18,
                  color: AppColors.success,
                ),
                label: Text(
                  'Registrar Pago / Abono (S/ ${pending.toStringAsFixed(2)})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.success,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isProcessingAction ? null : onShowPaymentDialog,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

