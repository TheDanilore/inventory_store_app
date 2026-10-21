import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:intl/intl.dart';

/// Diálogo de detalle de turno para pantallas de escritorio.
class ShiftDetailDialog extends StatelessWidget {
  final CashShiftEntity shift;
  final VoidCallback? onCloseShift;

  const ShiftDetailDialog({super.key, required this.shift, this.onCloseShift});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShiftDetailContent(shift: shift),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                  // Botón de cierre protegido por permiso
                  PermissionGuard(
                    permission: AppPermissions.posCashShiftClose,
                    child:
                        onCloseShift != null
                            ? Row(
                              children: [
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.amberDark,
                                  ),
                                  onPressed: onCloseShift,
                                  icon: const Icon(
                                    Icons.lock_clock_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Cerrar Turno Ahora'),
                                ),
                              ],
                            )
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet de detalle de turno para móvil/tablet.
class ShiftDetailSheet extends StatelessWidget {
  final CashShiftEntity shift;
  final VoidCallback? onCloseShift;

  const ShiftDetailSheet({super.key, required this.shift, this.onCloseShift});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ShiftDetailContent(shift: shift),
              const SizedBox(height: 20),
              // Botón de cierre protegido por permiso
              PermissionGuard(
                permission: AppPermissions.posCashShiftClose,
                child:
                    onCloseShift != null
                        ? FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.amberDark,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onCloseShift,
                          icon: const Icon(Icons.lock_clock_rounded, size: 18),
                          label: const Text(
                            'Cerrar Turno Ahora',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Shared Detail Content ─────────────────────────────────────────────────────
class ShiftDetailContent extends StatelessWidget {
  final CashShiftEntity shift;

  const ShiftDetailContent({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = shift.isOpen;
    final diff = shift.differenceAmount ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isOpen ? AppColors.success : AppColors.textSecondary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.point_of_sale_rounded,
                color: isOpen ? AppColors.success : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shift.accountName ?? 'Caja General',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'ID: ${shift.id.substring(0, shift.id.length > 8 ? 8 : shift.id.length)}...',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _StatusBadge(isOpen: isOpen),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              _DetailRow(
                label: 'Apertura:',
                value:
                    '${DateFormat('dd/MM/yyyy HH:mm').format(shift.openedAt)} (${shift.openedByName ?? 'Desconocido'})',
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Cierre:',
                value:
                    isOpen
                        ? 'Turno actualmente en curso'
                        : (shift.closedAt != null
                            ? '${DateFormat('dd/MM/yyyy HH:mm').format(shift.closedAt!)} (${shift.closedByName ?? 'Desconocido'})'
                            : 'No registrado'),
              ),
              if (shift.notes != null && shift.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailRow(label: 'Notas:', value: shift.notes!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'RESUMEN FINANCIERO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _AmountRow(
                label: 'Monto Inicial (Apertura)',
                amount: shift.openingAmount,
              ),
              if (!isOpen) ...[
                const SizedBox(height: 8),
                if (shift.expectedAmount != null)
                  _AmountRow(
                    label: 'Monto Esperado',
                    amount: shift.expectedAmount!,
                  ),
                const SizedBox(height: 8),
                _AmountRow(
                  label: 'Monto Real al Cierre',
                  amount: shift.actualAmount ?? 0.0,
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Diferencia de Caja:',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      diff == 0
                          ? 'S/ 0.00 (Cuadrada)'
                          : (diff > 0
                              ? '+S/ ${diff.toStringAsFixed(2)} (Sobrante)'
                              : '-S/ ${diff.abs().toStringAsFixed(2)} (Faltante)'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color:
                            diff == 0
                                ? AppColors.textSecondary
                                : (diff > 0
                                    ? AppColors.success
                                    : AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOpen;
  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isOpen
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.slateLight.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isOpen
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOpen ? AppColors.success : AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'ABIERTO' : 'CERRADO',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isOpen ? const Color(0xFF065F46) : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  const _AmountRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          'S/ ${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
