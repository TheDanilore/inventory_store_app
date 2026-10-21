import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:intl/intl.dart';

// ── Shared Style ─────────────────────────────────────────────────────────────
const tableHeaderStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.6,
  color: AppColors.textSecondary,
);

// ── Status Badge ─────────────────────────────────────────────────────────────
class ShiftStatusBadge extends StatelessWidget {
  final bool isOpen;

  const ShiftStatusBadge({super.key, required this.isOpen});

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

// ── Desktop Table Row ─────────────────────────────────────────────────────────
class ShiftDesktopTableRow extends StatefulWidget {
  final CashShiftEntity shift;
  final VoidCallback onTap;

  /// Null cuando el usuario no tiene permiso `pos.cash_shift.close`
  final VoidCallback? onClose;

  const ShiftDesktopTableRow({
    super.key,
    required this.shift,
    required this.onTap,
    this.onClose,
  });

  @override
  State<ShiftDesktopTableRow> createState() => _ShiftDesktopTableRowState();
}

class _ShiftDesktopTableRowState extends State<ShiftDesktopTableRow> {
  bool _isHovered = false;
  bool _isClosing = false;

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final isOpen = shift.isOpen;
    final theme = Theme.of(context);
    final diff = shift.differenceAmount ?? 0.0;
    final hasDiff = shift.differenceAmount != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          color:
              _isHovered
                  ? theme.colorScheme.primary.withValues(alpha: 0.03)
                  : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              // Estado
              SizedBox(
                width: 110,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ShiftStatusBadge(isOpen: isOpen),
                ),
              ),

              // Caja / Cuenta
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isOpen
                                ? AppColors.success
                                : AppColors.textSecondary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.point_of_sale_rounded,
                        size: 16,
                        color:
                            isOpen
                                ? AppColors.success
                                : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shift.accountName ?? 'Caja General',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (shift.notes != null && shift.notes!.isNotEmpty)
                            Text(
                              shift.notes!,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Responsable
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        (shift.openedByName?.isNotEmpty == true)
                            ? shift.openedByName![0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shift.openedByName ?? 'Desconocido',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Apertura
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S/ ${shift.openingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM HH:mm').format(shift.openedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Cierre
              Expanded(
                flex: 2,
                child:
                    isOpen
                        ? Text(
                          'En curso...',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.success.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'S/ ${(shift.actualAmount ?? 0.0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (shift.closedAt != null)
                              Text(
                                DateFormat(
                                  'dd/MM HH:mm',
                                ).format(shift.closedAt!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
              ),

              // Diferencia
              Expanded(
                flex: 2,
                child:
                    !isOpen && hasDiff
                        ? _DiffBadge(diff: diff)
                        : Text(
                          '-',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
              ),

              // Acciones
              SizedBox(
                width: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Botón "Cerrar Turno" protegido por permiso
                    if (isOpen)
                      PermissionGuard(
                        permission: AppPermissions.posCashShiftClose,
                        // Sin permiso: solo icono de detalle
                        fallback: IconButton(
                          onPressed: widget.onTap,
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                          ),
                          tooltip: 'Ver detalle de arqueo',
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: FilledButton.icon(
                          onPressed:
                              widget.onClose == null || _isClosing
                                  ? null
                                  : () async {
                                    setState(() => _isClosing = true);
                                    widget.onClose!();
                                    if (mounted) {
                                      setState(() => _isClosing = false);
                                    }
                                  },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.amberDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon:
                              _isClosing
                                  ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.lock_clock_rounded,
                                    size: 14,
                                  ),
                          label: const Text(
                            'Cerrar',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      IconButton(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        tooltip: 'Ver detalle de arqueo',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile Card ───────────────────────────────────────────────────────────────
class ShiftMobileCard extends StatefulWidget {
  final CashShiftEntity shift;
  final VoidCallback onTap;

  /// Null cuando el usuario no tiene permiso `pos.cash_shift.close`
  final VoidCallback? onClose;

  const ShiftMobileCard({
    super.key,
    required this.shift,
    required this.onTap,
    this.onClose,
  });

  @override
  State<ShiftMobileCard> createState() => _ShiftMobileCardState();
}

class _ShiftMobileCardState extends State<ShiftMobileCard> {
  bool _isClosing = false;

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final isOpen = shift.isOpen;
    final theme = Theme.of(context);
    final diff = shift.differenceAmount ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.35),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isOpen
                              ? AppColors.success
                              : AppColors.textSecondary)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.point_of_sale_rounded,
                      size: 18,
                      color:
                          isOpen ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.accountName ?? 'Caja General',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'dd MMM, HH:mm',
                              ).format(shift.openedAt),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•  ${shift.openedByName?.split(' ')[0] ?? 'Cajero'}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ShiftStatusBadge(isOpen: isOpen),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 0.5,
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apertura',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'S/ ${shift.openingAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isOpen) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cierre',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'S/ ${(shift.actualAmount ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Diferencia',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            diff == 0
                                ? 'S/ 0.00'
                                : (diff > 0
                                    ? '+S/ ${diff.toStringAsFixed(2)}'
                                    : '-S/ ${diff.abs().toStringAsFixed(2)}'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
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
                    ),
                  ],
                ],
              ),

              // Botón de cierre protegido por permiso
              if (isOpen)
                PermissionGuard(
                  permission: AppPermissions.posCashShiftClose,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: FilledButton.icon(
                      onPressed:
                          widget.onClose == null || _isClosing
                              ? null
                              : () async {
                                setState(() => _isClosing = true);
                                widget.onClose!();
                                if (mounted) setState(() => _isClosing = false);
                              },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.amberDark,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon:
                          _isClosing
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.lock_clock_rounded, size: 16),
                      label: const Text(
                        'Cerrar Turno de Caja',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Diff Badge ────────────────────────────────────────────────────────────────
class _DiffBadge extends StatelessWidget {
  final double diff;

  const _DiffBadge({required this.diff});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color:
                diff == 0
                    ? AppColors.slateLight
                    : (diff > 0
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.danger.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            diff == 0
                ? 'S/ 0.00'
                : (diff > 0
                    ? '+S/ ${diff.toStringAsFixed(2)}'
                    : '-S/ ${diff.abs().toStringAsFixed(2)}'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color:
                  diff == 0
                      ? AppColors.textSecondary
                      : (diff > 0 ? AppColors.success : AppColors.danger),
            ),
          ),
        ),
      ],
    );
  }
}
