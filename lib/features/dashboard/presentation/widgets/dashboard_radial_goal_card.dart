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
                child: _AdjustGoalButton(
                  onConfigure: onConfigure,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gauge Graphic Centered with Smooth Sweep Animation
          Center(
            child: SizedBox(
              width: 170,
              height: 95,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(progress),
                tween: Tween<double>(begin: 0.0, end: progress),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, animatedProgress, child) {
                  final animPercent = (animatedProgress * 100).toInt();

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(170, 95),
                        painter: _AppleRadialGaugePainter(
                          progress: animatedProgress,
                          isDark: isDark,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$animPercent%',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color:
                                    animatedProgress >= 1.0
                                        ? const Color(0xFF10B981)
                                        : (isDark
                                            ? const Color(0xFFF8FAFC)
                                            : const Color(0xFF0F172A)),
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              animatedProgress >= 1.0
                                  ? '¡CUMPLIDA!'
                                  : 'LOGRADO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color:
                                    animatedProgress >= 1.0
                                        ? const Color(0xFF10B981)
                                        : (isDark
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF94A3B8)),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
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
          const SizedBox(height: 8),
          if (progress >= 1.0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      isDark
                          ? [
                            const Color(0xFF78350F).withValues(alpha: 0.5),
                            const Color(0xFF064E3B).withValues(alpha: 0.5),
                          ]
                          : [const Color(0xFFFEF3C7), const Color(0xFFD1FAE5)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                          : const Color(0xFFFBBF24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    '¡META CUMPLIDA! FELICITACIONES',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color:
                          isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF92400E),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            )
          else if (remaining > 0)
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

    if (progress <= 0.0) return;

    final isCompleted = progress >= 1.0;

    // Progress arc with celebration gradient if completed
    final progressPaint =
        Paint()
          ..shader = (isCompleted
                  ? const LinearGradient(
                    colors: [
                      Color(0xFFF59E0B),
                      Color(0xFFFBBF24),
                      Color(0xFF10B981),
                    ],
                  )
                  : const LinearGradient(
                    colors: [
                      Color(0xFF38BDF8),
                      Color(0xFF2563EB),
                      Color(0xFF10B981),
                    ],
                  ))
              .createShader(Rect.fromCircle(center: center, radius: radius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round;

    final sweep = math.pi * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      sweep,
      false,
      progressPaint,
    );

    // Tip of the arc with glow effect
    final tipAngle = math.pi + sweep;
    final tipX = center.dx + radius * math.cos(tipAngle);
    final tipY = center.dy + radius * math.sin(tipAngle);
    final tipOffset = Offset(tipX, tipY);

    final glowPaint =
        Paint()
          ..color = (isCompleted
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF10B981))
              .withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(tipOffset, 8, glowPaint);

    final dotPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(tipOffset, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _AppleRadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AdjustGoalButton extends StatefulWidget {
  final VoidCallback onConfigure;
  final bool isDark;

  const _AdjustGoalButton({required this.onConfigure, required this.isDark});

  @override
  State<_AdjustGoalButton> createState() => _AdjustGoalButtonState();
}

class _AdjustGoalButtonState extends State<_AdjustGoalButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Tooltip(
      message: 'Configurar meta de ahorro (Atajo: G)',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onConfigure,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  _isHovered
                      ? (isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                          : const Color(0xFFEFF6FF))
                      : (isDark
                          ? AppColors.darkSurfaceElevated
                          : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    _isHovered
                        ? (isDark
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.7)
                            : const Color(0xFF2563EB).withValues(alpha: 0.6))
                        : (isDark
                            ? AppColors.darkBorder
                            : const Color(0xFFE2E8F0)),
                width: _isHovered ? 1.2 : 1.0,
              ),
              boxShadow:
                  _isHovered
                      ? [
                        BoxShadow(
                          color: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: isDark ? 0.2 : 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 14,
                  color:
                      _isHovered
                          ? (isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB))
                          : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 4),
                Text(
                  'Ajustar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        _isHovered
                            ? (isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB))
                            : (isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isHovered
                            ? (isDark
                                ? const Color(
                                  0xFF2563EB,
                                ).withValues(alpha: 0.25)
                                : const Color(0xFFDBEAFE))
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color:
                          _isHovered
                              ? (isDark
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFF1D4ED8))
                              : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
