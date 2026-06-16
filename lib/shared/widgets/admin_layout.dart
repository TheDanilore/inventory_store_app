import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/providers/network_provider.dart';
import 'package:inventory_store_app/providers/profile_provider.dart';
import 'package:go_router/go_router.dart';

class AdminLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final bool showProfileButton;
  final bool showSettingsButton;
  final bool showDrawerButton;
  final List<PopupMenuEntry<String>>? settingsActions;
  final ValueChanged<String>? onSettingsSelected;

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
    this.settingsActions,
    this.onSettingsSelected,
  });

  void _openProfile(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.go('/login');
    } else {
      context.push('/admin/profile');
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      endDrawer: showDrawerButton ? const AppDrawer(isAdmin: true) : null,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
        ),
        // Ajustamos el ancho dependiendo de cuántos botones hay realmente
        leadingWidth: (showBackButton && showProfileButton) ? 104 : 60,
        leading:
            (!showBackButton && !showProfileButton)
                ? const SizedBox.shrink()
                : Align(
                  alignment:
                      Alignment.centerLeft, // <-- ANCLAJE FIJO A LA IZQUIERDA
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12), // <-- MARGEN CONSTANTE
                      if (showBackButton)
                        _AppBarIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.maybePop(context),
                        ),
                      if (showBackButton && showProfileButton)
                        const SizedBox(width: 8),
                      if (showProfileButton)
                        _ProfileAvatar(onTap: () => _openProfile(context)),
                    ],
                  ),
                ),
        actions: [
          if (showSettingsButton &&
              settingsActions != null &&
              settingsActions!.isNotEmpty) ...[
            _SettingsMenuButton(
              items: settingsActions!,
              onSelected: onSettingsSelected,
            ),
            const SizedBox(width: 8),
          ],

          if (showDrawerButton)
            Builder(
              builder:
                  (context) => _AppBarIconButton(
                    icon: Icons.menu_rounded,
                    onTap: () => Scaffold.of(context).openEndDrawer(),
                  ),
            ),

          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Offline banner — Animates its height layout size so it doesn't leave gaps
          Consumer<NetworkProvider>(
            builder: (context, network, child) {
              return AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: network.isOnline
                    ? const SizedBox(width: double.infinity, height: 0)
                    : Container(
                        width: double.infinity,
                        color: const Color(0xFFFF3B30),
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
              );
            },
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Botón circular para la AppBar
class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AppBarIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF475569)),
      ),
    );
  }
}

class _SettingsMenuButton extends StatelessWidget {
  final List<PopupMenuEntry<String>> items;
  final PopupMenuItemSelected<String>? onSelected;

  const _SettingsMenuButton({required this.items, this.onSelected});

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
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

/// Avatar / botón de perfil — carga la foto real del usuario desde ProfileProvider
class _ProfileAvatar extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileAvatar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Consumer<ProfileProvider>(
            builder: (context, profile, _) {
              if (profile.isLoading && profile.avatarUrl == null && profile.fullName.isEmpty) {
                // Skeleton/Loading state
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

              if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
                return CachedNetworkImage(
                  imageUrl: profile.avatarUrl!,
                  fit: BoxFit.cover,
                  width: 38,
                  height: 38,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (context, url) => const Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => _initialsWidget(profile),
                );
              }
              return _initialsWidget(profile);
            },
          ),
        ),
      ),
    );
  }

  Widget _initialsWidget(ProfileProvider profile) {
    String initials = '?';
    final name = profile.fullName.trim();
    if (name.isNotEmpty) {
      final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
      initials = parts.length >= 2
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
