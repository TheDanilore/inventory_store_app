import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Formatea una cantidad: "5" si es entera, "2.5" si tiene decimales.
String formatExitQty(double v) {
  if (v % 1 == 0) return v.toInt().toString();
  return v
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Cantidad editable directamente (sin diálogos), con tope de stock.
///
/// - Si el usuario escribe más que [max], se corrige al máximo y se avisa.
/// - Si deja el campo vacío o en 0 y sale de él, vuelve al último valor válido.
/// - El controlador vive aquí dentro, así que no hay riesgo de usarlo
///   después de haberlo destruido (error típico con `showDialog`).
class ExitQuantityStepper extends StatefulWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  /// Muestra los botones − / +. En tablas se usa solo el campo.
  final bool showButtons;

  /// Versión grande (hoja de producto). Si es false, versión compacta.
  final bool large;

  /// Muestra "Máximo disponible: N" debajo cuando se intenta superar el tope.
  final bool showHint;

  const ExitQuantityStepper({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.showButtons = true,
    this.large = false,
    this.showHint = true,
  });

  @override
  State<ExitQuantityStepper> createState() => _ExitQuantityStepperState();
}

class _ExitQuantityStepperState extends State<ExitQuantityStepper> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _overMax = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: formatExitQty(widget.value));
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant ExitQuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el valor cambió desde afuera (botones, otro widget), refleja en texto.
    final parsed = _parse(_ctrl.text);
    if (parsed != null && (parsed - widget.value).abs() > 1e-9) {
      _setText(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  double? _parse(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  void _setText(double v) {
    final t = formatExitQty(v);
    _ctrl.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  void _onFocusChange() {
    if (_focus.hasFocus) return;
    final p = _parse(_ctrl.text);
    if (p == null || p <= 0) _setText(widget.value);
    if (_overMax && mounted) setState(() => _overMax = false);
  }

  void _onTyped(String raw) {
    final p = _parse(raw);
    if (p == null || p <= 0) return;
    if (widget.max > 0 && p > widget.max) {
      AppFeedbackService.mediumImpact();
      _setText(widget.max);
      setState(() => _overMax = true);
      widget.onChanged(widget.max);
      return;
    }
    if (_overMax) setState(() => _overMax = false);
    widget.onChanged(p);
  }

  void _step(int delta) {
    AppFeedbackService.selectionClick();
    var next = widget.value + delta;
    if (next < 1) next = 1;
    var over = false;
    if (widget.max > 0 && next > widget.max) {
      next = widget.max;
      over = true;
    }
    _setText(next);
    setState(() => _overMax = over);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final large = widget.large;
    final height = large ? 56.0 : 40.0;
    final radius = large ? 14.0 : 10.0;
    final canDecrease = widget.value > 1;
    final canIncrease = widget.max <= 0 || widget.value < widget.max;

    final field = TextField(
      controller: _ctrl,
      focusNode: _focus,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,3}')),
      ],
      onTap:
          () =>
              _ctrl.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _ctrl.text.length,
              ),
      onChanged: _onTyped,
      style: TextStyle(
        fontSize: large ? 20 : 14,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
    );

    final box = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: widget.showButtons ? 4 : 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: _overMax ? AppColors.danger : AppColors.border,
          width: _overMax ? 1.5 : 1,
        ),
      ),
      child:
          widget.showButtons
              ? Row(
                children: [
                  Semantics(
                    label: 'Disminuir cantidad',
                    button: true,
                    child: _StepButton(
                      icon: Icons.remove_rounded,
                      enabled: canDecrease,
                      height: height - 10,
                      onTap: () => _step(-1),
                    ),
                  ),
                  Expanded(child: field),
                  Semantics(
                    label: 'Aumentar cantidad',
                    button: true,
                    child: _StepButton(
                      icon: Icons.add_rounded,
                      enabled: canIncrease,
                      height: height - 10,
                      onTap: () => _step(1),
                    ),
                  ),
                ],
              )
              : Center(child: field),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        box,
        if (_overMax && widget.showHint)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Máximo disponible: ${formatExitQty(widget.max)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final double height;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.primary.withValues(alpha: 0.18),
        child: Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            color:
                enabled
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
