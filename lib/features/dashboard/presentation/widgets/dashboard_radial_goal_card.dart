import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';

/// Tarjeta del medidor de meta mensual radial estilo Apple Fitness.
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

              // Botón Configurar protegido por permisos (solo administradores o con permiso settings)
              PermissionGuard(
                permission: AppPermissions.settingsEdit,
                child: InkWell(
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
                                  ? const Color(0xFF94A3B8)
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
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gauge Graphic Centered
          Center(
            child: SizedBox(
              width: 170,
              height: 95,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(170, 95),
                    painter: _AppleRadialGaugePainter(
                      progress: progress,
                      isDark: isDark,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percent%',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color:
                                isDark
                                    ? const Color(0xFFF8FAFC)
                                    : const Color(0xFF0F172A),
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'LOGRADO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Footnote Details
          Row(
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
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    'S/ ${currentAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Objetivo',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    'S/ ${targetAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (remaining > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Faltan S/ ${remaining.toStringAsFixed(2)} para alcanzar la meta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
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
