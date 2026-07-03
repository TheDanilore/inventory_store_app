import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class PosTotalSummarySection extends StatelessWidget {
  final double subtotalAntesDePuntos;
  final int puntosAplicables;
  final double descuentoPuntos;
  final double descuentoExtra;
  final double totalFinal;
  final double pointsToSolesRatio;
  final double earningRate;
  final bool isCredito;
  final bool isLoyaltyEnabled;

  const PosTotalSummarySection({
    super.key,
    required this.subtotalAntesDePuntos,
    required this.puntosAplicables,
    required this.descuentoPuntos,
    required this.descuentoExtra,
    required this.totalFinal,
    required this.pointsToSolesRatio,
    required this.earningRate,
    required this.isCredito,
    required this.isLoyaltyEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final puntosGanadosEstimados =
        isLoyaltyEnabled
            ? (totalFinal * earningRate / pointsToSolesRatio).toInt()
            : 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        children: [
          if (puntosAplicables > 0 || descuentoExtra > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppColors.radius),
                ),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Subtotal',
                    value: 'S/ ${subtotalAntesDePuntos.toStringAsFixed(2)}',
                  ),
                  if (puntosAplicables > 0) ...[
                    const SizedBox(height: 6),
                    _SummaryRow(
                      label: 'Monedas usadas',
                      value: '$puntosAplicables monedas',
                      valueColor: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    _SummaryRow(
                      label: 'Descuento monedas',
                      value: '- S/ ${descuentoPuntos.toStringAsFixed(2)}',
                      valueColor: AppColors.success,
                      isBold: true,
                    ),
                  ],
                  if (descuentoExtra > 0) ...[
                    const SizedBox(height: 6),
                    _SummaryRow(
                      label: 'Descuento aplicado',
                      value: '- S/ ${descuentoExtra.toStringAsFixed(2)}',
                      valueColor: AppColors.success,
                      isBold: true,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _SummaryRow(
                    label: 'Tasa de acumulación',
                    value: '${(earningRate * 100).toStringAsFixed(1)}%',
                    valueColor: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isCredito
                        ? [
                          Colors.deepOrange.shade600,
                          Colors.deepOrange.shade800,
                        ]
                        : const [Color(0xFF0D9488), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  puntosAplicables > 0
                      ? const BorderRadius.vertical(
                        bottom: Radius.circular(AppColors.radius),
                      )
                      : BorderRadius.circular(AppColors.radius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCredito ? 'TOTAL A CRÉDITO' : 'TOTAL A PAGAR',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCredito
                          ? 'Se cargará a la deuda del cliente'
                          : 'Incluye todos los descuentos',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                    if (!isCredito && puntosGanadosEstimados > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+$puntosGanadosEstimados monedas al cliente',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  'S/ ${totalFinal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class PosConfirmButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final String label;
  final VoidCallback? onPressed;

  const PosConfirmButton({
    super.key,
    required this.loading,
    required this.enabled,
    required this.onPressed,
    this.label = 'Confirmar venta',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (enabled && !loading) ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient:
              (enabled && !loading)
                  ? const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: (!enabled || loading) ? AppColors.border : null,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow:
              (enabled && !loading)
                  ? [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              Icon(
                Icons.check_circle_rounded,
                color: enabled ? Colors.white : AppColors.textMuted,
                size: 20,
              ),
            const SizedBox(width: 10),
            Text(
              loading ? 'Procesando…' : label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.white : AppColors.textMuted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
