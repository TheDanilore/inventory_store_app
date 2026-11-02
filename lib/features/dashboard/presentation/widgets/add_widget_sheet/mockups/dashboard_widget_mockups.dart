import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class _SplineLinePainter extends CustomPainter {
  final Color lineColor;
  const _SplineLinePainter({this.lineColor = const Color(0xFF2563EB)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.3,
      size.height * 0.9,
      size.width * 0.5,
      size.height * 0.1,
      size.width,
      size.height * 0.4,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SplineLinePainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

/// Micro-mockup vectorial para la tira de KPIs
class DashboardKpiMockup extends StatelessWidget {
  const DashboardKpiMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 14,
                height: 5,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 10,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            width: 32,
            height: 7,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Micro-mockup vectorial para el gráfico Spline de ganancias
class DashboardSplineMockup extends StatelessWidget {
  const DashboardSplineMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 44,
          height: 28,
          child: CustomPaint(
            painter: _SplineLinePainter(
              lineColor:
                  isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
            ),
          ),
        ),
      ),
    );
  }
}

/// Micro-mockup vectorial para productos de mayor rotación
class DashboardBestSellersMockup extends StatelessWidget {
  const DashboardBestSellersMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: barBg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: barBg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: barBg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Micro-mockup vectorial para segmentación de clientes
class DashboardCustomersMockup extends StatelessWidget {
  const DashboardCustomersMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 26,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 16,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Micro-mockup vectorial para actividad semanal
class DashboardWeeklyActivityMockup extends StatelessWidget {
  const DashboardWeeklyActivityMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveBarBg =
        isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 5,
            height: 18,
            decoration: BoxDecoration(
              color: inactiveBarBg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 5,
            height: 26,
            decoration: BoxDecoration(
              color: inactiveBarBg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 6,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 5,
            height: 22,
            decoration: BoxDecoration(
              color: inactiveBarBg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 5,
            height: 14,
            decoration: BoxDecoration(
              color: inactiveBarBg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Micro-mockup vectorial para indicador radial de meta financiera
class DashboardRadialGoalMockup extends StatelessWidget {
  const DashboardRadialGoalMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 0.72,
                strokeWidth: 4,
                backgroundColor:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF10B981),
                ),
              ),
              Text(
                '72%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Micro-mockup vectorial para asistente IA
class DashboardAiAssistantMockup extends StatelessWidget {
  const DashboardAiAssistantMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF60A5FA), Color(0xFF2563EB), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Micro-mockup vectorial para lotes críticos por vencer
class DashboardExpiringBatchesMockup extends StatelessWidget {
  const DashboardExpiringBatchesMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFF450A0A).withValues(alpha: 0.4)
                : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark
                  ? const Color(0xFF991B1B).withValues(alpha: 0.6)
                  : const Color(0xFFFECDD3),
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color:
                isDark
                    ? const Color(0xFF7F1D1D).withValues(alpha: 0.6)
                    : const Color(0xFFFFE4E6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 22,
            color: isDark ? const Color(0xFFF87171) : const Color(0xFFE11D48),
          ),
        ),
      ),
    );
  }
}
