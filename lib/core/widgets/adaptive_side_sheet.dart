import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utilidad arquitectónica premium de nivel internacional para presentar
/// Side-Sheets y Modales de forma camaleónica y adaptativa:
///
/// - **Desktop / Web (ancho >= breakpoint)**:
///   Panel flotante estilo Linear / Stripe con esquinas redondeadas (`BorderRadius.circular(24)`),
///   margen perimetral flotante, sombra de elevación multinivel y BackdropFilter con desenfoque
///   cinemático (Glassmorphism). Soporta atajos de teclado con Focus Shield (Esc).
///
/// - **Móvil (ancho < breakpoint)**:
///   Modal Bottom Sheet con estética Apple HIG (esquinas superiores de 24px, drag handle táctil,
///   área táctil optimizada para el pulgar y soporte de arrastre).
class AdaptiveSideSheet {
  AdaptiveSideSheet._();

  static const double defaultBreakpoint = 800.0;
  static const double defaultDesktopWidth = 600.0;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext context, bool isSlideOver) builder,
    double desktopWidth = defaultDesktopWidth,
    double breakpoint = defaultBreakpoint,
    bool barrierDismissible = true,
    String barrierLabel = 'Cerrar detalle',
    bool enableGlassmorphism = true,
    bool enableFloatingCard = true,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSlideOver = screenWidth >= breakpoint;

    if (isSlideOver) {
      final effectiveWidth = screenWidth < (desktopWidth + 48)
          ? screenWidth * 0.92
          : desktopWidth;

      return showGeneralDialog<T>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: barrierDismissible,
        barrierLabel: barrierLabel,
        barrierColor: Colors.black.withValues(alpha: 0.28),
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (dialogCtx, anim1, anim2) {
          final sheetTheme = Theme.of(dialogCtx);
          final effectiveBg = backgroundColor ?? sheetTheme.scaffoldBackgroundColor;
          final effectiveRadius = borderRadius ??
              (enableFloatingCard
                  ? BorderRadius.circular(24)
                  : const BorderRadius.horizontal(left: Radius.circular(24)));

          return _SideSheetKeyboardScope(
            onDismiss: () {
              if (Navigator.of(dialogCtx).canPop()) {
                Navigator.of(dialogCtx).pop();
              }
            },
            child: Stack(
              children: [
                // ── 1. Glassmorphism Backdrop ─────────────────────────────
                if (enableGlassmorphism)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),

                // ── 2. Floating Linear / Stripe Side Panel ────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: enableFloatingCard
                        ? const EdgeInsets.fromLTRB(0, 12, 12, 12)
                        : EdgeInsets.zero,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: effectiveWidth,
                        height: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: effectiveBg,
                          borderRadius: effectiveRadius,
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 40,
                              offset: const Offset(-8, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(-2, 2),
                            ),
                          ],
                        ),
                        child: builder(dialogCtx, true),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        transitionBuilder: (context, anim1, anim2, child) {
          final curved = CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
    } else {
      // ── Modo Móvil: iOS Bottom Sheet con Drag Handle ─────────────────
      return showModalBottomSheet<T>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) {
          final effectiveBg = backgroundColor ?? Theme.of(sheetCtx).scaffoldBackgroundColor;
          final maxHeight = MediaQuery.sizeOf(sheetCtx).height * 0.92;

          return Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle táctil estilo Apple HIG
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Flexible(
                  child: builder(sheetCtx, false),
                ),
              ],
            ),
          );
        },
      );
    }
  }
}

/// Scope que gestiona la regla estricta de aislamiento de foco (Focus Shield)
/// y permite cerrar el Side-Sheet con la tecla [Escape] solo si no hay un
/// campo de texto activo en edición.
class _SideSheetKeyboardScope extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const _SideSheetKeyboardScope({
    required this.child,
    required this.onDismiss,
  });

  bool _isInputFieldFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final context = primaryFocus.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorStateOfType<EditableTextState>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          if (_isInputFieldFocused()) {
            FocusManager.instance.primaryFocus?.unfocus();
            return KeyEventResult.handled;
          }
          onDismiss();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
