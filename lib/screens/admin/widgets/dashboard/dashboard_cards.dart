import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

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

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              if (badge != null)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: gradient.colors.last,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            height: 44,
            width: 1,
            color: color.withValues(alpha: 0.2),
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rightLabel,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                rightValue,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: rightColor ?? color,
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.tealDark, AppColors.success],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.price_check_rounded,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'GANANCIA BRUTA',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'vs precio de compra',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ${gananciaBruta.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Inversión: S/ ${inversion.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Margen Bruto',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${margenPct.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (margenPct / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.greenAccent,
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.percent_rounded, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade900.withValues(alpha: 0.15),
            Colors.red.shade900.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.4),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
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
                        '${batches.length} lote${batches.length != 1 ? "s" : ""} en los próximos 30 días'
                        '${criticalCount > 0 ? " · $criticalCount crítico${criticalCount != 1 ? "s" : ""}" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.danger.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
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
              ],
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

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: urgencyColor.withValues(alpha: 0.25)),
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
                          [
                            if (attrsDesc.isNotEmpty) attrsDesc,
                            if (sku != null && sku.isNotEmpty) 'SKU: $sku',
                            'Lote: $batchNumber',
                            warehouseName,
                          ].join(' · '),
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
                        child: Text(
                          daysLabel,
                          style: TextStyle(
                            color: urgencyColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
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
            );
          }),
          if (batches.length > 3)
            TextButton(
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
    final int percentage = (rawProgress * 100).clamp(0, 100).toInt();
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
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
                    '$percentage%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
                Text(
                  'S/ ${currentAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                Text(
                  'de S/ ${targetAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
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
                            : Colors.white.withValues(alpha: 0.8),
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
