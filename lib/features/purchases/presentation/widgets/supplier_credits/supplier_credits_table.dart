import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class SupplierCreditsTable extends StatefulWidget {
  final List<SupplierCreditEntity> accounts;
  final Function(SupplierCreditEntity) onSelectAccount;
  final Function(SupplierCreditEntity) onPay;
  final Function(SupplierCreditEntity) onViewHistory;

  const SupplierCreditsTable({
    super.key,
    required this.accounts,
    required this.onSelectAccount,
    required this.onPay,
    required this.onViewHistory,
  });

  @override
  State<SupplierCreditsTable> createState() => _SupplierCreditsTableState();
}

class _SupplierCreditsTableState extends State<SupplierCreditsTable> {
  String? _hoveredId;

  Color _getDebtColor(double pct, bool isMaxedOut, double debt) {
    if (debt <= 0) return AppColors.textMuted;
    if (isMaxedOut || pct >= 0.90) return AppColors.danger;
    if (pct >= 0.75) return AppColors.warningDark;
    return AppColors.textPrimary;
  }

  Color _getProgressColor(double pct, bool isMaxedOut) {
    if (isMaxedOut || pct >= 0.90) return AppColors.danger;
    if (pct >= 0.75) return AppColors.warning;
    return AppColors.teal;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTableWidth = 960.0;
        final needsScroll = constraints.maxWidth < minTableWidth;

        final tableContent = SizedBox(
          width: needsScroll ? minTableWidth : constraints.maxWidth,
          child: Column(
            children: [
              // --- Encabezado Fijo de Tabla ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'PROVEEDOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 115,
                      child: Text(
                        'LÍNEA CRÉDITO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 115,
                      child: Text(
                        'DEUDA ACTUAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 115,
                      child: Text(
                        'DISPONIBLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text(
                        'USO DE LÍNEA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'ESTADO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text(
                        'ACCIONES',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Filas de Datos ---
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.accounts.length,
                separatorBuilder:
                    (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE2E8F0),
                    ),
                itemBuilder: (context, index) {
                  final account = widget.accounts[index];
                  final pct = account.usagePercent.clamp(0.0, 1.0);
                  final progressColor = _getProgressColor(pct, account.isMaxedOut);
                  final debtColor = _getDebtColor(pct, account.isMaxedOut, account.currentDebt);

                  final isHovered = _hoveredId == account.creditId;

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoveredId = account.creditId),
                    onExit: (_) => setState(() => _hoveredId = null),
                    child: InkWell(
                      onTap: () => widget.onSelectAccount(account),
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: isHovered ? const Color(0xFFF8FAFC) : Colors.white,
                          border: Border(
                            left: BorderSide(
                              color: isHovered ? AppColors.teal.withValues(alpha: 0.6) : Colors.transparent,
                              width: 3.5,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            // Proveedor (Avatar + Nombre + RUC)
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: account.isActive
                                          ? AppColors.tealLight
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
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
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.supplierName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        if (account.supplierTaxId != null &&
                                            account.supplierTaxId!.isNotEmpty)
                                          Text(
                                            'RUC ${account.supplierTaxId}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textMuted,
                                            ),
                                          )
                                        else
                                          const Text(
                                            '—',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Línea Total
                            SizedBox(
                              width: 115,
                              child: Text(
                                'S/ ${account.creditLimit.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),

                            // Deuda Actual
                            SizedBox(
                              width: 115,
                              child: account.currentDebt == 0
                                  ? Row(
                                      children: [
                                        const Text(
                                          'S/ 0.00',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textMuted,
                                            fontFeatures: [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: const Text(
                                            'Al día',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'S/ ${account.currentDebt.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: debtColor,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                            ),

                            // Disponible
                            SizedBox(
                              width: 115,
                              child: Text(
                                'S/ ${account.availableCredit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: account.isActive
                                      ? AppColors.tealDark
                                      : AppColors.textMuted,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),

                            // Uso de Línea (Barra + %)
                            SizedBox(
                              width: 130,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 6,
                                        backgroundColor: const Color(0xFFE2E8F0),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          progressColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 44,
                                    child: Text(
                                      '${(pct * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: progressColor,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Estado
                            SizedBox(
                              width: 100,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: account.isActive
                                        ? AppColors.successLight
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: account.isActive
                                          ? AppColors.success.withValues(alpha: 0.3)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: account.isActive
                                              ? AppColors.success
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        account.isActive ? 'Activo' : 'Suspendido',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: account.isActive
                                              ? AppColors.successDark
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Acciones (Botón Abonar Estilizado + Menú)
                            SizedBox(
                              width: 130,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Tooltip(
                                    message: 'Registrar abono a cuenta',
                                    child: OutlinedButton.icon(
                                      onPressed: () => widget.onPay(account),
                                      icon: const Icon(
                                        Icons.payments_outlined,
                                        size: 13,
                                      ),
                                      label: const Text(
                                        'Abonar',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.tealDark,
                                        side: BorderSide(
                                          color: AppColors.teal.withValues(alpha: 0.3),
                                        ),
                                        backgroundColor: AppColors.teal.withValues(alpha: 0.05),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 5,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    tooltip: 'Más opciones',
                                    offset: const Offset(0, 36),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    padding: EdgeInsets.zero,
                                    icon: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.more_vert_rounded,
                                        size: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    onSelected: (val) {
                                      if (val == 'pay') widget.onPay(account);
                                      if (val == 'history') widget.onViewHistory(account);
                                      if (val == 'manage') widget.onSelectAccount(account);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'pay',
                                        height: 36,
                                        child: Row(
                                          children: [
                                            Icon(Icons.payments_outlined, size: 15, color: AppColors.tealDark),
                                            SizedBox(width: 8),
                                            Text(
                                              'Registrar abono',
                                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'history',
                                        height: 36,
                                        child: Row(
                                          children: [
                                            Icon(Icons.history_rounded, size: 15, color: AppColors.textSecondary),
                                            SizedBox(width: 8),
                                            Text(
                                              'Ver movimientos',
                                              style: TextStyle(fontSize: 12.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'manage',
                                        height: 36,
                                        child: Row(
                                          children: [
                                            Icon(Icons.tune_rounded, size: 15, color: AppColors.textSecondary),
                                            SizedBox(width: 8),
                                            Text(
                                              'Ajustar línea / Opciones',
                                              style: TextStyle(fontSize: 12.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x050F172A),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: needsScroll
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: tableContent,
                )
              : tableContent,
        );
      },
    );
  }
}
