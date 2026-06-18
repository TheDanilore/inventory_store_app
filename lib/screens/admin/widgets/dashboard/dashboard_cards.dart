import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

/// Anima un valor numérico desde 0 hasta [value] cuando el widget aparece
/// o cuando [value] cambia. [formatter] decide cómo se muestra el número
/// en cada frame de la animación (ej. con prefijo "S/" o sufijo "%").
class AnimatedCounter extends StatelessWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(formatter(animatedValue), style: style);
      },
    );
  }
}

/// Anima la parte numérica de un texto ya formateado (ej. "S/ 1,234.56",
/// "45", "12.5%"), preservando el prefijo, sufijo y precisión decimal
/// originales. Si el texto no contiene un número parseable, se muestra
/// estático sin animar (fallback seguro).
class AnimatedNumericText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Duration duration;

  const AnimatedNumericText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.duration = const Duration(milliseconds: 700),
  });

  static final _numberPattern = RegExp(r'[\d,]+\.?\d*');

  @override
  Widget build(BuildContext context) {
    final match = _numberPattern.firstMatch(text);
    if (match == null) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final numericStr = match.group(0)!;
    final cleanNumber = numericStr.replaceAll(',', '');
    final value = double.tryParse(cleanNumber);
    if (value == null) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final prefix = text.substring(0, match.start);
    final suffix = text.substring(match.end);
    final decimals =
        cleanNumber.contains('.') ? cleanNumber.split('.').last.length : 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        final formatted = animatedValue.toStringAsFixed(decimals);
        return Text(
          '$prefix$formatted$suffix',
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}

class SubSectionLabel extends StatelessWidget {
  final String label;
  const SubSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.teal,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final String? badge;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = gradient.colors.first;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: baseColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              if (badge != null)
                Semantics(
                  label: 'Alerta',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: baseColor.withValues(alpha: 0.4),
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label: '$title: $value, $subtitle',
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedNumericText(
                text: value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: baseColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return BounceScale(onTap: onTap!, child: card);
  }
}

class KpiCardWide extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String rightLabel;
  final String rightValue;
  final Color? rightColor;

  const KpiCardWide({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.rightLabel,
    required this.rightValue,
    this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sparkline background
          Positioned(
            right: -20,
            bottom: 0,
            left: 50,
            height: 50,
            child: Opacity(
              opacity: 0.3,
              child: CustomPaint(
                painter: _SparklinePainter(color, [
                  1.2,
                  1.0,
                  1.8,
                  1.5,
                  2.5,
                  2.1,
                  3.2,
                  2.8,
                  3.8,
                  4.2,
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Semantics(
                        label: '$title: $value, $subtitle',
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedNumericText(
                            text: value,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 50,
                  width: 1.5,
                  color: color.withValues(alpha: 0.15),
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rightLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      label: '$rightLabel: $rightValue',
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: AnimatedNumericText(
                          text: rightValue,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: rightColor ?? color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GananciaBrutaCard extends StatelessWidget {
  final double gananciaBruta;
  final double margenPct;
  final double inversion;

  const GananciaBrutaCard({
    super.key,
    required this.gananciaBruta,
    required this.margenPct,
    required this.inversion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sparkline en el fondo
          Positioned(
            right: -20,
            bottom: 0,
            left: 50,
            height: 60,
            child: Opacity(
              opacity: 0.4,
              child: CustomPaint(
                painter: _SparklinePainter(AppColors.success, [
                  1.0,
                  1.5,
                  1.2,
                  2.0,
                  2.8,
                  2.4,
                  3.5,
                  4.0,
                  3.8,
                  5.0,
                ]),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.price_check_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'GANANCIA BRUTA',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'vs precio de compra',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Semantics(
                    label:
                        'Ganancia bruta: S/ ${gananciaBruta.toStringAsFixed(2)}',
                    child: AnimatedCounter(
                      value: gananciaBruta,
                      formatter: (v) => 'S/ ${v.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Inversión total: S/ ${inversion.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Margen Bruto Global',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label:
                        'Margen bruto: ${margenPct.toStringAsFixed(1)} por ciento',
                    child: AnimatedCounter(
                      value: margenPct,
                      formatter: (v) => '${v.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: (margenPct / 100).clamp(0.0, 1.0),
                  ),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedValue, _) {
                    return LinearProgressIndicator(
                      value: animatedValue,
                      minHeight: 8,
                      backgroundColor: AppColors.success.withValues(
                        alpha: 0.15,
                      ),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.success,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MargenBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;

  const MargenBar({
    super.key,
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.percent_rounded, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Semantics(
                label: '$label: ${percent.toStringAsFixed(1)} por ciento',
                child: AnimatedCounter(
                  value: percent,
                  formatter: (v) => '${v.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (percent / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, _) {
                return LinearProgressIndicator(
                  value: animatedValue,
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ExpiringBatchesCard extends StatefulWidget {
  final List<Map<String, dynamic>> batches;
  const ExpiringBatchesCard({super.key, required this.batches});

  @override
  State<ExpiringBatchesCard> createState() => _ExpiringBatchesCardState();
}

class _ExpiringBatchesCardState extends State<ExpiringBatchesCard> {
  bool _expanded = false;

  String _daysLabel(String? expiryDateStr) {
    if (expiryDateStr == null) return '';
    final expiry = DateTime.tryParse(expiryDateStr);
    if (expiry == null) return '';
    final diff = expiry.difference(DateTime.now()).inDays;
    if (diff == 0) return 'Vence hoy';
    if (diff == 1) return 'Vence mañana';
    return 'Vence en $diff días';
  }

  Color _urgencyColor(String? expiryDateStr) {
    if (expiryDateStr == null) return AppColors.warning;
    final expiry = DateTime.tryParse(expiryDateStr);
    if (expiry == null) return AppColors.warning;
    final diff = expiry.difference(DateTime.now()).inDays;
    if (diff <= 7) return AppColors.danger;
    if (diff <= 15) return AppColors.warning;
    return Colors.orange.shade400;
  }

  // Complementa el color con un ícono distinto por nivel de urgencia,
  // para que la información no dependa solo del canal de color
  // (importante para usuarios con daltonismo rojo-verde/naranja).
  IconData _urgencyIcon(String? expiryDateStr) {
    if (expiryDateStr == null) return Icons.help_outline_rounded;
    final expiry = DateTime.tryParse(expiryDateStr);
    if (expiry == null) return Icons.help_outline_rounded;
    final diff = expiry.difference(DateTime.now()).inDays;
    if (diff <= 7) return Icons.error_rounded;
    if (diff <= 15) return Icons.warning_rounded;
    return Icons.schedule_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final batches = widget.batches;
    final criticalCount =
        batches.where((b) {
          final expiry = DateTime.tryParse(b['expiry_date'] ?? '');
          return expiry != null &&
              expiry.difference(DateTime.now()).inDays <= 7;
        }).length;

    final visibleBatches = _expanded ? batches : batches.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BounceScale(
            onTap: () {
              // Redirigir al inventario o expandir
              setState(() => _expanded = !_expanded);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lotes Próximos a Vencer',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.danger,
                          ),
                        ),
                        Text(
                          '${batches.length} lote${batches.length != 1 ? "s" : ""} en próximos 30 días'
                          '${criticalCount > 0 ? " · $criticalCount crítico${criticalCount != 1 ? "s" : ""}" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${batches.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...visibleBatches.map((batch) {
            final productName =
                (batch['products'] as Map?)?['name'] as String? ?? '–';
            final warehouseName =
                (batch['warehouses'] as Map?)?['name'] as String? ?? '–';
            final variantData =
                batch['product_variants'] as Map<String, dynamic>?;
            final sku = variantData?['sku'] as String?;
            final batchNumber = batch['batch_number'] as String? ?? '–';
            final qty = (batch['available_quantity'] as num?)?.toInt() ?? 0;
            final expiryStr = batch['expiry_date'] as String?;
            final urgencyColor = _urgencyColor(expiryStr);
            final daysLabel = _daysLabel(expiryStr);

            final vavList =
                variantData?['variant_attribute_values'] as List<dynamic>? ??
                [];
            final List<String> attrValues = [];
            for (var vav in vavList) {
              final av = vav['attribute_values'] as Map<String, dynamic>?;
              if (av != null && av['value'] != null) {
                attrValues.add(av['value'].toString());
              }
            }
            final attrsDesc = attrValues.join(' · ');
            final urgencyIcon = _urgencyIcon(expiryStr);

            final detailLine = [
              if (attrsDesc.isNotEmpty) attrsDesc,
              if (sku != null && sku.isNotEmpty) 'SKU: $sku',
              'Lote: $batchNumber',
              warehouseName,
            ].join(' · ');

            return Tooltip(
              message: '$productName\n$detailLine\n$daysLabel · $qty uds.',
              triggerMode: TooltipTriggerMode.longPress,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: urgencyColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: urgencyColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            detailLine,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(urgencyIcon, color: urgencyColor, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                daysLabel,
                                style: TextStyle(
                                  color: urgencyColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$qty uds.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          if (batches.length > 3)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Ver menos' : 'Ver ${batches.length - 3} más...',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class AdminGoalCard extends StatelessWidget {
  final double currentAmount;
  final double targetAmount;
  final VoidCallback? onAddPressed;

  const AdminGoalCard({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final rawProgress = targetAmount > 0 ? (currentAmount / targetAmount) : 0.0;
    final progress = rawProgress.clamp(0.0, 1.0);
    final remainingAmount = (targetAmount - currentAmount).clamp(
      0.0,
      double.infinity,
    );
    final hasReachedGoal = currentAmount >= targetAmount && targetAmount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, animatedProgress, _) {
                final animatedPercentage =
                    (animatedProgress * 100).clamp(0, 100).toInt();
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: animatedProgress,
                      strokeWidth: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        hasReachedGoal
                            ? Colors.greenAccent.shade400
                            : Colors.amber.shade400,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '$animatedPercentage%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'MI META DE AHORRO',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Semantics(
                  label:
                      'Ahorro actual: S/ ${currentAmount.toStringAsFixed(2)} de S/ ${targetAmount.toStringAsFixed(2)}',
                  child: AnimatedCounter(
                    value: currentAmount,
                    formatter: (v) => 'S/ ${v.toStringAsFixed(2)}',
                    duration: const Duration(milliseconds: 800),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
                Text(
                  'de S/ ${targetAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  hasReachedGoal
                      ? '🎉 ¡Meta cumplida! Excelente trabajo.'
                      : 'Faltan S/ ${remainingAmount.toStringAsFixed(2)} para tu meta',
                  style: TextStyle(
                    color:
                        hasReachedGoal
                            ? Colors.greenAccent.shade100
                            : Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message:
                onAddPressed == null
                    ? 'Configura esta acción para abonar a la meta.'
                    : 'Configurar Meta',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: onAddPressed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BounceScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BounceScale({super.key, required this.child, required this.onTap});

  @override
  State<BounceScale> createState() => _BounceScaleState();
}

class _BounceScaleState extends State<BounceScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  final List<double> data;
  _SparklinePainter(this.color, this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final maxData = data.reduce((a, b) => a > b ? a : b);
    final minData = data.reduce((a, b) => a < b ? a : b);
    final range = (maxData - minData) == 0 ? 1 : (maxData - minData);

    final stepX = size.width / (data.length - 1);
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      // padding superior e inferior virtual (10%)
      final y =
          size.height * 0.9 -
          ((data[i] - minData) / range) * (size.height * 0.8);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Curve to make it smoother
        final prevX = (i - 1) * stepX;
        final prevY =
            size.height * 0.9 -
            ((data[i - 1] - minData) / range) * (size.height * 0.8);
        final cpX = (x + prevX) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    final fillPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath =
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => false;
}
