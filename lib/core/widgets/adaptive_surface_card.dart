import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Contenedor camaleónico de superficie con soporte nativo para Modo Oscuro/Claro,
/// borde fino de 1px, glassmorphism opcional (Apple HIG) y microinteracciones
/// de hover/press en Desktop y Web.
class AdaptiveSurfaceCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final bool translucent;
  final bool elevated;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHoverChanged;
  final MouseCursor? mouseCursor;

  const AdaptiveSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20.0,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.borderColor,
    this.hoverBorderColor,
    this.translucent = false,
    this.elevated = true,
    this.onTap,
    this.onHoverChanged,
    this.mouseCursor,
  });

  @override
  State<AdaptiveSurfaceCard> createState() => _AdaptiveSurfaceCardState();
}

class _AdaptiveSurfaceCardState extends State<AdaptiveSurfaceCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _setHover(bool hovered) {
    if (_isHovered == hovered) return;
    setState(() => _isHovered = hovered);
    widget.onHoverChanged?.call(hovered);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final isInteractive = widget.onTap != null;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(widget.borderRadius);

    final baseBg =
        widget.backgroundColor ??
        (widget.translucent
            ? AppColors.glassSurface(context)
            : AppColors.surf(context));
    final resolvedBg =
        (isInteractive && _isHovered)
            ? (widget.hoverBackgroundColor ?? AppColors.surfHover(context))
            : baseBg;

    final baseBorder =
        widget.borderColor ??
        (widget.translucent
            ? AppColors.glassBorder(context)
            : AppColors.brd(context));
    final resolvedBorder =
        (isInteractive && _isHovered)
            ? (widget.hoverBorderColor ?? AppColors.brdSubtle(context))
            : baseBorder;

    Widget surface = AnimatedContainer(
      duration:
          disableAnimations ? Duration.zero : const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: radius,
        border: Border.all(color: resolvedBorder, width: 1),
        boxShadow:
            (!isDark && widget.elevated)
                ? AppColors.cardShadow(opacity: _isHovered ? 0.06 : 0.035)
                : null,
      ),
      child: widget.child,
    );

    if (widget.translucent) {
      surface = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: surface,
        ),
      );
    }

    if (isInteractive) {
      surface = MouseRegion(
        cursor: widget.mouseCursor ?? SystemMouseCursors.click,
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.985 : 1.0,
            duration:
                disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: surface,
          ),
        ),
      );
    }

    if (widget.margin != null) {
      return Padding(padding: widget.margin!, child: surface);
    }
    return surface;
  }
}
