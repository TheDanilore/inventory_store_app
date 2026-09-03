// ─── COMPONENTE CAMALEÓNICO ADAPTATIVO: ASIGNACIÓN DE LOTES ─────────────────
//
// Muta inteligentemente de personalidad:
// • Móvil: BottomSheet estilo Apple HIG con drag handle, área del pulgar de 48dp y hápticos.
// • Desktop / Tablet: Diálogo centrado Pro-Tool estilo Linear/Stripe, bordes simétricos (20dp),
//   cabecera con botón 'X', atajos de teclado (Esc, Enter, Ctrl+R), barra de progreso FEFO y edición inline.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class BatchEditSheet extends StatefulWidget {
  final String productName;
  final String? variantLabel;
  final int totalRequired;
  final List<BatchAssignmentModel> batches; // Ordenados FEFO con assigned
  final bool? isDialog;

  const BatchEditSheet({
    super.key,
    required this.productName,
    this.variantLabel,
    required this.totalRequired,
    required this.batches,
    this.isDialog,
  });

  /// Invocación unificada y adaptativa que elige automáticamente Dialog o BottomSheet
  static Future<List<BatchAssignmentModel>?> show(
    BuildContext context, {
    required String productName,
    String? variantLabel,
    required int totalRequired,
    required List<BatchAssignmentModel> batches,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) {
      return showDialog<List<BatchAssignmentModel>>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder:
            (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 700,
                ),
                child: BatchEditSheet(
                  productName: productName,
                  variantLabel: variantLabel,
                  totalRequired: totalRequired,
                  batches: batches,
                  isDialog: true,
                ),
              ),
            ),
      );
    } else {
      return showModalBottomSheet<List<BatchAssignmentModel>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (ctx) => BatchEditSheet(
              productName: productName,
              variantLabel: variantLabel,
              totalRequired: totalRequired,
              batches: batches,
              isDialog: false,
            ),
      );
    }
  }

  @override
  State<BatchEditSheet> createState() => _BatchEditSheetState();
}

class _BatchEditSheetState extends State<BatchEditSheet> {
  late final List<BatchAssignmentModel> _batches;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _batches =
        widget.batches.map((b) => b.copyWith(assigned: b.assigned)).toList();
    _controllers =
        _batches
            .map((b) => TextEditingController(text: b.assigned.toString()))
            .toList();
    _focusNodes = _batches.map((_) => FocusNode()).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  int get _totalAssigned => _batches.fold(0, (s, b) => s + b.assigned);
  int get _remaining => widget.totalRequired - _totalAssigned;
  bool get _isValid => _totalAssigned == widget.totalRequired;

  void _vibrate({int duration = 50, int amplitude = 128}) {
    // Solo vibrar si no es web para evitar MissingPluginException
    if (!kIsWeb) {
      Vibration.vibrate(duration: duration, amplitude: amplitude);
    }
  }

  void _resetToFefo() {
    _vibrate(duration: 50, amplitude: 128);
    // Retorna lista vacía como señal atómica para restablecer a FEFO automático y cerrar de una vez
    Navigator.pop(context, const <BatchAssignmentModel>[]);
  }

  void _changeAssigned(int index, int delta) {
    _vibrate(duration: 30, amplitude: 64);
    setState(() {
      final b = _batches[index];
      final newVal = (b.assigned + delta).clamp(0, b.available);
      _batches[index].assigned = newVal;
      _controllers[index].text = newVal.toString();
    });
  }

  void _assignMax(int index) {
    _vibrate(duration: 40, amplitude: 96);
    setState(() {
      final b = _batches[index];
      final otherAssigned = _totalAssigned - b.assigned;
      final needed = (widget.totalRequired - otherAssigned).clamp(
        0,
        widget.totalRequired,
      );
      final toAssign = needed > b.available ? b.available : needed;
      b.assigned = toAssign;
      _controllers[index].text = toAssign.toString();
    });
  }

  void _onConfirm() {
    if (!_isValid) return;
    // Solo vibrar si no es web para evitar MissingPluginException
    if (!kIsWeb) {
      Vibration.vibrate(duration: 50, amplitude: 128);
    }
    Navigator.pop(context, List.of(_batches));
  }

