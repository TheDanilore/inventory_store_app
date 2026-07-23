import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/core/network/network_state.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/offline_games_suggestion.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/app_drawer.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_sidebar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';

class AdminLayout extends StatefulWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final bool showProfileButton;
  final bool showSettingsButton;
  final bool showDrawerButton;
  final bool showAppBar;
  final List<PopupMenuEntry<String>>? settingsActions;
  final ValueChanged<String>? onSettingsSelected;
  final List<Widget>? actions;

  const AdminLayout({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBackButton = false,
    this.showProfileButton = true,
    this.showSettingsButton = false,
    this.showDrawerButton = true,
    this.showAppBar = true,
    this.settingsActions,
    this.onSettingsSelected,
    this.actions,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  bool _isSidebarCollapsed = false;

  void _openProfile(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.go('/login');
    } else {
      context.push('/admin/profile');
    }
  }

  void _toggleSidebar() {
    setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

          if (isDesktop) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Row(
                children: [
                  // ── Left Sidebar (Desktop) ─────────────────────────────────
                  AdminSidebar(
                    isCollapsed: _isSidebarCollapsed,
                    onToggleCollapse: _toggleSidebar,
                  ),

                  // ── Right Main Area (TopBar + Body) ─────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        // ── TopBar ERP ───────────────────────────────────────
                        _buildDesktopTopBar(context),

                        // ── Offline Banner ───────────────────────────────────
                        _buildOfflineBanner(),

                        // ── Content View ─────────────────────────────────────
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 1280),
                              child: widget.body,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              floatingActionButton: widget.floatingActionButton,
            );
          }

          // ── Mobile / Tablet Layout ──────────────────────────────────────────
          return Scaffold(
            backgroundColor: AppColors.background,
            endDrawer: widget.showDrawerButton
                ? const AppDrawer(isAdmin: true)
                : null,
            appBar: widget.showAppBar
                ? AppBar(
                  backgroundColor: AppColors.surface,
                  elevation: 0,
                  shadowColor: Colors.black.withValues(alpha: 0.06),
                  surfaceTintColor: Colors.transparent,
                  titleSpacing: 0,
                  title: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  leadingWidth:
                      (widget.showBackButton && widget.showProfileButton)
                          ? 104
                          : 60,
                  leading:
                      (!widget.showBackButton && !widget.showProfileButton)
                          ? const SizedBox.shrink()
                          : Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 12),
                                if (widget.showBackButton)
                                  AdminAppBarIconButton(
                                    icon: Icons.arrow_back_ios_new_rounded,
                                    tooltip: 'Volver',
                                    onTap: () => Navigator.maybePop(context),
                                  ),
                                if (widget.showBackButton &&
                                    widget.showProfileButton)
                                  const SizedBox(width: 8),
                                if (widget.showProfileButton)
                                  AdminProfileAvatar(
                                    onTap: () => _openProfile(context),
                                  ),
                              ],
                            ),
                          ),
                  actions: [
                    if (widget.actions != null) ...widget.actions!,
                    if (widget.actions != null && widget.actions!.isNotEmpty)
                      const SizedBox(width: 8),

                    if (widget.showSettingsButton &&
                        widget.settingsActions != null &&
                        widget.settingsActions!.isNotEmpty) ...[
                      AdminSettingsMenuButton(
                        items: widget.settingsActions!,
                        onSelected: widget.onSettingsSelected,
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (widget.showDrawerButton)
                      Builder(
                        builder:
                            (context) => AdminAppBarIconButton(
                              icon: Icons.menu_rounded,
                              tooltip: 'Menú principal',
                              onTap: () => Scaffold.of(context).openEndDrawer(),
                            ),
                      ),

                    const SizedBox(width: 12),
                  ],
                )
                : null,
            body: SafeArea(
              top: !widget.showAppBar,
              bottom: false,
              child: Column(
                children: [
                  _buildOfflineBanner(),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: widget.body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: widget.floatingActionButton,
            bottomNavigationBar: widget.bottomNavigationBar,
          );
        },
      ),
    );
  }

  Widget _buildDesktopTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // ── Toggle Sidebar Button ─────────────────────────────────
          AdminAppBarIconButton(
            icon: _isSidebarCollapsed
                ? Icons.menu_open_rounded
                : Icons.menu_rounded,
            tooltip: _isSidebarCollapsed ? 'Expandir menú' : 'Colapsar menú',
            onTap: _toggleSidebar,
          ),
          const SizedBox(width: 16),

          // ── Title & Breadcrumbs ───────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const Text(
                'Panel de Administración ERP',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── Quick Custom Actions ──────────────────────────────────
          if (widget.actions != null) ...widget.actions!,
          if (widget.actions != null && widget.actions!.isNotEmpty)
            const SizedBox(width: 12),

          // ── Notifications Icon ────────────────────────────────────
          AdminAppBarIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notificaciones',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sin notificaciones pendientes'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // ── Settings Dropdown ─────────────────────────────────────
          if (widget.showSettingsButton &&
              widget.settingsActions != null &&
              widget.settingsActions!.isNotEmpty) ...[
            AdminSettingsMenuButton(
              items: widget.settingsActions!,
              onSelected: widget.onSettingsSelected,
            ),
            const SizedBox(width: 12),
          ],

          // ── Admin Profile Dropdown Avatar ─────────────────────────
          PopupMenuButton<String>(
            tooltip: 'Opciones de perfil',
            offset: const Offset(0, 48),
            onSelected: (value) {
              if (value == 'profile') context.push('/admin/profile');
              if (value == 'business') context.push('/admin/business-info');
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
                    Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Cerrar Sesión', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
            child: AdminProfileAvatar(
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return BlocBuilder<NetworkCubit, NetworkState>(
      builder: (context, state) {
        final isOnline = state is NetworkConnected;
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isOnline
              ? const SizedBox(width: double.infinity, height: 0)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      color: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Sin conexión a internet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const OfflineGamesSuggestion(),
                  ],
                ),
        );
      },
    );
  }
}

/// Botón circular para la AppBar
class AdminAppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const AdminAppBarIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class AdminSettingsMenuButton extends StatelessWidget {
  final List<PopupMenuEntry<String>> items;
  final PopupMenuItemSelected<String>? onSelected;

  const AdminSettingsMenuButton({
    super.key,
    required this.items,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Opciones',
      offset: const Offset(0, 45),
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Avatar / botón de perfil con CachedNetworkImage
class AdminProfileAvatar extends StatelessWidget {
  final VoidCallback onTap;
  const AdminProfileAvatar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Perfil',
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: AppColors.cardShadow(opacity: 0.2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  final currentUser = state.currentUser;
                  if (state.viewState == ViewState.loading &&
                      currentUser?.avatarUrl == null &&
                      (currentUser?.fullName ?? '').isEmpty) {
                    return const Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  }

                  if (currentUser?.avatarUrl != null &&
                      currentUser!.avatarUrl!.isNotEmpty) {
                    return CachedNetworkImage(
                      imageUrl: currentUser.avatarUrl!,
                      fit: BoxFit.cover,
                      width: 38,
                      height: 38,
                      placeholder:
                          (context, url) => _initialsWidget(currentUser),
                      errorWidget:
                          (context, url, error) =>
                              _initialsWidget(currentUser),
                    );
                  }
                  return _initialsWidget(currentUser);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _initialsWidget(UserEntity? user) {
    String initials = '?';
    final name = (user?.fullName ?? '').trim();
    if (name.isNotEmpty) {
      final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
      initials =
          parts.length >= 2
              ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
              : name[0].toUpperCase();
    }

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
