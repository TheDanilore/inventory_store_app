import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_command_palette.dart';
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
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          // ── Sub-page Back Button (Only when explicitly enabled for non-root views) ──
          if (showBackButton) ...[
            _TopBarIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Volver atrás',
              onTap: onBack,
            ),
            const SizedBox(width: 14),
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Buscar en el ERP...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
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

          // ── Quick Custom Actions ──────────────────────────────────
          if (actions != null)
            ...actions!.map((action) => SizedBox(height: 38, child: action)),
          if (actions != null && actions!.isNotEmpty) const SizedBox(width: 12),

          // ── Theme Mode Indicator Toggle ───────────────────────────
          _TopBarIconButton(
            icon: Icons.light_mode_outlined,
            tooltip: 'Modo Claro Ejecutivo',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tema ejecutivo claro activo'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
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
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: const Color(0xFFF1F5F9),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}
