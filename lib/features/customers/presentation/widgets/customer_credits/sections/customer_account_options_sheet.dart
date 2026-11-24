import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

/// Modal de opciones rápidas para una línea de crédito de cliente.
class CustomerAccountOptionsSheet {
  static String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'CL';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  static void show(
    BuildContext context, {
    required CustomerCreditEntity account,
    required VoidCallback onPay,
    required VoidCallback onHistory,
    required VoidCallback onEditLimit,
    required VoidCallback onToggleStatus,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        final canPay = account.isActive && account.currentDebt > 0;
        final availableLabel =
            account.isUnlimited
                ? 'Ilimitado'
                : 'S/ ${account.availableCredit.toStringAsFixed(2)}';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getInitials(account.customerName),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.customerName ?? 'Cliente',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Deuda: S/ ${account.currentDebt.toStringAsFixed(2)} | Disp: $availableLabel',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          canPay
                              ? const Color(0xFFF0FDF4)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.payments_rounded,
                      color:
                          canPay
                              ? const Color(0xFF16A34A)
                              : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Registrar Pago / Abono',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    account.currentDebt <= 0
                        ? 'Esta línea no presenta saldo pendiente'
                        : 'Amortizar saldo deudor',
                    style: const TextStyle(fontSize: 12),
                  ),
                  enabled: canPay,
                  onTap: () {
                    Navigator.pop(ctx);
                    onPay();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Ver historial de movimientos',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Revisar cargos, abonos y comprobantes',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onHistory();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Editar Límite de Crédito',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Modificar cupo total asignado',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEditLimit();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          account.isActive
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      account.isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_rounded,
                      color:
                          account.isActive
                              ? AppColors.error
                              : AppColors.success,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    account.isActive ? 'Suspender Línea' : 'Reactivar Línea',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          account.isActive
                              ? AppColors.error
                              : AppColors.success,
                    ),
                  ),
                  subtitle: Text(
                    account.isActive
                        ? 'Bloquear nuevas compras a crédito'
                        : 'Habilitar compras a crédito',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onToggleStatus();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
