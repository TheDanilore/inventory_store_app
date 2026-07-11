// ─── BOTTOM SHEET: EDITAR LOTES ──────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class BatchEditSheet extends StatefulWidget {
  final String productName;
  final String? variantLabel;
  final int totalRequired;
  final List<BatchAssignmentModel> batches; // ordenados FEFO con assigned

  const BatchEditSheet({
    super.key,
    required this.productName,
    this.variantLabel,
    required this.totalRequired,
    required this.batches,
  });

  @override
  State<BatchEditSheet> createState() => _BatchEditSheetState();
}

class _BatchEditSheetState extends State<BatchEditSheet> {
  late final List<BatchAssignmentModel> _batches;

  @override
  void initState() {
    super.initState();
    _batches =
        widget.batches.map((b) => b.copyWith(assigned: b.assigned)).toList();
  }

  int get _totalAssigned => _batches.fold(0, (s, b) => s + b.assigned);
  int get _remaining => widget.totalRequired - _totalAssigned;
  bool get _isValid => _totalAssigned == widget.totalRequired;

  void _resetToFefo() {
    setState(() {
      for (final b in _batches) {
        b.assigned = 0;
      }
      int rem = widget.totalRequired;
      for (final b in _batches) {
        if (rem <= 0) break;
        b.assigned = rem > b.available ? b.available : rem;
        rem -= b.assigned;
      }
    });
  }

  void _changeAssigned(int index, int delta) {
    setState(() {
      final b = _batches[index];
      final newVal = (b.assigned + delta).clamp(0, b.available);
      _batches[index].assigned = newVal;
    });
  }

  Future<void> _showQuantityDialog(
    BuildContext context,
    int index,
    BatchAssignmentModel b,
  ) async {
    final qtyCtrl = TextEditingController(text: b.assigned.toString());
    final maximoPermitido = b.assigned + _remaining;
    final stockMaximoReal =
        maximoPermitido < b.available ? maximoPermitido : b.available;

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad exacta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                helperText: 'Límite disponible: $stockMaximoReal',
                helperStyle: const TextStyle(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                ),
                onPressed: () {
                  final newQty = int.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty >= 0) {
                    if (newQty <= stockMaximoReal) {
                      final diferencia = (newQty - b.assigned).toInt();
                      if (diferencia != 0) _changeAssigned(index, diferencia);
                      Navigator.pop(dialogContext);
                    } else {
                      AppSnackbar.show(
                        context,
                        message:
                            'No puedes asignar más de $stockMaximoReal unidades.',
                        type: SnackbarType.warning,
                      );
                    }
                  } else {
                    AppSnackbar.show(
                      context,
                      message: 'Por favor, ingresa un número válido.',
                      type: SnackbarType.error,
                    );
                  }
                },
                child: Text(
                  'Guardar',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              mediaQuery.viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Asignación de Lotes',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.variantLabel != null
                                ? '${widget.productName} · ${widget.variantLabel}'
                                : widget.productName,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _resetToFefo();
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text(
                        'Reset FEFO',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isValid
                            ? AppColors.successLight
                            : (_remaining < 0
                                ? AppColors.dangerLight
                                : AppColors.amberLight),
                    borderRadius: BorderRadius.circular(AppColors.radiusLg),
                  ),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          _isValid
                              ? Icons.check_circle_rounded
                              : (_remaining < 0
                                  ? Icons.error_rounded
                                  : Icons.warning_rounded),
                          key: ValueKey(
                            _isValid ? 'ok' : (_remaining < 0 ? 'err' : 'warn'),
                          ),
                          size: 16,
                          color:
                              _isValid
                                  ? AppColors.success
                                  : (_remaining < 0
                                      ? AppColors.danger
                                      : AppColors.amber),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isValid
                                ? 'Asignación completa: $_totalAssigned / ${widget.totalRequired} unidades ✓'
                                : _remaining > 0
                                ? 'Faltan $_remaining unidades por asignar'
                                : 'Exceso de ${-_remaining} unidades. Reduce algún lote.',
                            key: ValueKey('text_$_totalAssigned'),
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  _isValid
                                      ? AppColors.successDark
                                      : (_remaining < 0
                                          ? AppColors.danger
                                          : AppColors.amberDark),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: mediaQuery.size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _batches.length,
                    separatorBuilder:
                        (_, _) =>
                            const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final b = _batches[index];
                      final isExpired =
                          b.expiryDate != null &&
                          b.expiryDate!.isBefore(DateTime.now());
                      final badgeColor =
                          isExpired
                              ? AppColors.danger
                              : b.isExpiringSoon
                              ? AppColors.amber
                              : AppColors.success;
                      final badgeLabel =
                          isExpired
                              ? 'VENCIDO'
                              : b.isExpiringSoon
                              ? 'PRÓXIMO A VENCER'
                              : b.expiryDate != null
                              ? 'Vto: ${b.expiryLabel}'
                              : 'Sin vto.';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.tag_rounded,
                                        size: 14,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        b.batchNumber,
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (index == 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.tealLight,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'FEFO 1°',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.tealDark,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: textTheme.labelSmall?.copyWith(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Disponible: ${b.available} u',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap:
                                          b.assigned > 0
                                              ? () {
                                                HapticFeedback.lightImpact();
                                                _changeAssigned(index, -1);
                                              }
                                              : null,
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Icon(
                                          Icons.remove_rounded,
                                          size: 20,
                                          color:
                                              b.assigned > 0
                                                  ? AppColors.textSecondary
                                                  : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap:
                                        () => _showQuantityDialog(
                                          context,
                                          index,
                                          b,
                                        ),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                      ),
                                      alignment: Alignment.center,
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        transitionBuilder:
                                            (child, anim) => ScaleTransition(
                                              scale: anim,
                                              child: child,
                                            ),
                                        child: Text(
                                          '${b.assigned}',
                                          key: ValueKey(b.assigned),
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.tealDark,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap:
                                          b.assigned < b.available &&
                                                  _remaining > 0
                                              ? () {
                                                HapticFeedback.lightImpact();
                                                _changeAssigned(index, 1);
                                              }
                                              : null,
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Icon(
                                          Icons.add_rounded,
                                          size: 20,
                                          color:
                                              b.assigned < b.available &&
                                                      _remaining > 0
                                                  ? AppColors.textSecondary
                                                  : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isValid
                            ? () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context, List.of(_batches));
                            }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.background,
                      disabledForegroundColor: AppColors.textMuted,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radius),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text(
                      'Confirmar asignación',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
