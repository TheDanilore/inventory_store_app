import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_section_card.dart';

class OrderDetailPaymentSection extends StatelessWidget {
  final String currentPaymentMethod;
  final bool isEditing;
  final bool isCompleted;
  final List<Map<String, dynamic>> accounts;
  final ValueChanged<String?> onChanged;

  const OrderDetailPaymentSection({
    super.key,
    required this.currentPaymentMethod,
    required this.isEditing,
    required this.accounts,
    required this.onChanged,
    this.isCompleted = false,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'CAJA':
        return Icons.point_of_sale_rounded;
      case 'BANCO':
        return Icons.account_balance_rounded;
      case 'DIGITAL':
        return Icons.smartphone_rounded;
      default:
        return Icons.wallet_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'CAJA':
        return const Color(0xFFF59E0B);
      case 'BANCO':
        return const Color(0xFF2563EB);
      case 'DIGITAL':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCrediToLocked = isCompleted && currentPaymentMethod == 'CRÉDITO';

    final List<Map<String, dynamic>> fixedOptions = [
      {'id': 'POR_ACORDAR', 'name': 'POR ACORDAR', 'type': 'FIXED'},
      {'id': 'CREDITO', 'name': 'CRÉDITO', 'type': 'FIXED'},
    ];

    final allOptions = [...fixedOptions, ...accounts];
    final String safeValue = currentPaymentMethod.isNotEmpty ? currentPaymentMethod : 'POR ACORDAR';
    final bool valueInList = allOptions.any((o) => o['name'] as String == safeValue);

    return OrderDetailSectionCard(
      title: 'Método de Pago / Cuenta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCrediToLocked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, size: 13, color: Color(0xFFB45309)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Venta a crédito completada. El método de pago no puede modificarse.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isEditing || isCrediToLocked) ...[
            _PaymentMethodBadge(
              label: safeValue,
              icon: accounts.any((a) => a['name'] == safeValue)
                  ? _iconForType(
                      accounts.firstWhere(
                        (a) => a['name'] == safeValue,
                        orElse: () => {'type': 'OTRO'},
                      )['type'] as String,
                    )
                  : (safeValue == 'CRÉDITO' ? Icons.handshake_rounded : Icons.help_outline_rounded),
              color: accounts.any((a) => a['name'] == safeValue)
                  ? _colorForType(
                      accounts.firstWhere(
                        (a) => a['name'] == safeValue,
                        orElse: () => {'type': 'OTRO'},
                      )['type'] as String,
                    )
                  : (safeValue == 'CRÉDITO' ? AppColors.teal : AppColors.textMuted),
            ),
          ] else ...[
            SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 2),
                itemCount: allOptions.length + (valueInList ? 0 : 1),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (!valueInList && index == allOptions.length) {
                    final isSelected = safeValue == currentPaymentMethod;
                    return _buildChip(
                      name: safeValue,
                      type: 'LEGACY',
                      balance: null,
                      isSelected: isSelected,
                      isFixed: true,
                      onTap: () => onChanged(safeValue),
                    );
                  }

                  final option = allOptions[index];
                  final name = option['name'] as String;
                  final type = option['type'] as String;
                  final isFixed = type == 'FIXED';
                  final balance = isFixed ? null : (option['balance'] as num?)?.toDouble();
                  final isSelected = name == safeValue;

                  return _buildChip(
                    name: name,
                    type: type,
                    balance: balance,
                    isSelected: isSelected,
                    isFixed: isFixed,
                    onTap: () => onChanged(name),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip({
    required String name,
    required String type,
    required double? balance,
    required bool isSelected,
    required bool isFixed,
    required VoidCallback onTap,
  }) {
    final Color typeColor = isFixed
        ? (name == 'CRÉDITO' ? AppColors.teal : AppColors.textMuted)
        : _colorForType(type);
    final IconData icon = isFixed
        ? (name == 'CRÉDITO' ? Icons.handshake_rounded : Icons.pending_actions_rounded)
        : _iconForType(type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teal : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: isSelected ? Colors.white : typeColor),
                const SizedBox(width: 5),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isFixed) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white70 : typeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (balance != null)
                    Text(
                      'S/ ${balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white70 : AppColors.textMuted,
                      ),
                    ),
                ] else
                  Text(
                    name == 'CRÉDITO' ? 'A cuenta del cliente' : 'Definir luego',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _PaymentMethodBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
