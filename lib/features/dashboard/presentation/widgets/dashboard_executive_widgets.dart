import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Componente para animar números de métricas de forma fluida (roll-up fintech).
class AnimatedCounterText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const AnimatedCounterText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final match = RegExp(
      r'^(.*?)([\d,]+(?:\.\d+)?)(.*)$',
    ).firstMatch(text.trim());
    if (match == null) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final prefix = match.group(1) ?? '';
    final rawNumber = (match.group(2) ?? '0').replaceAll(',', '');
    final suffix = match.group(3) ?? '';
    final targetValue = double.tryParse(rawNumber) ?? 0.0;
    final hasDecimals = match.group(2)!.contains('.');
    final decimalPlaces =
        hasDecimals
            ? (match.group(2)!.split('.').length > 1
                ? match.group(2)!.split('.')[1].length
                : 2)
            : 0;

    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween<double>(begin: 0.0, end: targetValue),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutExpo,
      builder: (context, val, child) {
        final formattedNumber =
            NumberFormat.currency(
              symbol: '',
              decimalDigits: decimalPlaces,
            ).format(val).trim();

        return Text(
          '$prefix$formattedNumber$suffix',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// Tarjeta KPI estándar del Dashboard estilo Apple HIG / Shopeers.
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -3.0 : 0.0, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  _isHovered
                      ? widget.accentColor.withValues(alpha: 0.65)
                      : (isDark
                          ? AppColors.darkBorder
                          : const Color(0xFFE2E8F0)),
              width: _isHovered ? 1.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    _isHovered
                        ? widget.accentColor.withValues(alpha: 0.22)
                        : (isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.03)),
                blurRadius: _isHovered ? 20 : 8,
                offset: Offset(0, _isHovered ? 6 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: Title and Animated Icon Container
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
                  AnimatedScale(
                    scale: _isHovered ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(
                          alpha: isDark ? 0.25 : 0.14,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.accentColor.withValues(
                            alpha: _isHovered ? 0.5 : 0.0,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 18,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Main Metric Value (Animated Counter)
              AnimatedCounterText(
                text: widget.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                  letterSpacing: -0.6,
                ),
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
                            )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .moveY(
                              begin: 0,
                              end: widget.isPositiveDelta ? -1.5 : 1.5,
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeInOut,
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

/// Menú de opciones contextuales para widgets del Dashboard
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
