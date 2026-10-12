import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. DASHBOARD KPI STRIP CARD (APPLE HIG / SHOPEERS UNIFORM METRIC CARD)
// ─────────────────────────────────────────────────────────────────────────────
class DashboardKpiStripCard extends StatefulWidget {
  final String title;
  final String value;
  final String deltaText;
  final bool isPositiveDelta;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const DashboardKpiStripCard({
    super.key,
    required this.title,
    required this.value,
    required this.deltaText,
    this.isPositiveDelta = true,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  State<DashboardKpiStripCard> createState() => _DashboardKpiStripCardState();
}

class _DashboardKpiStripCardState extends State<DashboardKpiStripCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor:
          widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  _isHovered
                      ? widget.accentColor.withValues(alpha: 0.45)
                      : (isDark
                          ? AppColors.darkBorder
                          : const Color(0xFFE2E8F0)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    _isHovered
                        ? widget.accentColor.withValues(alpha: 0.12)
                        : (isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.03)),
                blurRadius: _isHovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: Title and Icon Container
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(
                        alpha: isDark ? 0.2 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: widget.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Main Metric Value (Dedicated full width row -> NEVER truncated)
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                  letterSpacing: -0.6,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Bottom Row: Delta Pill + Subtitle
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          widget.isPositiveDelta
                              ? (isDark
                                  ? const Color(
                                    0xFF064E3B,
                                  ).withValues(alpha: 0.6)
                                  : const Color(0xFFDCFCE7))
                              : (isDark
                                  ? const Color(
                                    0xFF881337,
                                  ).withValues(alpha: 0.6)
                                  : const Color(0xFFFFE4E6)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isPositiveDelta
                              ? Icons.arrow_drop_up_rounded
                              : Icons.arrow_drop_down_rounded,
                          size: 15,
                          color:
                              widget.isPositiveDelta
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFE11D48),
                        ),
                        Text(
                          widget.deltaText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color:
                                widget.isPositiveDelta
                                    ? (isDark
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFF15803D))
                                    : (isDark
                                        ? const Color(0xFFFB7185)
                                        : const Color(0xFFBE123C)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTE REUTILIZABLE: MENÚ DE OPCIONES CONTEXTUALES DE TARJETA
// ─────────────────────────────────────────────────────────────────────────────
class DashboardCardOptionsMenu extends StatelessWidget {
  final String title;
  final VoidCallback onHide;

  const DashboardCardOptionsMenu({
    super.key,
    required this.title,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Opciones de $title',
      icon: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          size: 16,
          color: Color(0xFF64748B),
        ),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 150),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      onSelected: (val) {
        if (val == 'hide') onHide();
      },
      itemBuilder:
          (ctx) => [
            const PopupMenuItem(
              value: 'hide',
              height: 38,
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 16,
                    color: Color(0xFFE11D48),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Ocultar widget',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ),
          ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. DASHBOARD SPLINE REVENUE CHART CARD (SHOPEERS TOTAL PROFIT CURVE)
// ─────────────────────────────────────────────────────────────────────────────
class DashboardSplineChartCard extends StatefulWidget {
  final SalesMetricsEntity sales;
  final InventoryMetricsEntity inventory;
  final VoidCallback? onHide;

  const DashboardSplineChartCard({
    super.key,
    required this.sales,
    required this.inventory,
    this.onHide,
  });

  @override
  State<DashboardSplineChartCard> createState() =>
      _DashboardSplineChartCardState();
}

class _DashboardSplineChartCardState extends State<DashboardSplineChartCard> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final revenue = widget.sales.totalRevenue;
    final totalSales = widget.sales.totalSales;

    final dataPoints =
        widget.sales.revenueTrendPoints.isNotEmpty
            ? widget.sales.revenueTrendPoints
            : (revenue > 0
                ? [
                  revenue * 0.15,
                  revenue * 0.28,
                  revenue * 0.42,
                  revenue * 0.58,
                  revenue * 0.72,
                  revenue * 0.88,
                  revenue,
                ]
                : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

    final dates = [
      '1 Ene',
      '6 Ene',
      '12 Ene',
      '18 Ene',
      '24 Ene',
      '28 Ene',
      '31 Ene',
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Adaptativo móvil / escritorio sin desborde
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobileHeader = constraints.maxWidth < 580;

              final liveBadge = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                          : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isDark
                            ? const Color(0xFF1E40AF).withValues(alpha: 0.5)
                            : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.insights_rounded,
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'En Tiempo Real',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              );

              final deltaPill = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.6)
                          : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_drop_up_rounded,
                      size: 16,
                      color: Color(0xFF16A34A),
                    ),
                    Text(
                      '▲ 24.4% vs anterior',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              );

              if (isMobileHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ingresos & Ganancia Total',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        liveBadge,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'S/ ${revenue.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A),
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                        deltaPill,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ingresos & Ganancia Total',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'S/ ${revenue.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      isDark
                                          ? AppColors.darkTextPrimary
                                          : const Color(0xFF0F172A),
                                  letterSpacing: -0.7,
                                ),
                              ),
                            ),
                            deltaPill,
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  liveBadge,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Spline Interactive Curve Canvas
          SizedBox(
            height: 190,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return MouseRegion(
                  onHover: (event) {
                    final width = constraints.maxWidth;
                    final step = width / (dataPoints.length - 1);
                    final index = (event.localPosition.dx / step).round().clamp(
                      0,
                      dataPoints.length - 1,
                    );
                    if (_hoveredIndex != index) {
                      setState(() => _hoveredIndex = index);
                    }
                  },
                  onExit: (_) => setState(() => _hoveredIndex = null),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(constraints.maxWidth, 160),
                        painter: _SplineAreaChartPainter(
                          points: dataPoints,
                          hoveredIndex: _hoveredIndex,
                        ),
                      ),

                      // Floating Apple-style Tooltip on hover
                      if (_hoveredIndex != null)
                        Positioned(
                          left: (_hoveredIndex! *
                                  (constraints.maxWidth /
                                      (dataPoints.length - 1)))
                              .clamp(20.0, constraints.maxWidth - 140),
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dates[_hoveredIndex!],
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'S/ ${dataPoints[_hoveredIndex!].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Timeline X-Axis Labels
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children:
                              dates.map((d) {
                                return Text(
                                  d,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF94A3B8),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Bottom Segmented Breakdown Strip (Adaptativo sin desbordes)
          LayoutBuilder(
            builder: (context, bConstraints) {
              final isCompact = bConstraints.maxWidth < 460;

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppColors.darkSurfaceElevated
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildBreakdownItem(
                        color: const Color(0xFF2563EB),
                        label: isCompact ? 'Ventas' : 'Ventas Realizadas',
                        value:
                            isCompact
                                ? '$totalSales transac.'
                                : '$totalSales transacciones',
                        isDark: isDark,
                        isCompact: isCompact,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      margin: EdgeInsets.symmetric(
                        horizontal: isCompact ? 4 : 8,
                      ),
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                    Expanded(
                      child: _buildBreakdownItem(
                        color: const Color(0xFF10B981),
                        label: isCompact ? 'Ganancia' : 'Ganancia Bruta',
                        value:
                            'S/ ${widget.sales.totalProfit.toStringAsFixed(2)}',
                        isDark: isDark,
                        isCompact: isCompact,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      margin: EdgeInsets.symmetric(
                        horizontal: isCompact ? 4 : 8,
                      ),
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                    Expanded(
                      child: _buildBreakdownItem(
                        color: const Color(0xFFF59E0B),
                        label: isCompact ? 'Reposición' : 'Fondo Reposición',
                        value:
                            'S/ ${widget.sales.replacementFund.toStringAsFixed(2)}',
                        isDark: isDark,
                        isCompact: isCompact,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem({
    required Color color,
    required String label,
    required String value,
    required bool isDark,
    bool isCompact = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCompact ? 6 : 8,
          height: isCompact ? 6 : 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: isCompact ? 5 : 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isCompact ? 10 : 11,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplineAreaChartPainter extends CustomPainter {
  final List<double> points;
  final int? hoveredIndex;

  _SplineAreaChartPainter({required this.points, required this.hoveredIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxVal = points.reduce(math.max) * 1.15;
    final minVal = points.reduce(math.min) * 0.85;
    final range = maxVal - minVal > 0 ? maxVal - minVal : 1.0;

    // Draw horizontal dashed grid lines
    final gridPaint =
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final double step = size.width / (points.length - 1);
    final List<Offset> offsets = [];

    for (int i = 0; i < points.length; i++) {
      final x = i * step;
      final normalized = (points[i] - minVal) / range;
      final y = size.height - (normalized * size.height);
      offsets.add(Offset(x, y));
    }

    // Build smooth Cubic Bézier Spline path
    final path = Path();
    path.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // Area Gradient Fill below the spline
    final areaPath =
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();

    final fillPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF3B82F6).withValues(alpha: 0.22),
              const Color(0xFF3B82F6).withValues(alpha: 0.00),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, fillPaint);

    // Spline Line Stroke
    final linePaint =
        Paint()
          ..color = const Color(0xFF2563EB)
          ..strokeWidth = 2.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw interactive points
    for (int i = 0; i < offsets.length; i++) {
      final isHovered = hoveredIndex == i;
      final point = offsets[i];

      if (isHovered) {
        // Outer glow on hover
        canvas.drawCircle(
          point,
          7,
          Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.25),
        );
      }

      // Inner dot
      canvas.drawCircle(
        point,
        isHovered ? 4.5 : 3.0,
        Paint()..color = isHovered ? const Color(0xFF2563EB) : Colors.white,
      );
      canvas.drawCircle(
        point,
        isHovered ? 4.5 : 3.0,
        Paint()
          ..color = const Color(0xFF2563EB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplineAreaChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. DASHBOARD WEEKLY ACTIVITY BAR CARD (SHOPEERS MOST DAY ACTIVE)
// ─────────────────────────────────────────────────────────────────────────────
class DashboardWeeklyActivityCard extends StatelessWidget {
  final SalesMetricsEntity? sales;
  final VoidCallback? onHide;

  const DashboardWeeklyActivityCard({super.key, this.sales, this.onHide});

  @override
  Widget build(BuildContext context) {
    final days =
        (sales != null && sales!.weeklyActivity.isNotEmpty)
            ? sales!.weeklyActivity
            : [
              {'day': 'Dom', 'val': 0.0, 'orders': 0, 'active': false},
              {'day': 'Lun', 'val': 0.0, 'orders': 0, 'active': false},
              {'day': 'Mar', 'val': 0.0, 'orders': 0, 'active': false},
              {'day': 'Mié', 'val': 0.0, 'orders': 0, 'active': false},
              {'day': 'Jue', 'val': 0.0, 'orders': 0, 'active': false},
              {'day': 'Vie', 'val': 0.0, 'orders': 0, 'active': false},
              {'day': 'Sáb', 'val': 0.0, 'orders': 0, 'active': false},
            ];

    double maxVal = 1.0;
    for (var d in days) {
      final v = (d['val'] as num?)?.toDouble() ?? 0.0;
      if (v > maxVal) maxVal = v;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
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
              Text(
                'Actividad Semanal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                              : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sales?.peakDayLabel ?? 'Semana activa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart Row
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children:
                  days.map((item) {
                    final double val = (item['val'] as num).toDouble();
                    final bool isActive = item['active'] as bool;
                    final double heightRatio = (val / maxVal).clamp(0.15, 1.0);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isActive && val > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              val >= 1000
                                  ? '${(val / 1000).toStringAsFixed(1)}k'
                                  : val.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 20),

                        // Bar Capsule
                        Container(
                          width: 22,
                          height: 90 * heightRatio,
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? const Color(0xFF2563EB)
                                    : (isDark
                                        ? AppColors.darkSurfaceElevated
                                        : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          item['day'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color:
                                isActive
                                    ? (isDark
                                        ? AppColors.darkTextPrimary
                                        : const Color(0xFF2563EB))
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. DASHBOARD APPLE FITNESS RADIAL GOAL GAUGE CARD
// ─────────────────────────────────────────────────────────────────────────────
class DashboardRadialGoalCard extends StatelessWidget {
  final double currentAmount;
  final double targetAmount;
  final VoidCallback onConfigure;
  final VoidCallback? onHide;

  const DashboardRadialGoalCard({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
    required this.onConfigure,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress =
        targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();
    final remaining = (targetAmount - currentAmount).clamp(
      0.0,
      double.infinity,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
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
              Text(
                'Cumplimiento de Meta',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: onConfigure,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ajustar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Semicircle / Radial Activity Ring Gauge
          Center(
            child: SizedBox(
              width: 140,
              height: 100,
              child: CustomPaint(
                painter: _AppleRadialGaugePainter(
                  progress: progress,
                  isDark: isDark,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percent%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : const Color(0xFF0F172A),
                            letterSpacing: -0.6,
                          ),
                        ),
                        const Text(
                          'alcanzado',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Targets Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppColors.darkSurfaceElevated
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actual',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'S/ ${currentAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Restante',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'S/ ${remaining.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB),
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

class _AppleRadialGaugePainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _AppleRadialGaugePainter({required this.progress, this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 8;

    // Track arc
    final trackPaint =
        Paint()
          ..color = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      trackPaint,
    );

    // Progress arc
    final progressPaint =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF38BDF8), Color(0xFF2563EB), Color(0xFF10B981)],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AppleRadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. DASHBOARD AI ASSISTANT CARD (SHOPEERS GLOW SPHERE & PROMPT BAR)
// ─────────────────────────────────────────────────────────────────────────────
class DashboardAiAssistantCard extends StatelessWidget {
  final VoidCallback? onQuerySubmit;
  final VoidCallback? onHide;

  const DashboardAiAssistantCard({super.key, this.onQuerySubmit, this.onHide});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Asistente ERP Inteligente',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                              : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'IA Beta',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3D Illuminated Sphere with Aura
          Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  radius: 0.85,
                  colors: [
                    Color(0xFF60A5FA),
                    Color(0xFF2563EB),
                    Color(0xFF1E3A8A),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
                    blurRadius: 22,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Prompt Input Field
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppColors.darkSurfaceElevated
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preguntar al ERP sobre stock o ventas...',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    size: 14,
                    color: Colors.white,
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

// ─────────────────────────────────────────────────────────────────────────────
// 6. DASHBOARD BEST SELLING PRODUCTS TABLE (SHOPEERS DATA TABLE PRO)
// ─────────────────────────────────────────────────────────────────────────────
class DashboardBestSellersTable extends StatefulWidget {
  final List<Map<String, dynamic>>? bestSellers;
  final List<Map<String, dynamic>> criticalBatches;
  final VoidCallback? onHide;

  const DashboardBestSellersTable({
    super.key,
    this.bestSellers,
    required this.criticalBatches,
    this.onHide,
  });

  @override
  State<DashboardBestSellersTable> createState() =>
      _DashboardBestSellersTableState();
}

class _DashboardBestSellersTableState extends State<DashboardBestSellersTable> {
  int? _hoveredRank;

  Widget _buildProductThumbnail({
    required String? imageUrl,
    double size = 32,
    bool isDark = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          imageUrl != null && imageUrl.trim().isNotEmpty
              ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color:
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: size * 0.45,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color:
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: size * 0.45,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
              )
              : Container(
                color:
                    isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                alignment: Alignment.center,
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: size * 0.45,
                  color: const Color(0xFF94A3B8),
                ),
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products =
        (widget.bestSellers != null && widget.bestSellers!.isNotEmpty)
            ? widget.bestSellers!
            : <Map<String, dynamic>>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow:
                isDark
                    ? []
                    : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Productos con Mayor Rotación',
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 16,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark
                                    ? const Color(0xFFF8FAFC)
                                    : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Artículos más despachados y rendimiento financiero',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (products.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 16,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF94A3B8),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sin ventas en este período',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registra ventas en el POS para ver la rotación de artículos en tiempo real.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isMobile)
                // ── VISTA MÓVIL: APPLE HIG / SHOPEERS LIST CARDS ──────────
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder:
                      (context, index) => Divider(
                        height: 1,
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFF1F5F9),
                      ),
                  itemBuilder: (context, index) {
                    final p = products[index];

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        hoverColor:
                            isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.primaryLight.withValues(
                                  alpha: 0.45,
                                ),
                        onTap: () {
                          final prodId = p['productId'] as String?;
                          if (prodId != null && prodId.isNotEmpty) {
                            context.go('/product/$prodId');
                          } else {
                            context.go('/inventory');
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          child: Row(
                            children: [
                              _buildProductThumbnail(
                                imageUrl: p['imageUrl'] as String?,
                                size: 38,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['name'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            isDark
                                                ? const Color(0xFFF8FAFC)
                                                : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          p['category'] as String,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '•',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                isDark
                                                    ? const Color(0xFF475569)
                                                    : const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          p['sold'] as String,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    p['revenue'] as String,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ((p['statusColor'] is Color
                                              ? p['statusColor'] as Color
                                              : (p['status'] == 'Alta Rotación'
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFF2563EB))))
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      p['status'] as String,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            (p['statusColor'] is Color
                                                ? p['statusColor'] as Color
                                                : (p['status'] ==
                                                        'Alta Rotación'
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(0xFF2563EB))),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                )
              else ...[
                // ── VISTA DESKTOP: TABLA PRO CON HOVER INTERACTIVO Y ENCABEZADOS ──
                MouseRegion(
                  onExit: (_) {
                    if (_hoveredRank != null) {
                      setState(() => _hoveredRank = null);
                    }
                  },
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? AppColors.darkSurfaceElevated
                                  : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                '#',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                'CÓDIGO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'NOMBRE DEL PRODUCTO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'DESPACHADOS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'FACTURACIÓN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                'ESTADO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 24),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Table Rows con hover reactivo idéntico a TopCustomersCard
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        separatorBuilder:
                            (context, index) => Divider(
                              height: 1,
                              color:
                                  isDark
                                      ? AppColors.darkBorder
                                      : const Color(0xFFF1F5F9),
                            ),
                        itemBuilder: (context, index) {
                          final p = products[index];
                          final rank = index + 1;
                          final isHovered = _hoveredRank == rank;

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) {
                              if (_hoveredRank != rank) {
                                setState(() => _hoveredRank = rank);
                              }
                            },
                            child: GestureDetector(
                              onTap: () {
                                final prodId = p['productId'] as String?;
                                if (prodId != null && prodId.isNotEmpty) {
                                  context.go('/product/$prodId');
                                } else {
                                  context.go('/inventory');
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      isHovered
                                          ? (isDark
                                              ? AppColors.darkSurfaceElevated
                                              : AppColors.primaryLight.withValues(
                                                alpha: 0.45,
                                              ))
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    // Rank
                                    SizedBox(
                                      width: 44,
                                      child: Row(
                                        children: [
                                          if (rank <= 3) ...[
                                            Icon(
                                              Icons.workspace_premium_rounded,
                                              size: 16,
                                              color:
                                                  rank == 1
                                                      ? const Color(0xFFF59E0B)
                                                      : rank == 2
                                                      ? const Color(0xFF64748B)
                                                      : const Color(0xFFB45309),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            '$rank',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color:
                                                  rank == 1
                                                      ? const Color(0xFFF59E0B)
                                                      : rank == 2
                                                      ? const Color(0xFF64748B)
                                                      : rank == 3
                                                      ? const Color(0xFFB45309)
                                                      : (isDark
                                                          ? const Color(0xFF94A3B8)
                                                          : const Color(0xFF64748B)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Código
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        p['id'] as String,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),

                                    // Thumbnail + Nombre
                                    Expanded(
                                      flex: 4,
                                      child: Row(
                                        children: [
                                          _buildProductThumbnail(
                                            imageUrl: p['imageUrl'] as String?,
                                            size: 32,
                                            isDark: isDark,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              p['name'] as String,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isDark
                                                        ? const Color(0xFFF8FAFC)
                                                        : const Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Despachados
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        p['sold'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),

                                    // Facturación
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        p['revenue'] as String,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ),

                                    // Estado
                                    SizedBox(
                                      width: 100,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ((p['statusColor'] is Color
                                                  ? p['statusColor'] as Color
                                                  : (p['status'] == 'Alta Rotación'
                                                      ? const Color(0xFF16A34A)
                                                      : const Color(0xFF2563EB))))
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          p['status'] as String,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                (p['statusColor'] is Color
                                                    ? p['statusColor'] as Color
                                                    : (p['status'] == 'Alta Rotación'
                                                        ? const Color(0xFF16A34A)
                                                        : const Color(0xFF2563EB))),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color:
                                          isDark
                                              ? const Color(0xFF64748B)
                                              : const Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
