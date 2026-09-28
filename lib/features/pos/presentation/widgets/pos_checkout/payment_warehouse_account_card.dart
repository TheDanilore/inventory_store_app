// ─── PAYMENT & WAREHOUSE & ACCOUNT CARD ──────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';

class PaymentWarehouseAccountCard extends StatelessWidget {
  final String paymentMethod;
  final List<WarehouseModel> warehouseList;
  final String? selectedWarehouseId;
  final List<Map<String, dynamic>> accountsList;
  final String? selectedAccountId;
  final CashShiftEntity? activeShift;
  final bool isCredito;
  final ValueChanged<String?> onWarehouseChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<bool> onCreditoToggle;

  static const Map<String, IconData> _typeIcons = {
    'CAJA': Icons.payments_rounded,
    'BANCO': Icons.account_balance_rounded,
    'DIGITAL': Icons.smartphone_rounded,
    'OTRO': Icons.wallet_rounded,
  };

  static const Map<String, Color> _typeColors = {
    'CAJA': AppColors.teal,
    'BANCO': Colors.indigo,
    'DIGITAL': Colors.purple,
    'OTRO': AppColors.textSecondary,
  };

  const PaymentWarehouseAccountCard({
    super.key,
    required this.paymentMethod,
    required this.warehouseList,
    required this.selectedWarehouseId,
    required this.accountsList,
    required this.selectedAccountId,
    required this.activeShift,
    required this.isCredito,
    required this.onWarehouseChanged,
    required this.onAccountChanged,
    required this.onCreditoToggle,
  });

  @override
  Widget build(BuildContext context) {
    final selectedAcc =
        selectedAccountId != null
            ? accountsList.firstWhere(
              (a) => a['id'] == selectedAccountId,
              orElse: () => <String, dynamic>{},
            )
            : <String, dynamic>{};
    final selectedType = selectedAcc['type'] as String? ?? '';
    final isCajaSelected = !isCredito && selectedType == 'CAJA';

    final sortedAccounts = List<Map<String, dynamic>>.from(accountsList)..sort((a, b) {
      const order = ['CAJA', 'DIGITAL', 'BANCO', 'OTRO'];
      final ai = order.indexOf(a['type'] as String? ?? 'OTRO');
      final bi = order.indexOf(b['type'] as String? ?? 'OTRO');
      return ai.compareTo(bi);
    });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título de Sección ─────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              const Text(
                'MÉTODO DE PAGO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (selectedAcc.isNotEmpty)
                Text(
                  isCredito ? 'Crédito' : (selectedAcc['name'] as String? ?? ''),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCredito ? Colors.deepOrange : AppColors.teal,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Grilla 2x2 estructurada (Zero Horizontal Scroll / Sin textos cortados) ──
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 8) / 2;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...sortedAccounts.map((acc) {
                    final type = acc['type'] as String? ?? 'OTRO';
                    final chipColor = _typeColors[type] ?? AppColors.textSecondary;
                    final chipIcon = _typeIcons[type] ?? Icons.wallet_rounded;
                    final isSelected = !isCredito && acc['id'] == selectedAccountId;
                    final balance = (acc['balance'] as num?)?.toStringAsFixed(0) ?? '0';
                    final isCashRegister = PosCalculatorUtils.accountRequiresShift(acc);

                    return SizedBox(
                      width: itemWidth,
                      height: 48,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onAccountChanged(acc['id'] as String),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? chipColor.withValues(alpha: 0.1)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? chipColor : AppColors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? chipColor.withValues(alpha: 0.15)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    chipIcon,
                                    size: 15,
                                    color: isSelected ? chipColor : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        acc['name'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? chipColor
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'S/ $balance',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? chipColor.withValues(alpha: 0.85)
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCashRegister) ...[
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: activeShift != null
                                        ? 'Turno abierto'
                                        : 'Turno de caja cerrado',
                                    child: Icon(
                                      activeShift != null
                                          ? Icons.check_circle_rounded
                                          : Icons.lock_clock_rounded,
                                      size: 14,
                                      color: activeShift != null
                                          ? AppColors.success
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // ── Tarjeta de CRÉDITO integrada en la grilla ────────────────
                  SizedBox(
                    width: itemWidth,
                    height: 48,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onCreditoToggle(!isCredito),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCredito
                                ? Colors.deepOrange.withValues(alpha: 0.1)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCredito ? Colors.deepOrange : AppColors.border,
                              width: isCredito ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isCredito
                                      ? Colors.deepOrange.withValues(alpha: 0.15)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.handshake_rounded,
                                  size: 15,
                                  color: isCredito
                                      ? Colors.deepOrange
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CRÉDITO',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isCredito
                                            ? Colors.deepOrange
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'A cuenta',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isCredito
                                            ? Colors.deepOrange.withValues(alpha: 0.85)
                                            : AppColors.textSecondary,
                                      ),
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
                ],
              );
            },
          ),

          // ── Banner contextual de Turno (Solo cuando se elige Efectivo sin Turno Abierto) ──
          if (isCajaSelected && activeShift == null) ...[
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.lock_clock_rounded,
                    size: 15,
                    color: Color(0xFFB45309),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Turno cerrado en caja física. Abre turno o cobra con Yape/BCP/Crédito.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
