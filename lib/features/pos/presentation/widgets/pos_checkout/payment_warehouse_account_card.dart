// ─── PAYMENT & WAREHOUSE & ACCOUNT CARD ──────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

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
    // Cuenta actualmente seleccionada
    final selectedAcc =
        selectedAccountId != null
            ? accountsList.firstWhere(
              (a) => a['id'] == selectedAccountId,
              orElse: () => <String, dynamic>{},
            )
            : <String, dynamic>{};
    final selectedType = selectedAcc['type'] as String? ?? '';
    final isCajaSelected = !isCredito && selectedType == 'CAJA';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Método de pago / cuenta ─────────────────────────────────
          const Text(
            'Método de pago',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // ── Chips de cuentas financieras (CAJA primero) ───────
                ...(List<Map<String, dynamic>>.from(accountsList)..sort((a, b) {
                  const order = ['CAJA', 'DIGITAL', 'BANCO', 'OTRO'];
                  final ai = order.indexOf(a['type'] as String? ?? 'OTRO');
                  final bi = order.indexOf(b['type'] as String? ?? 'OTRO');
                  return ai.compareTo(bi);
                })).map((acc) {
                  final type = acc['type'] as String? ?? 'OTRO';
                  final chipColor =
                      _typeColors[type] ?? AppColors.textSecondary;
                  final chipIcon = _typeIcons[type] ?? Icons.wallet_rounded;
                  final isSelected =
                      !isCredito && acc['id'] == selectedAccountId;
                  final balance = (acc['balance'] as num?)?.toStringAsFixed(0) ?? '0';

                  return GestureDetector(
                    onTap: () => onAccountChanged(acc['id'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? chipColor.withValues(alpha: 0.12)
                                : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? chipColor : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            chipIcon,
                            size: 14,
                            color: isSelected ? chipColor : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc['name'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isSelected
                                          ? chipColor
                                          : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'S/ $balance',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      isSelected
                                          ? chipColor.withValues(alpha: 0.75)
                                          : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          // Dot de turno (solo CAJA seleccionada)
                          if (type == 'CAJA' && isSelected) ...[
                            const SizedBox(width: 6),
                            Icon(
                              activeShift != null
                                  ? Icons.circle
                                  : Icons.warning_rounded,
                              size: activeShift != null ? 7 : 13,
                              color:
                                  activeShift != null
                                      ? AppColors.success
                                      : AppColors.danger,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

                // ── Separador visual antes de CRÉDITO ─────────────────
                if (accountsList.isNotEmpty)
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    color: AppColors.border,
                  ),

                // ── Chip CRÉDITO (siempre al final) ───────────────────
                GestureDetector(
                  onTap: () => onCreditoToggle(!isCredito),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color:
                          isCredito
                              ? Colors.deepOrange.withValues(alpha: 0.12)
                              : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCredito ? Colors.deepOrange : AppColors.border,
                        width: isCredito ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.handshake_rounded,
                          size: 14,
                          color:
                              isCredito
                                  ? Colors.deepOrange
                                  : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'CRÉDITO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                isCredito
                                    ? Colors.deepOrange
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Aviso turno de caja (inline, debajo de chips) ──────────
          if (isCajaSelected) ...[
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color:
                    activeShift != null
                        ? AppColors.successLight
                        : AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      activeShift != null
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    activeShift != null
                        ? Icons.check_circle_rounded
                        : Icons.lock_rounded,
                    size: 13,
                    color:
                        activeShift != null
                            ? AppColors.success
                            : AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    activeShift != null
                        ? 'Turno de caja abierto ✓'
                        : 'Caja sin turno abierto — no se puede cobrar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          activeShift != null
                              ? AppColors.success
                              : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Almacén ────────────────────────────────────────────────────
          if (warehouseList.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 14),
            const Text(
              'Almacén de origen',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedWarehouseId,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                  items:
                      warehouseList.map((w) {
                        return DropdownMenuItem<String>(
                          value: w.id,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warehouse_rounded,
                                size: 16,
                                color: AppColors.teal,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                w.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged: onWarehouseChanged,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
