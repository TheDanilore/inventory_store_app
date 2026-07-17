import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/network/network_state.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/offline_games_suggestion.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/wallet_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class CustomerLayout extends StatelessWidget {
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
  });

  // WALLET CHIP

  Widget _buildWalletChip(BuildContext context) {
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (context, config) {
        return BlocBuilder<WalletCubit, WalletState>(
          builder: (context, walletState) {
            final globalEnabled =
                config.businessInfo?.loyaltyGlobalEnabled ?? true;
            final customerVisible =
                config.businessInfo?.loyaltyCustomerVisible ?? true;
            if (!globalEnabled || !customerVisible) {
              return const SizedBox.shrink();
            }

            if (!walletState.hasBalance && !walletState.isLoading) {
              return const SizedBox.shrink();
            }

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go('/customer/points'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (
                          Widget child,
                          Animation<double> animation,
                        ) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.5),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child:
                            walletState.isLoading
                                ? const AppShimmer(
                                  key: ValueKey('shimmer'),
                                  width: 30,
                                  height: 12,
                                  borderRadius: 6,
                                )
                                : Text(
                                  '${walletState.balance}',
                                  key: ValueKey(walletState.balance),
                                  style: const TextStyle(
                                    color: Color(0xFF8A6300),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  // LEADING

  Widget? _buildLeading(BuildContext context) {
    if (!showBackButton && !showProfileIcon) return null;

    final child =
        showBackButton
            ? const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: AppColors.textPrimary,
            )
            : const Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: AppColors.textPrimary,
            );

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16.0),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (showBackButton) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) {
                  context.go('/login');
                } else {
                  context.go('/customer/profile');
                }
              }
            } else {
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) {
                context.push('/login');
              } else {
                context.push('/customer/profile');
              }
            }
          },
          child: SizedBox(width: 36, height: 36, child: child),
        ),
      ),
    );
  }

  // TITLE

  // Recibe context para poder hacer watch dentro del NestedScrollView,
  // ya que su headerSliverBuilder no se reconstruye con el padre.
  Widget _buildTitle(BuildContext context) {
    final bool noLeadingIcon = !showBackButton && !showProfileIcon;

    return Padding(
      padding: EdgeInsets.only(left: noLeadingIcon ? 16.0 : 0.0),
      child: BlocBuilder<AppConfigCubit, AppConfigState>(
        builder: (context, config) {
          final liveTitle = config.businessInfo?.businessName ?? '';
          final displayTitle =
              liveTitle.isNotEmpty && liveTitle != 'Cargando...'
                  ? liveTitle
                  : title; // fallback al parámetro recibido
          return Text(
            displayTitle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          );
        },
      ),
    );
  }

  //  ACTIONS

  List<Widget> _buildActions(BuildContext context) {
    return [
      if (showWalletChip) Center(child: _buildWalletChip(context)),
      if (showWalletChip && showCartIcon) const SizedBox(width: 10),
      if (showCartIcon)
        Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Material(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  context.go('/customer/cart');
                },
                child: SizedBox(
                  width: 40,
                  height: 40,
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
                      BlocBuilder<CartCubit, CartState>(
                        builder: (context, cartState) {
                          if (cartState.itemCount == 0) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            right: 4,
                            top: 4,
                            child: _AnimatedCartBadge(
                              itemCount: cartState.itemCount,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      const SizedBox(width: 16),
    ];
  }

  //  APPBAR

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final bool hasLeading = showBackButton || showProfileIcon;
    return AppBar(
      backgroundColor: AppColors.surface.withValues(alpha: 0.85),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leadingWidth: hasLeading ? 64.0 : 0.0,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.cardShadow(opacity: 0.1).first.color,
      scrolledUnderElevation: 2,
      titleSpacing: 0,
      leading: _buildLeading(context),
      title: _buildTitle(context),
      actions: (showCartIcon || showWalletChip) ? _buildActions(context) : null,
    );
  }

  //  NAVITATION (BOTTOM & RAIL)

  void _onNavDestinationSelected(BuildContext context, int index) {
    if (index == 2) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        context.go('/login');
        return;
      }
    }
    if (index == 0) context.go('/customer');
    if (index == 1) context.go('/customer/cart');
    if (index == 2) context.go('/customer/profile');
  }

  Widget _buildBottomNav(BuildContext context) {
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
                onTap: () => _onNavDestinationSelected(context, 0),
              ),
              _navItemCart(context),
              _navItem(
                context: context,
                index: 2,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Perfil',
                onTap: () => _onNavDestinationSelected(context, 2),
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

  Widget _navItemCart(BuildContext context) {
    final isActive = currentIndex == 1;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _onNavDestinationSelected(context, 1),
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
              _ShakeCartIcon(isActive: isActive),
              const SizedBox(height: 3),
              Text(
                'Carrito',
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

  Widget _buildNavRail(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: (idx) => _onNavDestinationSelected(context, idx),
      backgroundColor: AppColors.surface,
      labelType: NavigationRailLabelType.all,
      indicatorColor: AppColors.primary.withValues(alpha: 0.08),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
      selectedLabelTextStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Inicio'),
        ),
        NavigationRailDestination(
          icon: _ShakeCartIcon(isActive: false),
          selectedIcon: _ShakeCartIcon(isActive: true),
          label: Text('Carrito'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: Text('Perfil'),
        ),
      ],
    );
  }

  //  BUILD

  @override
  Widget build(BuildContext context) {
    // Banner de sin conexión + body
    Widget pageBody = Column(
      children: [
        BlocBuilder<NetworkCubit, NetworkState>(
          builder: (context, state) {
            final isOnline = state is NetworkConnected;
            return AnimatedSize(
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: double.infinity,
                                color: Colors.red.shade500,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
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
                              const OfflineGamesSuggestion(),
                            ],
                          ),
                        ),
                      ),
            );
          },
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
                backgroundColor: AppColors.surface.withValues(alpha: 0.85),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                centerTitle: false,
                automaticallyImplyLeading: false,
                leadingWidth: (showBackButton || showProfileIcon) ? 64.0 : 0.0,
                surfaceTintColor: Colors.transparent,
                floating: true,
                snap: true,
                titleSpacing: 0,
                leading: _buildLeading(context),
                title: _buildTitle(context),
                actions:
                    (showCartIcon || showWalletChip)
                        ? _buildActions(context)
                        : null,
              ),
            ],
        body: pageBody,
      );
    }

    final isTablet = MediaQuery.of(context).size.width > 600;

    Widget scaffoldBody = finalBody;
    if (isTablet && showBottomNav) {
      scaffoldBody = Row(
        children: [
          _buildNavRail(context),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: scaffoldBody),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar:
          (showAppBar && !hideAppBarOnScroll) ? _buildAppBar(context) : null,
      body: scaffoldBody,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar:
          (showBottomNav && !isTablet)
              ? _buildBottomNav(context)
              : (bottomNavigationBar != null && !isTablet
                  ? bottomNavigationBar
                  : null),
    );
  }
}

class _ShakeCartIcon extends StatefulWidget {
  final bool isActive;
  const _ShakeCartIcon({required this.isActive});

  @override
  State<_ShakeCartIcon> createState() => _ShakeCartIconState();
}

class _ShakeCartIconState extends State<_ShakeCartIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _animation;
  int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.08), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        if (cartState.itemCount > _prevCount) {
          _ctrl.forward(from: 0.0);
        }
        _prevCount = cartState.itemCount;

        return RotationTransition(
          turns: _animation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                widget.isActive
                    ? Icons.shopping_bag_rounded
                    : Icons.shopping_bag_outlined,
                size: 22,
                color:
                    widget.isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
              ),
              if (cartState.itemCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: _AnimatedCartBadge(itemCount: cartState.itemCount),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedCartBadge extends StatefulWidget {
  final int itemCount;
  const _AnimatedCartBadge({required this.itemCount});

  @override
  State<_AnimatedCartBadge> createState() => _AnimatedCartBadgeState();
}

class _AnimatedCartBadgeState extends State<_AnimatedCartBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant _AnimatedCartBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount > oldWidget.itemCount) {
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${widget.itemCount > 9 ? "9+" : widget.itemCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