  void _onCancel() {
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = widget.isDialog ?? (mediaQuery.size.width >= 700);

    final content = Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              isDesktop
                  ? BorderRadius.circular(20)
                  : const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDesktop ? 0.12 : 0.08),
              blurRadius: isDesktop ? 32 : 16,
              offset: Offset(0, isDesktop ? 8 : -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── DRAG HANDLE (SOLO MÓVIL) ──
            if (!isDesktop) ...[
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],

            // ── CABECERA PRO ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 20,
                isDesktop ? 20 : 10,
                isDesktop ? 20 : 16,
                14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.layers_rounded,
                      color: AppColors.teal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asignación de Lotes',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.variantLabel != null
                              ? '${widget.productName} · ${widget.variantLabel}'
                              : widget.productName,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón Reset FEFO Pro
                  Tooltip(
                    message: 'Restablecer a FEFO automático y cerrar',
                    child: OutlinedButton.icon(
                      onPressed: _resetToFefo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.tealDark,
                        side: BorderSide(
                          color: AppColors.teal.withValues(alpha: 0.25),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text(
                        'Reset FEFO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _onCancel,
                      tooltip: 'Cerrar (Esc)',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.textSecondary,
                      splashRadius: 20,
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── CUERPO PRINCIPAL CON SCROLL ──
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 20,
                  16,
                  isDesktop ? 24 : 20,
                  12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // BANNER DE PROGRESO DINÁMICO (WCAG AAA)
                    _buildProgressBanner(),
                    const SizedBox(height: 16),

                    // LISTA DE LOTES EN TARJETAS
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _batches.length,
                      separatorBuilder:
                          (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildBatchCard(index, isDesktop);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── FOOTER DE ACCIONES ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 20,
                14,
                isDesktop ? 24 : 20,
                isDesktop ? 20 : (mediaQuery.viewInsets.bottom + 16),
              ),
              child:
                  isDesktop
                      ? _buildDesktopFooter()
                      : _buildMobileFooter(),
            ),
          ],
        ),
      ),
    );

