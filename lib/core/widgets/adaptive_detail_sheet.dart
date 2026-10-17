import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Contenedor marco/contorno reutilizable para vistas de detalle:
///  - Desktop / Tablet (>= 900px): Slide-over panel lateral flotante con bordes redondeados y desenfoque de fondo.
///  - Móvil: Bottom Sheet con drag handle táctil.
class AdaptiveDetailSheet {
  static const double desktopBreakpoint = 900;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    double desktopWidth = 540,
    double breakpoint = desktopBreakpoint,
    String barrierLabel = 'Cerrar detalle',
    double mobileMaxHeightFactor = 0.92,
    bool enableGlassmorphism = true,
    Widget Function(Widget child)? wrap,
  }) {
    Widget wrapped(Widget child) => wrap != null ? wrap(child) : child;
    final isDesktop = MediaQuery.sizeOf(context).width >= breakpoint;

    if (isDesktop) {
      return showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel: barrierLabel,
        barrierColor: Colors.black.withValues(alpha: 0.28),
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (dialogContext, anim1, _) {
          final curved = CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
          );

          return wrapped(
            _DetailSheetScope(
              isSideSheet: true,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape):
                      () => Navigator.of(dialogContext).maybePop(),
                },
                child: Focus(
                  autofocus: true,
                  child: Stack(
                    children: [
                      // Fondo con borrosidad (Glassmorphism)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => Navigator.of(dialogContext).maybePop(),
                          child:
                              enableGlassmorphism
                                  ? BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 6,
                                      sigmaY: 6,
                                    ),
                                    child: Container(color: Colors.transparent),
                                  )
                                  : Container(color: Colors.transparent),
                        ),
                      ),
                      // Panel Flotante
                      Align(
                        alignment: Alignment.centerRight,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(curved),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Material(
                              color: Colors.white,
                              elevation: 10,
                              shadowColor: Colors.black12,
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: SizedBox(
                                width: desktopWidth.clamp(
                                  360.0,
                                  MediaQuery.sizeOf(dialogContext).width - 32,
                                ),
                                height: double.infinity,
                                child: Builder(builder: builder),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return wrapped(
          _DetailSheetScope(
            isSideSheet: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(ctx).height * mobileMaxHeightFactor,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Builder(builder: builder),
            ),
          ),
        );
      },
    );
  }
}

class _DetailSheetScope extends InheritedWidget {
  final bool isSideSheet;
  const _DetailSheetScope({required this.isSideSheet, required super.child});

  static bool isSide(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_DetailSheetScope>()
          ?.isSideSheet ??
      false;

  @override
  bool updateShouldNotify(_DetailSheetScope old) =>
      old.isSideSheet != isSideSheet;
}

/// Marco general del detalle (Header + Body Desplazable + Footer opcional).
class DetailSheetFrame extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget> headerActions;
  final Widget body;

  /// Franja fija opcional bajo la cabecera (p. ej. chips de variantes).
  final Widget? headerBottom;
  final Widget? footer;
  final EdgeInsetsGeometry bodyPadding;
  final Color? bodyBackgroundColor;
  final VoidCallback? onClose;

  /// En móvil el cuerpo ocupa solo lo necesario; con `true` llena la altura
  /// máxima del sheet (útil si el contenido cambia de tamaño al cargar).
  final bool fillMobileHeight;

  const DetailSheetFrame({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.headerActions = const [],
    this.headerBottom,
    this.footer,
    this.bodyPadding = const EdgeInsets.all(16),
    this.bodyBackgroundColor,
    this.onClose,
    this.fillMobileHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSide = _DetailSheetScope.isSide(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: isSide ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isSide)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

        // Cabecera / Header
        Padding(
          padding: EdgeInsets.fromLTRB(20, isSide ? 16 : 8, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      subtitle!,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...headerActions,
                  if (headerActions.isNotEmpty) const SizedBox(width: 6),
                  if (isSide) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'ESC',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                    tooltip: 'Cerrar',
                    onPressed:
                        onClose ?? () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

        if (headerBottom != null) headerBottom!,

        // Cuerpo Desplazable (Body)
        Flexible(
          fit: isSide || fillMobileHeight ? FlexFit.tight : FlexFit.loose,
          child: Container(
            color: bodyBackgroundColor ?? const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              padding: bodyPadding,
              physics: const AlwaysScrollableScrollPhysics(),
              child: body,
            ),
          ),
        ),

        // Pie Fijo (Footer)
        if (footer != null) ...[
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + (isSide ? 0 : bottomInset),
            ),
            child: footer,
          ),
        ],
      ],
    );
  }
}

/// Tarjeta contenedor genérica para agrupar secciones dentro del body.
class DetailSectionCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const DetailSectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(14),
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
