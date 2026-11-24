import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';

/// Contenedor modal camaleónico para flujos de tarea, selectores y confirmaciones:
/// - Móvil (< 600px): BottomSheet arrastrable estilo Apple HIG con drag handle y SafeArea.
/// - Tablet / Desktop (>= 600px): Diálogo flotante centrado con ancho restringido,
///   BackdropFilter, animación orgánica y cierre seguro con Escape.
class AdaptiveModalSheet {
  AdaptiveModalSheet._();

  static const double tabletBreakpoint = 600.0;

  /// Indica si el contexto actual está renderizándose como Diálogo centrado (Tablet/Desktop).
  static bool isDialogMode(BuildContext context) =>
      _AdaptiveModalScope.of(context);

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    double maxWidth = 560,
    double maxHeightFactor = 0.90,
    bool barrierDismissible = true,
    bool showDragHandle = true,
    String barrierLabel = 'Cerrar',
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= tabletBreakpoint;

    if (isWide) {
      return showGeneralDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        barrierLabel: barrierLabel,
        barrierColor: AppColors.scrim(context),
        transitionDuration: const Duration(milliseconds: 240),
        transitionBuilder: (ctx, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(ctx)) {
            return child;
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
        pageBuilder: (dialogCtx, _, _) {
          final size = MediaQuery.sizeOf(dialogCtx);
          final disableAnimations = MediaQuery.disableAnimationsOf(dialogCtx);
          final isDark = AppColors.isDark(dialogCtx);

          return _AdaptiveModalScope(
            isDialog: true,
            child: _ModalEscapeScope(
              allowDismiss: barrierDismissible,
              onDismiss: () => Navigator.of(dialogCtx).maybePop(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap:
                          barrierDismissible
                              ? () => Navigator.of(dialogCtx).maybePop()
                              : null,
                      child:
                          disableAnimations
                              ? const SizedBox.expand()
                              : BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 8,
                                  sigmaY: 8,
                                ),
                                child: const SizedBox.expand(),
                              ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxWidth.clamp(
                            320.0,
                            (size.width - 48).clamp(320.0, maxWidth),
                          ),
                          maxHeight: size.height * maxHeightFactor,
                        ),
                        child: Material(
                          color: AppColors.surfElevated(dialogCtx),
                          surfaceTintColor: Colors.transparent,
                          elevation: isDark ? 0 : 18,
                          shadowColor: Colors.black.withValues(alpha: 0.16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: AppColors.brdSubtle(dialogCtx),
                              width: 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Builder(builder: builder),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim(context),
      builder: (sheetCtx) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
        final maxHeight = MediaQuery.sizeOf(sheetCtx).height * maxHeightFactor;

        return _AdaptiveModalScope(
          isDialog: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surf(sheetCtx),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(color: AppColors.brd(sheetCtx), width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDragHandle) const AppSheetDragHandle(),
                      Flexible(child: Builder(builder: builder)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdaptiveModalScope extends InheritedWidget {
  final bool isDialog;

  const _AdaptiveModalScope({required this.isDialog, required super.child});

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_AdaptiveModalScope>()
          ?.isDialog ??
      false;

  @override
  bool updateShouldNotify(_AdaptiveModalScope oldWidget) =>
      oldWidget.isDialog != isDialog;
}

class _ModalEscapeScope extends StatelessWidget {
  final Widget child;
  final bool allowDismiss;
  final VoidCallback onDismiss;

  const _ModalEscapeScope({
    required this.child,
    required this.allowDismiss,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (FocusUtils.isInputFieldFocused()) {
            FocusManager.instance.primaryFocus?.unfocus();
            return KeyEventResult.handled;
          }
          if (allowDismiss) {
            onDismiss();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
