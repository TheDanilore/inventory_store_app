import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

/// Montos sugeridos para el abono rápido a la meta.
/// Edita esta lista para ajustar los chips sin tocar el resto del widget.
const List<double> kQuickAddAmounts = [50, 100, 200, 500];

class AdminGoalDialog extends StatefulWidget {
  final double currentAmount;
  final double targetAmount;

  const AdminGoalDialog({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
  });

  @override
  State<AdminGoalDialog> createState() => _AdminGoalDialogState();
}

class _AdminGoalDialogState extends State<AdminGoalDialog> {
  late TextEditingController _addCtrl;
  late TextEditingController _currentCtrl;
  late TextEditingController _targetCtrl;

  final _addFocusNode = FocusNode();
  final _currentFocusNode = FocusNode();
  final _targetFocusNode = FocusNode();

  bool _isLoading = false;
  bool _justSaved = false;

  // La sección avanzada inicia abierta solo si todavía no hay meta configurada
  // (primera vez), porque en ese caso el usuario SÍ necesita llenarla.
  late bool _advancedExpanded;

  String? _addError;
  String? _currentError;
  String? _targetError;

  static final _decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d{0,2}'),
  );

  @override
  void initState() {
    super.initState();
    _advancedExpanded = widget.targetAmount <= 0;

    _addCtrl = TextEditingController();
    _currentCtrl = TextEditingController(
      text: widget.currentAmount.toStringAsFixed(2),
    );
    _targetCtrl = TextEditingController(
      text:
          widget.targetAmount > 0 ? widget.targetAmount.toStringAsFixed(2) : '',
    );

    _addCtrl.addListener(_validateAdd);
    _currentCtrl.addListener(_validateCurrent);
    _targetCtrl.addListener(_validateTarget);
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _currentCtrl.dispose();
    _targetCtrl.dispose();
    _addFocusNode.dispose();
    _currentFocusNode.dispose();
    _targetFocusNode.dispose();
    super.dispose();
  }

  // ── Validación en tiempo real ────────────────────────────────────────

  void _validateAdd() {
    final text = _addCtrl.text.trim();
    String? error;
    if (text.isNotEmpty) {
      final value = double.tryParse(text);
      if (value == null) {
        error = 'Monto inválido';
      } else if (value < 0) {
        error = 'No puede ser negativo';
      }
    }
    if (error != _addError) {
      setState(() => _addError = error);
    }
  }

  void _validateCurrent() {
    final text = _currentCtrl.text.trim();
    String? error;
    final value = double.tryParse(text);
    if (text.isEmpty || value == null) {
      error = 'Ingresa un número válido';
    } else if (value < 0) {
      error = 'No puede ser negativo';
    }
    if (error != _currentError) {
      setState(() => _currentError = error);
    }
  }

  void _validateTarget() {
    final text = _targetCtrl.text.trim();
    String? error;
    final value = double.tryParse(text);
    if (text.isEmpty || value == null) {
      error = 'Ingresa un número válido';
    } else if (value <= 0) {
      error = 'Debe ser mayor a 0';
    }
    if (error != _targetError) {
      setState(() => _targetError = error);
    }
  }

  void _applyQuickAdd(double amount) {
    final current = double.tryParse(_addCtrl.text.trim()) ?? 0.0;
    final newValue = current + amount;
    _addCtrl.text =
        newValue == newValue.roundToDouble()
            ? newValue.toStringAsFixed(0)
            : newValue.toStringAsFixed(2);
    // Solo vibrar si no es web para evitar MissingPluginException
    if (!kIsWeb) {
      Vibration.vibrate(duration: 50, amplitude: 128);
    }
  }

  Future<void> _saveGoal() async {
    // Validar todo antes de intentar guardar.
    _validateAdd();
    _validateCurrent();
    _validateTarget();

    if (_addError != null || _currentError != null || _targetError != null) {
      AppSnackbar.show(
        context,
        message: 'Revisa los campos marcados antes de continuar.',
        type: SnackbarType.error,
      );
      return;
    }

    final added = double.tryParse(_addCtrl.text.trim()) ?? 0.0;
    final baseCurrent =
        double.tryParse(_currentCtrl.text.trim()) ?? widget.currentAmount;
    final newTarget =
        double.tryParse(_targetCtrl.text.trim()) ?? widget.targetAmount;
    final newCurrent = baseCurrent + added;

    setState(() => _isLoading = true);

    final configCubit = context.read<AppConfigCubit>();

    try {
      await configCubit.saveValue(
        'admin_goal_current',
        newCurrent,
        // description: 'Progreso actual del ahorro',
      );
      await configCubit.saveValue(
        'admin_goal_target',
        newTarget,
        // description: 'Meta de ahorro del administrador',
      );

      if (!mounted) return;

      // Microinteracción: mostramos un check breve antes de cerrar.
      setState(() {
        _isLoading = false;
        _justSaved = true;
      });
      // Solo vibrar si no es web para evitar MissingPluginException
      if (!kIsWeb) {
        Vibration.vibrate(duration: 50, amplitude: 128);
      }
      await Future.delayed(const Duration(milliseconds: 550));

      if (!mounted) return;
      Navigator.pop(context, true);
      AppSnackbar.show(
        context,
        message: '¡Meta actualizada con éxito!',
        type: SnackbarType.success,
      );
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error al actualizar meta de ahorro',
        tag: 'ADMIN_GOAL_DIALOG',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.show(
          context,
          message: 'Error al actualizar meta: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Title, Icon and Close Button ─────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Meta de Ahorro',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: const Color(0xFF64748B),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Acción primaria: abonar ──────────────────────────────────
          Text(
            'Abonar a la meta',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addCtrl,
            focusNode: _addFocusNode,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            textInputAction: TextInputAction.done,
            inputFormatters: [_decimalFormatter],
            onSubmitted: (_) => _saveGoal(),
            decoration: InputDecoration(
              labelText: 'Monto a sumar (S/.)',
              hintText: 'Ej. 100',
              helperText:
                  'Se sumará al saldo actual de S/ ${widget.currentAmount.toStringAsFixed(2)}',
              helperMaxLines: 1,
              errorText: _addError,
              prefixIcon: Semantics(
                label: 'Sumar monto',
                child: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.success,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Chips de monto rápido
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                kQuickAddAmounts.map((amount) {
                  final label =
                      amount == amount.roundToDouble()
                          ? amount.toStringAsFixed(0)
                          : amount.toStringAsFixed(2);
                  return ActionChip(
                    label: Text('+S/$label'),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: Color(0xFF15803D),
                    ),
                    backgroundColor: const Color(0xFFDCFCE7),
                    side: const BorderSide(
                      color: Color(0xFF86EFAC),
                      width: 0.8,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    onPressed: () => _applyQuickAdd(amount),
                  );
                }).toList(),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 4),

          // ── Sección avanzada (colapsable) ────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() => _advancedExpanded = !_advancedExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ajustes avanzados',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _advancedExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child:
                _advancedExpanded
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Saldo actual exacto',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _currentCtrl,
                          focusNode: _currentFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          inputFormatters: [_decimalFormatter],
                          onSubmitted: (_) => _targetFocusNode.requestFocus(),
                          decoration: InputDecoration(
                            labelText: 'Corregir saldo (S/.)',
                            helperText:
                                'Usa esto solo para corregir un error, no para abonar.',
                            helperMaxLines: 1,
                            errorText: _currentError,
                            prefixIcon: const Icon(
                              Icons.edit_note,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Modificar meta total',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _targetCtrl,
                          focusNode: _targetFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          inputFormatters: [_decimalFormatter],
                          onSubmitted: (_) => _saveGoal(),
                          decoration: InputDecoration(
                            labelText: 'Nueva meta total (S/.)',
                            helperText: 'El objetivo final de ahorro.',
                            errorText: _targetError,
                            prefixIcon: const Icon(
                              Icons.flag_outlined,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    )
                    : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // ── Actions: Cancelar & Guardar ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(90, 42),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  minimumSize: const Size(100, 42),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoading || _justSaved ? null : _saveGoal,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildActionButtonContent(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonContent() {
    if (_justSaved) {
      return const Row(
        key: ValueKey('saved'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text('Guardado', style: TextStyle(color: Colors.white)),
        ],
      );
    }
    if (_isLoading) {
      return const SizedBox(
        key: ValueKey('loading'),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }
    return const Text(
      'Guardar',
      key: ValueKey('idle'),
      style: TextStyle(color: Colors.white),
    );
  }
}
