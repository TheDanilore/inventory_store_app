import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Tooltip estilo Linear/Stripe que muestra la combinación de atajo de teclado
/// exclusivamente al hacer hover en Desktop/Web, manteniendo limpio el tacto en móvil.
class HoverShortcutTooltip extends StatelessWidget {
  final String message;
  final String? shortcut;
  final Widget child;
  final bool enabled;
  final bool preferBelow;

  const HoverShortcutTooltip({
    super.key,
    required this.message,
    required this.child,
    this.shortcut,
    this.enabled = true,
    this.preferBelow = true,
  });

  bool get _supportsHoverShortcuts {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    if (!_supportsHoverShortcuts || shortcut == null || shortcut!.isEmpty) {
      return child;
    }

    final isDark = AppColors.isDark(context);
    final bgColor =
        isDark ? AppColors.darkSurfaceElevated : AppColors.primaryDark;
    final keyBgColor =
        isDark
            ? AppColors.darkBackground
            : Colors.white.withValues(alpha: 0.14);
    final keyBorderColor =
        isDark
            ? AppColors.darkBorderSubtle
            : Colors.white.withValues(alpha: 0.24);

    return Tooltip(
      preferBelow: preferBelow,
      waitDuration: const Duration(milliseconds: 350),
      showDuration: const Duration(milliseconds: 1800),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.darkBorderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      richMessage: TextSpan(
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        children: [
          TextSpan(text: message),
          const WidgetSpan(child: SizedBox(width: 8)),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: keyBgColor,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: keyBorderColor),
              ),
              child: Text(
                shortcut!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}