    // Envolver con atajos de teclado completos en desktop
    if (isDesktop) {
      return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _onCancel,
          const SingleActivator(LogicalKeyboardKey.enter): _onConfirm,
          const SingleActivator(
            LogicalKeyboardKey.keyR,
            control: true,
          ): _resetToFefo,
          const SingleActivator(
            LogicalKeyboardKey.keyR,
            meta: true,
          ): _resetToFefo,
        },
        child: Focus(autofocus: true, child: content),
      );
    }

    return SafeArea(child: content);
  }

  // ── BANNER DE PROGRESO CON MEDIDOR VISUAL ──────────────────────────────────
  Widget _buildProgressBanner() {
    final double progress =
        widget.totalRequired > 0
            ? (_totalAssigned / widget.totalRequired).clamp(0.0, 1.0)
            : 1.0;

    final Color bannerBg;
    final Color bannerBorder;
    final Color textColor;
    final Color progressColor;
    final IconData statusIcon;
    final String statusText;

    if (_isValid) {
      bannerBg = const Color(0xFFE6F4EA);
      bannerBorder = const Color(0xFFB7E1CD);
      textColor = const Color(0xFF137333);
      progressColor = AppColors.teal;
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Asignación completa';
    } else if (_remaining > 0) {
      bannerBg = const Color(0xFFFEF7E0);
      bannerBorder = const Color(0xFFFEEFC3);
      textColor = const Color(0xFFB06000);
      progressColor = const Color(0xFFE37400);
      statusIcon = Icons.pending_actions_rounded;
      statusText = 'Faltan $_remaining de ${widget.totalRequired} unidades';
    } else {
      bannerBg = const Color(0xFFFCE8E6);
      bannerBorder = const Color(0xFFFAD2CF);
      textColor = const Color(0xFFC5221F);
      progressColor = const Color(0xFFD93025);
      statusIcon = Icons.error_outline_rounded;
      statusText =
          'Exceso de ${-_remaining} unidades. Reduce algún lote';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 16, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                '$_totalAssigned / ${widget.totalRequired} u',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.7),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── TARJETA INDIVIDUAL DE LOTE (INLINE EDITING + HOVER) ─────────────────────
  Widget _buildBatchCard(int index, bool isDesktop) {
    final b = _batches[index];
    final isAssigned = b.assigned > 0;
    final isExpired =
        b.expiryDate != null && b.expiryDate!.isBefore(DateTime.now());

    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeText;
    final IconData badgeIcon;
    final String badgeLabel;

    if (isExpired) {
      badgeBg = const Color(0xFFFCE8E6);
      badgeBorder = const Color(0xFFFAD2CF);
      badgeText = const Color(0xFFC5221F);
      badgeIcon = Icons.warning_amber_rounded;
      badgeLabel = 'VENCIDO';
    } else if (b.isExpiringSoon) {
      badgeBg = const Color(0xFFFEF7E0);
      badgeBorder = const Color(0xFFFEEFC3);
      badgeText = const Color(0xFFB06000);
      badgeIcon = Icons.schedule_rounded;
      badgeLabel = 'POR VENCER';
    } else {
      badgeBg = const Color(0xFFE6F4EA);
      badgeBorder = const Color(0xFFCEEAD6);
      badgeText = const Color(0xFF137333);
      badgeIcon = Icons.calendar_today_rounded;
      badgeLabel = b.expiryDate != null ? b.expiryLabel : 'Sin vto.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isAssigned
                ? AppColors.teal.withValues(alpha: 0.04)
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isAssigned
                  ? AppColors.teal.withValues(alpha: 0.45)
                  : AppColors.border,
          width: isAssigned ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Identificación del lote
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '# ${b.batchNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
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
                          color: AppColors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FEFO 1°',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 11, color: badgeText),
                          const SizedBox(width: 4),
                          Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: badgeText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Disponible: ${b.available} u',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Acciones de asignación con Stepper + Input Directo + Botón Máx
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón Máx
              Tooltip(
                message: 'Asignar el máximo posible de este lote',
                child: InkWell(
                  onTap: () => _assignMax(index),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.teal.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Text(
                      'Máx',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tealDark,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Contenedor Stepper con input inline
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isAssigned
                            ? AppColors.teal.withValues(alpha: 0.5)
                            : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botón Menos
                    InkWell(
                      onTap:
                          b.assigned > 0
                              ? () => _changeAssigned(index, -1)
                              : null,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(7),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 16,
                          color:
                              b.assigned > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                        ),
                      ),
                    ),

                    // Input numérico inline sin diálogos anidados
                    SizedBox(
                      width: 44,
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color:
                              isAssigned
                                  ? AppColors.tealDark
                                  : AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final p = int.tryParse(val.trim()) ?? 0;
                          final clamped = p.clamp(0, b.available);
                          setState(() {
                            b.assigned = clamped;
                          });
                        },
                        onEditingComplete: () {
                          _controllers[index].text = b.assigned.toString();
                          _focusNodes[index].unfocus();
                        },
                      ),
                    ),

                    // Botón Más
                    InkWell(
                      onTap:
                          b.assigned < b.available && _remaining > 0
                              ? () => _changeAssigned(index, 1)
                              : null,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(7),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.add_rounded,
                          size: 16,
                          color:
                              b.assigned < b.available && _remaining > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── FOOTER DESKTOP: CANCELAR (ESC) + CONFIRMAR (ENTER) ─────────────────────
  Widget _buildDesktopFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              _buildShortcutBadge('Esc'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _isValid ? _onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade200,
            disabledForegroundColor: Colors.grey.shade400,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_rounded, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Confirmar asignación',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              _buildShortcutBadge('Enter ↵', isPrimary: true),
            ],
          ),
        ),
      ],
    );
  }

  // ── FOOTER MÓVIL: CTA COMPLETO CON ÁREA DE PULGAR ──────────────────────────
  Widget _buildMobileFooter() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isValid ? _onConfirm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade400,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.check_rounded, size: 20),
        label: const Text(
          'Confirmar asignación',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildShortcutBadge(String label, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:
            isPrimary
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              isPrimary
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isPrimary ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}
