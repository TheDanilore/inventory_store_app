import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/common/customer_avatar_large.dart';

/// Inspector Lateral Pro (Stripe / Linear Style) para visualización rápida del cliente
class CustomerSideSheetInspector extends StatelessWidget {
  final CustomerEntity customer;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onOpenFullDetail;
  final ValueChanged<String> onWhatsApp;
  final ValueChanged<String> onCall;
  final void Function(String text, String label) onCopy;

  const CustomerSideSheetInspector({
    super.key,
    required this.customer,
    required this.onClose,
    required this.onEdit,
    required this.onOpenFullDetail,
    required this.onWhatsApp,
    required this.onCall,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final isUnlimited = c.creditLimit <= 0;
    final availableCredit =
        isUnlimited
            ? double.infinity
            : (c.creditLimit - c.currentDebt).clamp(0.0, double.infinity);
    final creditUsageRatio =
        (!isUnlimited && c.creditLimit > 0)
            ? (c.currentDebt / c.creditLimit).clamp(0.0, 1.0)
            : 0.0;

    return DetailSheetFrame(
      title: 'Ficha Rápida del Cliente',
      leading: const Icon(
        Icons.info_outline_rounded,
        size: 20,
        color: AppColors.primary,
      ),
      onClose: onClose,
      bodyPadding: const EdgeInsets.all(20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Profile Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow(opacity: 0.02),
            ),
            child: Row(
              children: [
                CustomerAvatarLarge(customer: c),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.fullName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  c.isActive
                                      ? AppColors.successLight
                                      : AppColors.slateLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c.isActive ? 'Activo' : 'Inactivo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    c.isActive
                                        ? AppColors.successDark
                                        : AppColors.slate,
                              ),
                            ),
                          ),
                          if (c.currentDebt > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Con Saldo Deudor',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.danger,
                                ),
                              ),
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

          const SizedBox(height: 16),

          // Contact Details Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                InspectorDetailRow(
                  icon: Icons.badge_outlined,
                  label: c.documentType ?? 'Documento',
                  value: c.documentNumber ?? 'No registrado',
                  onCopy:
                      c.documentNumber != null
                          ? () => onCopy(c.documentNumber!, 'Documento')
                          : null,
                ),
                const Divider(height: 16, color: AppColors.divider),
                InspectorDetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Teléfono',
                  value: c.phone ?? 'No registrado',
                  onCopy:
                      c.phone != null
                          ? () => onCopy(c.phone!, 'Teléfono')
                          : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Financial Overview Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTADO DE CUENTA Y CRÉDITO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: BalanceMiniCard(
                        title: 'Deuda Actual',
                        value: 'S/ ${c.currentDebt.toStringAsFixed(2)}',
                        isAlert: c.currentDebt > 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BalanceMiniCard(
                        title: 'Límite Crédito',
                        value:
                            isUnlimited
                                ? 'Sin límite (∞)'
                                : 'S/ ${c.creditLimit.toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BalanceMiniCard(
                        title: 'Crédito Disponible',
                        value:
                            isUnlimited
                                ? 'Ilimitado'
                                : 'S/ ${availableCredit.toStringAsFixed(2)}',
                        isSuccess: isUnlimited || availableCredit > 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BalanceMiniCard(
                        title: 'Facturación Total',
                        value: 'S/ ${c.totalRevenue.toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                ),
                if (!isUnlimited && c.creditLimit > 0) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: creditUsageRatio,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        creditUsageRatio > 0.85
                            ? AppColors.danger
                            : (creditUsageRatio > 0.5
                                ? AppColors.warning
                                : AppColors.teal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(creditUsageRatio * 100).toStringAsFixed(0)}% del límite de crédito consumido',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Direct Contact Action Buttons
          if (c.phone != null && c.phone!.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                    ),
                    label: const Text('WhatsApp'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => onWhatsApp(c.phone!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phone_outlined, size: 16),
                    label: const Text('Llamar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => onCall(c.phone!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Action Buttons Full Detail & Edit
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar datos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Ficha completa'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onOpenFullDetail,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BalanceMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isAlert;
  final bool isSuccess;

  const BalanceMiniCard({
    super.key,
    required this.title,
    required this.value,
    this.isAlert = false,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valColor = AppColors.textPrimary;
    if (isAlert) valColor = AppColors.danger;
    if (isSuccess) valColor = AppColors.successDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              isAlert
                  ? AppColors.danger.withValues(alpha: 0.25)
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: valColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class InspectorDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const InspectorDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: 'Copiar',
            splashRadius: 16,
            color: AppColors.textSecondary,
            onPressed: onCopy,
          ),
      ],
    );
  }
}
