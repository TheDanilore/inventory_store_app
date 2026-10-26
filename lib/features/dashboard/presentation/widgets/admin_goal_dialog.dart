import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';

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
    RegExp(r'[0-9.,]'),
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
      final value = double.tryParse(text.replaceAll(',', '.'));
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
    final value = double.tryParse(text.replaceAll(',', '.'));
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
    final value = double.tryParse(text.replaceAll(',', '.'));
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
    final current =
        double.tryParse(_addCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final newValue = current + amount;
    _addCtrl.text =
        newValue == newValue.roundToDouble()
            ? newValue.toStringAsFixed(0)
            : newValue.toStringAsFixed(2);
    AppFeedbackService.mediumImpact();
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

    final added =
        double.tryParse(_addCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final baseCurrent =
        double.tryParse(_currentCtrl.text.trim().replaceAll(',', '.')) ??
        widget.currentAmount;
    final newTarget =
        double.tryParse(_targetCtrl.text.trim().replaceAll(',', '.')) ??
        widget.targetAmount;
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
      AppFeedbackService.mediumImpact();
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.transparent,
        ),
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
                  color: AppColors.success.withValues(
                    alpha: isDark ? 0.2 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Meta de Ahorro',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Live Forecast Progress Card ─────────────────────────────
          _buildForecastPreview(isDark)
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 300))
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),

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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  return _QuickAddChip(
                    label: label,
                    isDark: isDark,
                    onTap: () => _applyQuickAdd(amount),
                  );
                }).toList(),
          ),

          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          ),
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
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ajustes avanzados',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _advancedExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
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
                  side: BorderSide(
                    color:
                        isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color:
                        isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
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

  Widget _buildForecastPreview(bool isDark) {
    final added =
        double.tryParse(_addCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final baseCurrent =
        double.tryParse(_currentCtrl.text.trim().replaceAll(',', '.')) ??
        widget.currentAmount;
    final target =
        double.tryParse(_targetCtrl.text.trim().replaceAll(',', '.')) ??
        widget.targetAmount;

    final projected = baseCurrent + (added > 0 ? added : 0.0);
    final curProgress =
        target > 0 ? (baseCurrent / target).clamp(0.0, 1.0) : 0.0;
    final projProgress =
        target > 0 ? (projected / target).clamp(0.0, 1.0) : 0.0;
    final curPercent = (curProgress * 100).toInt();
    final projPercent = (projProgress * 100).toInt();
    final willReachGoal = projProgress >= 1.0 && target > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              willReachGoal
                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                  : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso Actual: $curPercent%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                ),
              ),
              if (added > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        willReachGoal
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    willReachGoal
                        ? '🎉 ¡100% Alcanzado!'
                        : 'Proyectado: $projPercent%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          willReachGoal
                              ? const Color(0xFF10B981)
                              : const Color(0xFF2563EB),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Dual-layer Animated Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  // Background Track
                  Container(
                    color:
                        isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                  ),
                  // Projected Progress
                  if (added > 0)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: projProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                willReachGoal
                                    ? [
                                      const Color(0xFF10B981),
                                      const Color(0xFF34D399),
                                    ]
                                    : [
                                      const Color(0xFF38BDF8),
                                      const Color(0xFF60A5FA),
                                    ],
                          ),
                        ),
                      ),
                    ),
                  // Current Solid Progress
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: curProgress,
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Bottom Amounts Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'S/ ${baseCurrent.toStringAsFixed(2)} acumulados',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1E293B),
                ),
              ),
              Text(
                'Meta: S/ ${target.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAddChip extends StatefulWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickAddChip({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_QuickAddChip> createState() => _QuickAddChipState();
}

class _QuickAddChipState extends State<_QuickAddChip> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : (_isHovered ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:
                  widget.isDark
                      ? (_isHovered
                          ? const Color(0xFF15803D).withValues(alpha: 0.45)
                          : const Color(0xFF14532D).withValues(alpha: 0.35))
                      : (_isHovered
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFDCFCE7)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _isHovered
                        ? const Color(0xFF22C55E)
                        : (widget.isDark
                            ? const Color(0xFF15803D)
                            : const Color(0xFF86EFAC)),
                width: _isHovered ? 1.2 : 0.8,
              ),
              boxShadow:
                  _isHovered
                      ? [
                        BoxShadow(
                          color: const Color(
                            0xFF22C55E,
                          ).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Text(
              '+S/${widget.label}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color:
                    widget.isDark
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFF15803D),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
