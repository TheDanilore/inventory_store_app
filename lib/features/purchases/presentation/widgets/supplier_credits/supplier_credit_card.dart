import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class SupplierCreditCard extends StatefulWidget {
  final SupplierCreditEntity account;
  final VoidCallback onTap;
  final VoidCallback? onPay;
  final VoidCallback? onViewHistory;

  const SupplierCreditCard({
    super.key,
    required this.account,
    required this.onTap,
    this.onPay,
    this.onViewHistory,
  });

  @override
  State<SupplierCreditCard> createState() => _SupplierCreditCardState();
}

class _SupplierCreditCardState extends State<SupplierCreditCard> {
  bool _isHovered = false;

  Color _getDebtColor(double pct, bool isMaxedOut, double debt) {
    if (debt <= 0) return AppColors.textMuted;
    if (isMaxedOut || pct >= 0.90) return AppColors.danger;
    if (pct >= 0.75) return AppColors.warning;
    return AppColors.textPrimary;
  }

  Color _getProgressBarColor(double pct, bool isMaxedOut) {
    if (isMaxedOut || pct >= 0.90) return AppColors.danger;
    if (pct >= 0.75) return AppColors.warning;
    return AppColors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final pct = account.usagePercent.clamp(0.0, 1.0);
    final barColor = _getProgressBarColor(pct, account.isMaxedOut);
    final debtColor = _getDebtColor(pct, account.isMaxedOut, account.currentDebt);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: account.isMaxedOut
                ? AppColors.danger.withValues(alpha: 0.5)
                : (_isHovered
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.border),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.03),
              blurRadius: _isHovered ? 14 : 8,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Encabezado de Proveedor ---
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: account.isActive
                                  ? AppColors.tealLight
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              account.supplierName.isNotEmpty
                                  ? account.supplierName.substring(0, 1).toUpperCase()
                                  : 'P',
                              style: TextStyle(
                                color: account.isActive
                                    ? AppColors.tealDark
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: account.isActive
                                    ? AppColors.success
                                    : Colors.grey.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.supplierName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (account.supplierTaxId != null &&
                                    account.supplierTaxId!.isNotEmpty) ...[
                                  Text(
                                    'RUC ${account.supplierTaxId}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: account.isActive
                                        ? AppColors.successLight
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    account.isActive ? 'Activo' : 'Suspendido',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: account.isActive
                                          ? AppColors.successDark
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                        tooltip: 'Opciones de cuenta',
                        onPressed: widget.onTap,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // --- Métricas Financieras ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Por pagar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'S/ ${account.currentDebt.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: debtColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Disponible: ',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'S/ ${account.availableCredit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: account.isActive
                                      ? AppColors.tealDark
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Límite: S/ ${account.creditLimit.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // --- Barra de Progreso de Crédito ---
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // --- Barra de Acciones Rápidas ---
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onPay ?? widget.onTap,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.tealLight.withValues(alpha: 0.5),
                            foregroundColor: AppColors.tealDark,
                            side: BorderSide(
                              color: AppColors.teal.withValues(alpha: 0.25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: const Text(
                            'Abonar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: widget.onViewHistory ?? widget.onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Historial',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
