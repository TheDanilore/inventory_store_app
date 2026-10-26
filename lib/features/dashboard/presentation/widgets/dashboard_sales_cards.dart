import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_overview.dart';

const Color _kRevenue = Color(0xFF2563EB);
const Color _kProfit = Color(0xFF10B981);

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
const _monthsLong = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _daysShort = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _daysLong = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

final _moneyFmt = NumberFormat('#,##0.00', 'en_US');
String _money(double v) => 'S/ ${_moneyFmt.format(v)}';

String _compact(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

String _dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _rangeLabel(SalesOverview o) {
  if (o.from == o.to) return '${_dayMonth(o.from)} ${o.from.year}';
  final sameYear = o.from.year == o.to.year;
  final a =
      sameYear ? _dayMonth(o.from) : '${_dayMonth(o.from)} ${o.from.year}';
  return '$a – ${_dayMonth(o.to)} ${o.to.year}';
}

String _bucketLabel(SalesBucket b) =>
    b == SalesBucket.day
        ? 'por día'
        : (b == SalesBucket.week ? 'por semana' : 'por mes');

Color _soft(BuildContext c) =>
    AppColors.isDark(c) ? AppColors.darkSurfaceElevated : AppColors.surfaceDark;

// ─────────────────────────────────────────────────────────────────────────────
// Piezas comunes
// ─────────────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : AppColors.brdSubtle(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? color : AppColors.txtSecondary(context),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DeltaBadge extends StatelessWidget {
  final double? delta;
  const _DeltaBadge(this.delta);

  @override
  Widget build(BuildContext context) {
    if (delta == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _soft(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Sin periodo anterior',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.txtSecondary(context),
          ),
        ),
      );
    }
    final up = delta! >= 0;
    final color = up ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${delta!.abs().toStringAsFixed(1)}% vs periodo anterior',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  final double height;
  const _EmptyState({required this.text, required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  size: 26,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.go('/pos'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                ),
                icon: const Icon(Icons.point_of_sale_rounded, size: 15),
                label: const Text(
                  'Registrar Venta en POS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: AppColors.cardAdaptive(context),
    child: child,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Tendencia de ingresos y ganancia (datos y fechas reales)
// ─────────────────────────────────────────────────────────────────────────────

enum _Series { both, revenue, profit }

class SalesTrendCard extends StatefulWidget {
  final SalesOverview overview;
  final VoidCallback? onHide;
  const SalesTrendCard({super.key, required this.overview, this.onHide});

  @override
  State<SalesTrendCard> createState() => _SalesTrendCardState();
}

class _SalesTrendCardState extends State<SalesTrendCard> {
  _Series _series = _Series.both;
  int? _hovered;

  SalesOverview get o => widget.overview;

  String _pointTitle(SalesTrendPoint p) {
    switch (o.bucket) {
      case SalesBucket.day:
        return '${_daysShort[p.date.weekday - 1]} ${_dayMonth(p.date)} ${p.date.year}';
      case SalesBucket.week:
        return 'Semana del ${_dayMonth(p.date)}';
      case SalesBucket.month:
        return '${_monthsLong[p.date.month - 1]} ${p.date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppColors.txtPrimary(context);
    final muted = AppColors.txtSecondary(context);
    final hasData = o.totalOrders > 0 && o.trend.isNotEmpty;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingresos y ganancia',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: txt,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_rangeLabel(o)} · ${_bucketLabel(o.bucket)}',
                      style: TextStyle(fontSize: 12.5, color: muted),
                    ),
                  ],
                ),
              ),
              if (widget.onHide != null)
                IconButton(
                  tooltip: 'Ocultar widget',
                  onPressed: widget.onHide,
                  icon: Icon(
                    Icons.visibility_off_outlined,
                    size: 18,
                    color: muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _money(o.totalRevenue),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: txt,
                ),
              ),
              _DeltaBadge(o.revenueDelta),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                label: 'Ambas',
                color: muted,
                selected: _series == _Series.both,
                onTap: () => setState(() => _series = _Series.both),
              ),
              _Pill(
                label: 'Ingresos',
                color: _kRevenue,
                selected: _series == _Series.revenue,
                onTap: () => setState(() => _series = _Series.revenue),
              ),
              _Pill(
                label: 'Ganancia',
                color: _kProfit,
                selected: _series == _Series.profit,
                onTap: () => setState(() => _series = _Series.profit),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData)
            const _EmptyState(
              text:
                  'No hay ventas en este periodo.\nPrueba con otro rango de fechas.',
              height: 220,
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final h = c.maxWidth < 520 ? 190.0 : 240.0;
                return _chart(context, c.maxWidth, h)
                    .animate()
                    .fadeIn(duration: const Duration(milliseconds: 400))
                    .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
              },
            ),
          const SizedBox(height: 16),
          _footer(context),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context, double width, double height) {
    final showRev = _series != _Series.profit;
    final showProfit = _series != _Series.revenue;
    final pts = o.trend;
    final isDark = AppColors.isDark(context);

    double maxY = 0;
    for (final p in pts) {
      if (showRev) maxY = math.max(maxY, p.revenue);
      if (showProfit) maxY = math.max(maxY, p.profit);
    }

    int? indexFor(double dx) {
      if (pts.length == 1) return 0;
      final plotW = width - _TrendPainter.left - _TrendPainter.right;
      final t = ((dx - _TrendPainter.left) / plotW).clamp(0.0, 1.0);
      return (t * (pts.length - 1)).round();
    }

    final hovered =
        _hovered != null && _hovered! < pts.length ? _hovered : null;

    return SizedBox(
      height: height,
      child: MouseRegion(
        onHover: (e) => setState(() => _hovered = indexFor(e.localPosition.dx)),
        onExit: (_) => setState(() => _hovered = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown:
              (d) => setState(() => _hovered = indexFor(d.localPosition.dx)),
          onPanUpdate:
              (d) => setState(() => _hovered = indexFor(d.localPosition.dx)),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrendPainter(
                    points: pts,
                    bucket: o.bucket,
                    showRevenue: showRev,
                    showProfit: showProfit,
                    hovered: hovered,
                    maxY: maxY,
                    gridColor: AppColors.brd(context),
                    labelColor: AppColors.txtMuted(context),
                    surface: AppColors.surf(context),
                    isDark: isDark,
                  ),
                ),
              ),
              if (hovered != null)
                _tooltip(context, width, pts[hovered], hovered),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tooltip(
    BuildContext context,
    double width,
    SalesTrendPoint p,
    int i,
  ) {
    const tipW = 190.0;
    final plotW = width - _TrendPainter.left - _TrendPainter.right;
    final x =
        o.trend.length == 1
            ? _TrendPainter.left + plotW / 2
            : _TrendPainter.left + plotW * i / (o.trend.length - 1);
    final left =
        (x - tipW / 2).clamp(0.0, math.max(0.0, width - tipW)).toDouble();
    final isDark = AppColors.isDark(context);
    Widget row(Color c, String k, String v) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(k, style: const TextStyle(fontSize: 12))),
          Text(
            v,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return Positioned(
      left: left,
      top: 0,
      width: tipW,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.brdSubtle(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _pointTitle(p),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_series != _Series.profit)
                row(_kRevenue, 'Ingresos', _money(p.revenue)),
              if (_series != _Series.revenue)
                row(_kProfit, 'Ganancia', _money(p.profit)),
              row(AppColors.txtMuted(context), 'Pedidos', '${p.orders}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    Widget stat(String label, String value, {Color? color}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.txtSecondary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.txtPrimary(context),
          ),
        ),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 12,
        children: [
          stat('Pedidos', '${o.totalOrders}'),
          stat('Ticket promedio', _money(o.averageTicket)),
          stat('Ganancia bruta', _money(o.totalProfit), color: _kProfit),
          stat('Margen', '${o.margin.toStringAsFixed(1)}%'),
          stat('Costo de reposición', _money(o.costOfGoods)),
          stat('Cobrado', _money(o.totalCollected)),
          if (o.pendingCollection > 0)
            stat(
              'Por cobrar',
              _money(o.pendingCollection),
              color: AppColors.warning,
            ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  static const double left = 46;
  static const double right = 10;
  static const double top = 8;
  static const double bottom = 26;

  final List<SalesTrendPoint> points;
  final SalesBucket bucket;
  final bool showRevenue;
  final bool showProfit;
  final int? hovered;
  final double maxY;
  final Color gridColor;
  final Color labelColor;
  final Color surface;
  final bool isDark;

  _TrendPainter({
    required this.points,
    required this.bucket,
    required this.showRevenue,
    required this.showProfit,
    required this.hovered,
    required this.maxY,
    required this.gridColor,
    required this.labelColor,
    required this.surface,
    required this.isDark,
  });

  double _niceMax(double v) {
    if (v <= 0) return 4;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final f = v / exp;
    final double nf =
        f <= 1
            ? 1.0
            : (f <= 2 ? 2.0 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5.0 : 10.0)));
    return nf * exp;
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    TextAlign align = TextAlign.left,
    double maxWidth = 80,
    FontWeight w = FontWeight.w500,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: 11, color: labelColor, fontWeight: w),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    final dx =
        align == TextAlign.right
            ? at.dx - tp.width
            : (align == TextAlign.center ? at.dx - tp.width / 2 : at.dx);
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  String _xLabel(SalesTrendPoint p) {
    switch (bucket) {
      case SalesBucket.day:
      case SalesBucket.week:
        return _dayMonth(p.date);
      case SalesBucket.month:
        return '${_months[p.date.month - 1]} ${p.date.year % 100}';
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final niceMax = _niceMax(maxY * 1.05);
    final n = points.length;

    double xAt(int i) =>
        n == 1 ? plot.center.dx : plot.left + plot.width * i / (n - 1);
    double yAt(double v) =>
        plot.bottom - plot.height * (v / niceMax).clamp(0.0, 1.0);

    // Cuadrícula + eje Y
    final grid =
        Paint()
          ..color = gridColor
          ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(
        canvas,
        _compact(niceMax * i / 4),
        Offset(plot.left - 8, y),
        align: TextAlign.right,
        maxWidth: left - 10,
      );
    }

    // Eje X con fechas reales (máx. ~7 etiquetas, sin solaparse)
    final maxLabels = plot.width > 520 ? 7 : 4;
    final labelCount = math.min(n, maxLabels);
    final shown = <int>{};
    if (labelCount == 1) {
      shown.add(0);
    } else {
      for (var k = 0; k < labelCount; k++) {
        shown.add((k * (n - 1) / (labelCount - 1)).round());
      }
    }
    for (final i in shown) {
      var x = xAt(i);
      x = x.clamp(plot.left + 18, plot.right - 18).toDouble();
      _text(
        canvas,
        _xLabel(points[i]),
        Offset(x, size.height - 8),
        align: TextAlign.center,
        maxWidth: 60,
      );
    }

    // Línea del punto seleccionado
    if (hovered != null) {
      final x = xAt(hovered!);
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = labelColor.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }

    void drawSeries(
      double Function(SalesTrendPoint) v,
      Color color,
      bool fill,
    ) {
      final coords = [
        for (var i = 0; i < n; i++) Offset(xAt(i), yAt(v(points[i]))),
      ];

      if (n >= 2) {
        final line = Path()..moveTo(coords.first.dx, coords.first.dy);
        for (var i = 0; i < n - 1; i++) {
          final a = coords[i];
          final b = coords[i + 1];
          final mid = (b.dx - a.dx) / 2;
          // Tangentes horizontales: curva suave que nunca "rebasa" los datos.
          line.cubicTo(a.dx + mid, a.dy, b.dx - mid, b.dy, b.dx, b.dy);
        }
        if (fill) {
          final area =
              Path.from(line)
                ..lineTo(coords.last.dx, plot.bottom)
                ..lineTo(coords.first.dx, plot.bottom)
                ..close();
          canvas.drawPath(
            area,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: isDark ? 0.28 : 0.18),
                  color.withValues(alpha: 0.0),
                ],
              ).createShader(plot),
          );
        }
        canvas.drawPath(
          line,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }

      // Puntos: todos si son pocos; si no, solo los días con ventas y el seleccionado.
      for (var i = 0; i < n; i++) {
        final isHover = hovered == i;
        final hasSales = points[i].orders > 0;
        final draw = isHover || (n <= 14) || (hasSales && n <= 45);
        if (!draw) continue;
        final r = isHover ? 5.5 : 3.6;
        canvas.drawCircle(coords[i], r, Paint()..color = surface);
        canvas.drawCircle(
          coords[i],
          r,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }
    }

    // Se dibuja primero la serie con área para que la otra quede encima.
    if (showRevenue) drawSeries((p) => p.revenue, _kRevenue, true);
    if (showProfit) drawSeries((p) => p.profit, _kProfit, !showRevenue);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.points != points ||
      old.showRevenue != showRevenue ||
      old.showProfit != showProfit ||
      old.hovered != hovered ||
      old.maxY != maxY ||
      old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Actividad por día de la semana (Lun → Dom, todos los días)
// ─────────────────────────────────────────────────────────────────────────────

enum _Metric { revenue, orders }

class WeeklyActivityCard extends StatefulWidget {
  final SalesOverview overview;
  final VoidCallback? onHide;
  const WeeklyActivityCard({super.key, required this.overview, this.onHide});

  @override
  State<WeeklyActivityCard> createState() => _WeeklyActivityCardState();
}

class _WeeklyActivityCardState extends State<WeeklyActivityCard> {
  _Metric _metric = _Metric.revenue;
  int? _selected; // índice 0..6 (lunes..domingo)

  @override
  Widget build(BuildContext context) {
    final o = widget.overview;
    final txt = AppColors.txtPrimary(context);
    final muted = AppColors.txtSecondary(context);

    // Siempre 7 días, aunque el servidor no devuelva alguno.
    final days = List.generate(7, (i) {
      final found = o.weekday.where((w) => w.isoDow == i + 1);
      return found.isEmpty
          ? WeekdayActivity(isoDow: i + 1, revenue: 0, orders: 0)
          : found.first;
    });
    double value(WeekdayActivity d) =>
        _metric == _Metric.revenue ? d.revenue : d.orders.toDouble();

    final maxVal = days.map(value).fold<double>(0, math.max);
    final total = days.map(value).fold<double>(0, (a, b) => a + b);
    final peakIdx =
        maxVal > 0 ? days.indexWhere((d) => value(d) == maxVal) : -1;
    final hasData = o.totalOrders > 0;

    String fmt(double v) =>
        _metric == _Metric.revenue ? _money(v) : '${v.toInt()} pedidos';

    final focus = _selected ?? (peakIdx >= 0 ? peakIdx : null);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actividad semanal',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: txt,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qué días se vende más · ${_rangeLabel(o)}',
                      style: TextStyle(fontSize: 12.5, color: muted),
                    ),
                  ],
                ),
              ),
              if (widget.onHide != null)
                IconButton(
                  tooltip: 'Ocultar widget',
                  onPressed: widget.onHide,
                  icon: Icon(
                    Icons.visibility_off_outlined,
                    size: 18,
                    color: muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _Pill(
                label: 'Ventas S/',
                color: _kRevenue,
                selected: _metric == _Metric.revenue,
                onTap: () => setState(() => _metric = _Metric.revenue),
              ),
              _Pill(
                label: 'Pedidos',
                color: _kRevenue,
                selected: _metric == _Metric.orders,
                onTap: () => setState(() => _metric = _Metric.orders),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasData)
            const _EmptyState(text: 'Sin ventas en este periodo.', height: 160)
          else ...[
            SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: _bar(
                            context,
                            index: i,
                            day: days[i],
                            v: value(days[i]),
                            maxVal: maxVal,
                            isPeak: i == peakIdx,
                            isFocus: i == focus,
                          ),
                        ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 400))
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 14),
            if (focus != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _soft(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      focus == peakIdx
                          ? Icons.local_fire_department_rounded
                          : Icons.calendar_today_rounded,
                      size: 18,
                      color: focus == peakIdx ? AppColors.amber : muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_daysLong[focus]}${focus == peakIdx ? ' · mejor día' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: txt,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmt(value(days[focus])),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: txt,
                          ),
                        ),
                        Text(
                          total > 0
                              ? '${(value(days[focus]) / total * 100).toStringAsFixed(0)}% del total · ${days[focus].orders} ped.'
                              : '',
                          style: TextStyle(fontSize: 11.5, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _bar(
    BuildContext context, {
    required int index,
    required WeekdayActivity day,
    required double v,
    required double maxVal,
    required bool isPeak,
    required bool isFocus,
  }) {
    const maxBar = 104.0;
    // Días sin ventas: solo una marca baja (no una barra que parezca dato).
    final h = v > 0 ? math.max(8.0, maxBar * (v / maxVal)) : 4.0;
    final color =
        v == 0
            ? AppColors.brdSubtle(context)
            : (isFocus || isPeak
                ? _kRevenue
                : _kRevenue.withValues(alpha: 0.4));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _selected = index),
      onExit: (_) => setState(() => _selected = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:
            () => setState(() => _selected = _selected == index ? null : index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: 20,
              child:
                  v > 0 && (isFocus || isPeak)
                      ? Text(
                        _metric == _Metric.revenue
                            ? _compact(v)
                            : '${v.toInt()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _kRevenue,
                        ),
                      )
                      : null,
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 24,
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _daysShort[index],
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isFocus ? FontWeight.w800 : FontWeight.w500,
                color: isFocus ? _kRevenue : AppColors.txtSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
