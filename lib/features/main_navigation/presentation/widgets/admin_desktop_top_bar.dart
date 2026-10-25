import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_command_palette.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';
import 'package:inventory_store_app/core/theme/widgets/theme_circular_wave.dart';
import 'package:inventory_store_app/core/theme/widgets/theme_eclipse_button.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/notifications/notification_bell.dart';

class AdminDesktopTopBar extends StatelessWidget {
  final bool isSidebarCollapsed;
  final VoidCallback onToggleSidebar;
  final bool showBackButton;
  final VoidCallback? onBack;
  final String title;
  final String? breadcrumbText;
  final List<Widget>? actions;
  final bool showSettingsButton;
  final List<PopupMenuEntry<String>>? settingsActions;
  final ValueChanged<String>? onSettingsSelected;

  const AdminDesktopTopBar({
    super.key,
    required this.isSidebarCollapsed,
    required this.onToggleSidebar,
    required this.showBackButton,
    this.onBack,
    required this.title,
    this.breadcrumbText = '',
    this.actions,
    required this.showSettingsButton,
    this.settingsActions,
    this.onSettingsSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // ── Sub-page Back Button & Contextual Title (Only for sub-pages / non-root views) ──
          if (showBackButton) ...[
            _TopBarIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Volver atrás',
              onTap:
                  () =>
                      AppBackHandler.handleBack(context, onCustomBack: onBack),
            ),
            const SizedBox(width: 12),
            if (title.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 1,
                height: 20,
                color:
                    isDark
                        ? AppColors.darkBorderSubtle
                        : const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: 14),
            ],
          ],

          Tooltip(
            message: 'Buscar en el ERP (Atajo: ⌘K / /)',
            child: _PressSink(
              onTap: () => AdminCommandPaletteDialog.show(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 38,
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppColors.darkSurfaceElevated
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark
                            ? AppColors.darkBorderSubtle
                            : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 18,
                      color:
                          isDark
                              ? AppColors.darkTextMuted
                              : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Buscar en el ERP...',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark
                                  ? AppColors.darkTextMuted
                                  : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // ── Quick Custom Actions (excluye botones de refresco del topbar) ──
          if (actions != null)
            ...actions!
                .where((a) => !_isRefreshWidget(a))
                .map((action) => SizedBox(height: 38, child: action)),
          if (actions != null &&
              actions!.where((a) => !_isRefreshWidget(a)).isNotEmpty)
            const SizedBox(width: 12),

          // ── Theme Mode Toggle ("Eclipse Morphing" + "Circular Eclipse Wave") ──
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              final isCurrentlyDark =
                  Theme.of(context).brightness == Brightness.dark;
              return ThemeEclipseButton(
                isDark: isCurrentlyDark,
                size: 38,
                tooltip:
                    isCurrentlyDark
                        ? 'Modo Claro Ejecutivo'
                        : 'Modo Oscuro Midnight Slate',
                onTapWithOrigin: (origin) {
                  ThemeCircularWave.switchTheme(context, origin: origin);
                },
              );
            },
          ),
          const SizedBox(width: 10),

          // ── Notificaciones reales (conteo + panel) ────────────────
          // Requiere NotificationsCubit provisto por encima del shell.
          const NotificationBell(),
          const SizedBox(width: 10),

          // ── Settings Dropdown ─────────────────────────────────────
          if (showSettingsButton &&
              settingsActions != null &&
              settingsActions!.isNotEmpty) ...[
            AdminSettingsMenuButton(
              items: settingsActions!,
              onSelected: onSettingsSelected,
            ),
            const SizedBox(width: 10),
          ],

          // ── Admin Profile Dropdown Avatar ─────────────────────────
          PopupMenuButton<String>(
            tooltip: 'Opciones de perfil',
            offset: const Offset(0, 48),
            onSelected: (value) {
              if (value == 'profile') context.push('/profile');
              if (value == 'business') context.go('/business-info');
              if (value == 'logout') context.read<AuthCubit>().logout();
            },
            itemBuilder: (ctx) {
              final authState = context.read<AuthCubit>().state;
              final currentUser = authState.currentUser;
              final isAdmin = currentUser?.isAdmin ?? false;
              final canBusiness =
                  isAdmin ||
                  (currentUser?.hasAnyPermission([
                        AppPermissions.settingsView,
                        AppPermissions.settingsEdit,
                      ]) ??
                      false);

              return [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Mi Perfil'),
                    ],
                  ),
                ),
                if (canBusiness)
                  const PopupMenuItem(
                    value: 'business',
                    child: Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Datos de Negocio'),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Cerrar Sesión',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ];
            },
            child: const AdminProfileAvatar(),
          ),
        ],
      ),
    );
  }

  static bool _isRefreshWidget(Widget w) {
    if (w is IconButton) {
      final icon = w.icon;
      if (icon is Icon &&
          (icon.icon == Icons.refresh_rounded || icon.icon == Icons.refresh)) {
        return true;
      }
      final tooltip = w.tooltip?.toLowerCase() ?? '';
      if (tooltip.contains('actualizar') ||
          tooltip.contains('refrescar') ||
          tooltip.contains('recargar')) {
        return true;
      }
    }
    return false;
  }
}

class _TopBarIconButton extends StatelessWidget {
  /// Caso simple: un solo IconData estático.
  final IconData? icon;

  /// Caso avanzado (p. ej. el toggle de tema): un widget ya armado — típicamente
  /// un AnimatedSwitcher — que reemplaza al Icon por defecto. Si se provee,
  /// tiene prioridad sobre [icon].
  final Widget? iconWidget;
  final String tooltip;
  final VoidCallback onTap;

  const _TopBarIconButton({
    this.icon,
    this.iconWidget,
    required this.tooltip,
    required this.onTap,
  }) : assert(icon != null || iconWidget != null, 'Provee icon o iconWidget');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);

    return Tooltip(
      message: tooltip,
      child: _HoverScaleTopBar(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            hoverColor:
                isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      isDark
                          ? AppColors.darkBorderSubtle
                          : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: iconWidget ?? Icon(icon, size: 19, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feedback de hover/press (escala sutil) reutilizado por los botones e
/// íconos del top bar, igual al usado en el sidebar.
class _HoverScaleTopBar extends StatefulWidget {
  final Widget child;
  const _HoverScaleTopBar({required this.child});

  @override
  State<_HoverScaleTopBar> createState() => _HoverScaleTopBarState();
}

class _HoverScaleTopBarState extends State<_HoverScaleTopBar> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.94 : (_hovered ? 1.05 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Envuelve el buscador: al presionar, el bar se "hunde" levemente (escala
/// + sombra reducida) antes de abrir el command palette — refuerza la
/// relación causal entre el clic y el modal que aparece.
class _PressSink extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _PressSink({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_PressSink> createState() => _PressSinkState();
}

class _PressSinkState extends State<_PressSink> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: widget.borderRadius,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
