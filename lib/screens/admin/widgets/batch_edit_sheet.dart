// ─── BOTTOM SHEET: EDITAR LOTES ──────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class BatchEditSheet extends StatefulWidget {
  final String productName;
  final String? variantLabel;
  final int totalRequired;
  final List<BatchAssignment> batches; // ordenados FEFO con assigned

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
  late final List<BatchAssignment> _batches;

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

  Future<void> _mostrarDialogoCantidad(
    BuildContext context,
    int index,
    BatchAssignment b,
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
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asignación de Lotes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.variantLabel != null
                          ? '${widget.productName} · ${widget.variantLabel}'
                          : widget.productName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _resetToFefo,
                icon: const Icon(Icons.restart_alt_rounded, size: 14),
                label: const Text(
                  'Reset FEFO',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  _isValid
                      ? AppColors.successLight
                      : (_remaining < 0
                          ? AppColors.dangerLight
                          : AppColors.amberLight),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _isValid
                        ? AppColors.success.withValues(alpha: 0.3)
                        : (_remaining < 0
                            ? AppColors.danger.withValues(alpha: 0.3)
                            : AppColors.amber.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isValid
                      ? Icons.check_circle_rounded
                      : (_remaining < 0
                          ? Icons.error_rounded
                          : Icons.warning_rounded),
                  size: 14,
                  color:
                      _isValid
                          ? AppColors.success
                          : (_remaining < 0
                              ? AppColors.danger
                              : AppColors.amber),
                ),
                const SizedBox(width: 6),
                Text(
                  _isValid
                      ? 'Asignación completa: $_totalAssigned / ${widget.totalRequired} unidades ✓'
                      : _remaining > 0
                      ? 'Faltan $_remaining unidades por asignar'
                      : 'Exceso de ${-_remaining} unidades. Reduce algún lote.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        _isValid
                            ? AppColors.success
                            : (_remaining < 0
                                ? AppColors.danger
                                : AppColors.amber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _batches.length,
              separatorBuilder:
                  (_, __) => const Divider(height: 1, color: AppColors.divider),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 10,
                  ),
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
                                  size: 12,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  b.batchNumber,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (index == 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.tealLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'FEFO 1°',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.tealDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: badgeColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Disponible: ${b.available} u',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap:
                                  b.assigned > 0
                                      ? () => _changeAssigned(index, -1)
                                      : null,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(8),
                              ),
                              child: Container(
                                width: 30,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 14,
                                  color:
                                      b.assigned > 0
                                          ? AppColors.textSecondary
                                          : AppColors.textHint,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap:
                                  () => _mostrarDialogoCantidad(
                                    context,
                                    index,
                                    b,
                                  ),
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 36),
                                alignment: Alignment.center,
                                color: AppColors.tealLight.withValues(
                                  alpha: 0.25,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  '${b.assigned}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.tealDark,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap:
                                  b.assigned < b.available && _remaining > 0
                                      ? () => _changeAssigned(index, 1)
                                      : null,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(8),
                              ),
                              child: Container(
                                width: 30,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color:
                                      b.assigned < b.available && _remaining > 0
                                          ? AppColors.textSecondary
                                          : AppColors.textHint,
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
            height: 50,
            child: ElevatedButton.icon(
              onPressed:
                  _isValid
                      ? () => Navigator.pop(context, List.of(_batches))
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                disabledBackgroundColor: AppColors.bg,
                disabledForegroundColor: AppColors.textHint,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.check_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Confirmar asignación',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
