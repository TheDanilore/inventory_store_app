// ─── COMPACT SMART POINTS SECTION ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class AdminSalePointsSection extends StatefulWidget {
  final bool show;
  final int saldoActualCliente;
  final int maxPuntosAplicables;
  final double pointsToSolesRatio;
  final TextEditingController pointsController;
  final ValueChanged<int> onPointsChanged;

  const AdminSalePointsSection({
    super.key,
    required this.show,
    required this.saldoActualCliente,
    required this.maxPuntosAplicables,
    required this.pointsToSolesRatio,
    required this.pointsController,
    required this.onPointsChanged,
  });

  @override
  State<AdminSalePointsSection> createState() => _AdminSalePointsSectionState();
}

class _AdminSalePointsSectionState extends State<AdminSalePointsSection> {
  bool _isCustomExpanded = false;

  int get _currentPoints => int.tryParse(widget.pointsController.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    if (!widget.show || widget.saldoActualCliente <= 0) {
      return const SizedBox.shrink();
    }

    final maxDiscount = widget.maxPuntosAplicables * widget.pointsToSolesRatio;
    final currentDiscount = _currentPoints * widget.pointsToSolesRatio;
    final isApplied = _currentPoints > 0;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isApplied ? const Color(0xFFFEF3C7) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isApplied ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A),
            width: isApplied ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── BARRA COMPACTA PRINCIPAL (44px) ──────────────────────────────
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isApplied ? AppColors.amber : AppColors.amberLight,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.stars_rounded,
                    size: 16,
                    color: isApplied ? Colors.white : AppColors.amberDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            isApplied
                                ? 'Canjeando $_currentPoints pts'
                                : 'Puntos: ${widget.saldoActualCliente} disp.',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.amberDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Text(
                              isApplied
                                  ? '-S/ ${currentDiscount.toStringAsFixed(2)}'
                                  : 'Máx -S/ ${maxDiscount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    isApplied
                                        ? Colors.green.shade800
                                        : AppColors.amberDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isApplied
                            ? 'Descuento aplicado al total'
                            : 'Aplica hasta ${widget.maxPuntosAplicables} monedas',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botón Acción Rápida (Aplicar Todo / Quitar)
                if (!isApplied) ...[
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amberDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed:
                        widget.maxPuntosAplicables > 0
                            ? () {
                              widget.onPointsChanged(
                                widget.maxPuntosAplicables,
                              );
                              widget.pointsController.text =
                                  widget.maxPuntosAplicables.toString();
                              setState(() {});
                            }
                            : null,
                    child: Text(
                      'Canjear máx',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else ...[
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () {
                      widget.onPointsChanged(0);
                      widget.pointsController.text = '0';
                      setState(() {});
                    },
                    child: const Text(
                      'Quitar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                // Toggle de personalización
                IconButton(
                  icon: Icon(
                    _isCustomExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.tune_rounded,
                    size: 16,
                    color: AppColors.amberDark,
                  ),
                  tooltip:
                      _isCustomExpanded
                          ? 'Ocultar ajuste manual'
                          : 'Ajustar cantidad exacta',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: () {
                    setState(() => _isCustomExpanded = !_isCustomExpanded);
                  },
                ),
              ],
            ),

            // ── AJUSTE MANUAL DESPLEGABLE (OPCIONAL) ────────────────────────
            if (_isCustomExpanded) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFFDE68A)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFDE68A),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.toll_rounded,
                            size: 15,
                            color: AppColors.amber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: widget.pointsController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                suffixText: 'monedas',
                                suffixStyle: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              onChanged: (val) {
                                widget.onPointsChanged(int.tryParse(val) ?? 0);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '= S/ ${currentDiscount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.amberDark,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
