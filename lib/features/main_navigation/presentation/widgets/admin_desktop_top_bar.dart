import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class AdminDesktopTopBar extends StatelessWidget {
  final bool isSidebarCollapsed;
  final VoidCallback onToggleSidebar;
  final bool showBackButton;
  final VoidCallback onBack;
  final String title;
  final String breadcrumbText;
  final List<Widget>? actions;
  final bool showSettingsButton;
  final List<PopupMenuEntry<String>>? settingsActions;
  final ValueChanged<String>? onSettingsSelected;

  const AdminDesktopTopBar({
    super.key,
    required this.isSidebarCollapsed,
    required this.onToggleSidebar,
    required this.showBackButton,
    required this.onBack,
    required this.title,
    required this.breadcrumbText,
    this.actions,
    required this.showSettingsButton,
    this.settingsActions,
    this.onSettingsSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // ── Toggle Sidebar Button ─────────────────────────────────
          AdminAppBarIconButton(
            icon: isSidebarCollapsed
                ? Icons.menu_open_rounded
                : Icons.menu_rounded,
            tooltip: isSidebarCollapsed ? 'Expandir menú' : 'Colapsar menú',
            onTap: onToggleSidebar,
          ),
          if (showBackButton) ...[
            const SizedBox(width: 8),
            AdminAppBarIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Volver atrás',
              onTap: onBack,
            ),
          ],
          const SizedBox(width: 16),

          // ── Title & Breadcrumbs ───────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                breadcrumbText,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── Quick Custom Actions ──────────────────────────────────
          if (actions != null) ...actions!,
          if (actions != null && actions!.isNotEmpty) const SizedBox(width: 12),

          // ── Notifications Icon ────────────────────────────────────
          AdminAppBarIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notificaciones',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.notifications_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Notificaciones'),
                    ],
                  ),
                  content: const Text(
                    'No tienes notificaciones pendientes.\n\nEste módulo estará disponible próximamente.',
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
          const SizedBox(width: 12),

          // ── Settings Dropdown ─────────────────────────────────────
          if (showSettingsButton &&
              settingsActions != null &&
              settingsActions!.isNotEmpty) ...[
            AdminSettingsMenuButton(
              items: settingsActions!,
              onSelected: onSettingsSelected,
            ),
            const SizedBox(width: 12),
          ],

          // ── Admin Profile Dropdown Avatar ─────────────────────────
          PopupMenuButton<String>(
            tooltip: 'Opciones de perfil',
            offset: const Offset(0, 48),
            onSelected: (value) {
              if (value == 'profile') context.push('/admin/profile');
              if (value == 'business') context.go('/admin/business-info');
              if (value == 'logout') context.read<AuthCubit>().logout();
            },
            itemBuilder: (ctx) => [
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
}
