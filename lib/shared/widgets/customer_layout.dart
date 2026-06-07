import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/network_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart'; // ← NUEVO
import 'package:inventory_store_app/screens/auth/profile_screen.dart';
import 'package:inventory_store_app/screens/auth/login_screen.dart';
import 'package:inventory_store_app/screens/customer/cart_screen.dart';
import 'package:inventory_store_app/screens/customer/customer_catalog_screen.dart';
import 'package:inventory_store_app/screens/customer/points_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';

class CustomerLayout extends StatelessWidget {
  // ← StatelessWidget ahora
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final bool showProfileIcon;
  final bool showBottomNav;
  final int currentIndex;
  final bool showCartIcon;
  final bool showWalletChip;
  final bool showAppBar;
  final bool hideAppBarOnScroll;
  final ValueChanged<int>? onTabSelected;

  const CustomerLayout({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBackButton = false,
    this.showProfileIcon = true,
    this.showBottomNav = true,
    this.currentIndex = 0,
    this.showCartIcon = true,
    this.showWalletChip = true,
    this.showAppBar = true,
    this.hideAppBarOnScroll = false,
    this.onTabSelected,
  });

  // ─── WALLET CHIP ─────────────────────────────────────────────────────────

  Widget _buildWalletChip(BuildContext context) {
    // Usamos Consumer para que SOLO el chip se reconstruya al cambiar el saldo
    return Consumer<WalletProvider>(
      builder: (context, wallet, child) {
        // Si no hay saldo, ocultamos
        if (!wallet.hasBalance) return const SizedBox.shrink();

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PointsScreen()),
                ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.goldLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    size: 16,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wallet.isLoading ? '...' : '${wallet.balance ?? 0}',
                    style: const TextStyle(
                      color: Color(0xFF8A6300),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  // ─── LEADING ─────────────────────────────────────────────────────────────

  Widget? _buildLeading(BuildContext context) {
    if (showBackButton) {
      return IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: AppColors.textPrimary,
          ),
        ),
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            final user = Supabase.instance.client.auth.currentUser;
            if (user == null) {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const LoginScreen(),
                  transitionDuration: Duration.zero,
                ),
              );
            } else {
              if (onTabSelected != null) {
                onTabSelected!(2);
              } else {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (_, __, ___) =>
                            const ProfileScreen(openedFromAdmin: false),
                    transitionDuration: Duration.zero,
                  ),
                );
              }
            }
          }
        },
      );
    } else if (showProfileIcon) {
      return IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
        onPressed: () {
          final user = Supabase.instance.client.auth.currentUser;
          if (user == null) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const LoginScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          } else {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (_, __, ___) => const ProfileScreen(openedFromAdmin: false),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          }
        },
      );
    }
    return null;
  }

  // ─── TITLE ───────────────────────────────────────────────────────────────

  // Recibe context para poder hacer watch dentro del NestedScrollView,
  // ya que su headerSliverBuilder no se reconstruye con el padre.
  Widget _buildTitle(BuildContext context) {
    final bool noLeadingIcon = !showBackButton && !showProfileIcon;
    // Leemos el businessName directamente del provider para que sea reactivo
    // incluso dentro del SliverAppBar del NestedScrollView.
    final liveTitle = context.watch<AppConfigProvider>().businessName;
    final displayTitle =
        liveTitle.isNotEmpty && liveTitle != 'Cargando...'
            ? liveTitle
            : title; // fallback al parámetro recibido
    return Padding(
      padding: EdgeInsets.only(left: noLeadingIcon ? 16.0 : 4.0),
      child: Text(
        displayTitle,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  // ─── ACTIONS ─────────────────────────────────────────────────────────────

  List<Widget> _buildActions(BuildContext context, CartProvider cart) {
    return [
      if (showWalletChip) _buildWalletChip(context),
      const SizedBox(width: 8),
      if (showCartIcon)
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (onTabSelected != null) {
                onTabSelected!(1);
              } else {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const CartScreen(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
            },
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (cart.itemCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${cart.itemCount > 9 ? "9+" : cart.itemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
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
      const SizedBox(width: 12),
    ];
  }

  // ─── APPBAR ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, CartProvider cart) {
    return AppBar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.cardShadow(opacity: 0.1).first.color,
      scrolledUnderElevation: 2,
      titleSpacing: 0,
      leading: _buildLeading(context),
      title: _buildTitle(context),
      actions:
          (showCartIcon || showWalletChip)
              ? _buildActions(context, cart)
              : null,
    );
  }

  // ─── BOTTOM NAV ──────────────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context, CartProvider cart) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppColors.cardShadow(),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                context: context,
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Inicio',
                onTap: () {
                  if (onTabSelected != null) {
                    onTabSelected!(0);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder:
                            (_, __, ___) => const CustomerCatalogScreen(),
                        transitionDuration: Duration.zero,
                      ),
                    );
                  }
                },
              ),
              _navItemCart(context, cart),
              _navItem(
                context: context,
                index: 2,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Perfil',
                onTap: () {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user == null) {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const LoginScreen(),
                        transitionDuration: Duration.zero,
                      ),
                    );
                  } else {
                    if (onTabSelected != null) {
                      onTabSelected!(2);
                    } else {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (_, __, ___) =>
                                  const ProfileScreen(openedFromAdmin: false),
                          transitionDuration: Duration.zero,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isActive = currentIndex == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color:
                isActive
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 22,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItemCart(BuildContext context, CartProvider cart) {
    final isActive = currentIndex == 1;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (onTabSelected != null) {
            onTabSelected!(1);
          } else {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const CartScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color:
                isActive
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive
                        ? Icons.shopping_bag_rounded
                        : Icons.shopping_bag_outlined,
                    size: 22,
                    color:
                        isActive ? AppColors.accent : AppColors.textSecondary,
                  ),
                  if (cart.itemCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        child: Text(
                          '${cart.itemCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Carrito',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final isOnline = context.watch<NetworkProvider>().isOnline;

    // Banner de sin conexión + body
    Widget pageBody = Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child:
              isOnline
                  ? const SizedBox.shrink() // No ocupa espacio si hay internet
                  : AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    offset: isOnline ? const Offset(0, -1) : Offset.zero,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: isOnline ? 0 : 1,
                      child: Container(
                        width: double.infinity,
                        color: Colors.red.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Sin conexión a internet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
        ),
        Expanded(child: body),
      ],
    );

    Widget finalBody =
        showAppBar ? pageBody : SafeArea(bottom: false, child: pageBody);

    if (hideAppBarOnScroll) {
      finalBody = NestedScrollView(
        headerSliverBuilder:
            (context, innerBoxIsScrolled) => [
              SliverAppBar(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                centerTitle: false,
                automaticallyImplyLeading: false,
                surfaceTintColor: Colors.transparent,
                floating: true,
                snap: true,
                titleSpacing: 0,
                leading: _buildLeading(context),
                title: _buildTitle(context),
                actions:
                    (showCartIcon || showWalletChip)
                        ? _buildActions(context, cart)
                        : null,
              ),
            ],
        body: pageBody,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar:
          (showAppBar && !hideAppBarOnScroll)
              ? _buildAppBar(context, cart)
              : null,
      body: finalBody,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar:
          showBottomNav ? _buildBottomNav(context, cart) : bottomNavigationBar,
    );
  }
}
