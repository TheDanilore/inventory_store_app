import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_command_palette.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';

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
            child: InkWell(
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

          // ── Theme Mode Toggle ───────────────────────────────────────
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              final isCurrentlyDark =
                  Theme.of(context).brightness == Brightness.dark;
              return _TopBarIconButton(
                icon:
                    isCurrentlyDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                tooltip:
                    isCurrentlyDark
                        ? 'Modo Claro Ejecutivo'
                        : 'Modo Oscuro Midnight Slate',
                onTap: () {
                  context.read<ThemeCubit>().toggleTheme();
                },
              );
            },
          ),
          const SizedBox(width: 10),

          // ── Notifications Icon with Unread Dot ────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              _TopBarIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notificaciones',
                onTap: () {
                  showDialog(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 22,
                                color: Color(0xFF2563EB),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Centro de Notificaciones',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          content: const Text(
                            'Todas tus alertas de inventario y pedidos están al día.\n\nEl sistema monitoriza en tiempo real el stock crítico.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Entendido'),
                            ),
                          ],
                        ),
                  );
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
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
            itemBuilder:
                (ctx) => [
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
                ],
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
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
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
            child: Icon(
              icon,
              size: 19,
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}
