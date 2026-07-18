import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/customer_catalog_cubit.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/customer/catalog/catalog_search_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/customer/catalog/catalog_category_list.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/customer/catalog/catalog_banners.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/customer/catalog/catalog_product_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/customer/catalog/catalog_shimmers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';

class CustomerCatalogScreen extends StatefulWidget {
  final Future<void> Function(ProductEntity product)? onAddToCart;
  final String businessName;
  final String businessAddress;

  const CustomerCatalogScreen({
    super.key,
    this.onAddToCart,
    this.businessName = 'Nuestra Tienda',
    this.businessAddress = '',
  });

  @override
  State<CustomerCatalogScreen> createState() => _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends State<CustomerCatalogScreen> {
  final ScrollController _scrollController = ScrollController();
  static bool _hasShownLoginPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginPrompt();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<CustomerCatalogCubit>().loadMoreProducts();
      }
    });
  }

  void _checkLoginPrompt() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null && !_hasShownLoginPrompt) {
      _hasShownLoginPrompt = true;
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radius),
                ),
                title: const Text('¡Bienvenido!'),
                content: const Text(
                  'Inicia sesión para disfrutar de más beneficios, guardar tus favoritos y acumular puntos en tus compras.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Ahora no',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Iniciar sesión'),
                  ),
                ],
              ),
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomerCatalogCubit>();
    final state = context.watch<CustomerCatalogCubit>().state;
    final authState = context.watch<AuthCubit>().state;
    final isGuest = authState.authStatus == AuthStatus.unauthenticated;
    final isAdmin = authState.currentUser?.role == AppRoles.admin;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: cubit.refreshProducts,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Banners (solo en modo normal) ─────────────────────────────────
            if (!state.isSearchMode && state.searchTerm.isEmpty) ...[
              SliverToBoxAdapter(
                child: CatalogWelcomeBanner(
                  businessName: widget.businessName,
                  businessAddress: widget.businessAddress,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: CatalogPromoBanner()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],

            // ── Buscador fijo (pinned) ─────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickySearchDelegate(child: const CatalogSearchBar()),
            ),

            // ── Categorías ────────────────────────────────────────────────────
            if (!state.isSearchMode && state.searchTerm.isEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Categorías',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: CatalogCategoryList()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Todos los Productos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],

            if (state.searchTerm.isNotEmpty || state.isSearchMode) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Text(
                    state.searchTerm.isEmpty
                        ? 'Búsquedas recientes'
                        : 'Resultados',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            // ── Historial de Búsqueda ─────────────────────────────────────────
            if (state.isSearchMode && state.searchTerm.isEmpty) ...[
              SliverToBoxAdapter(
                child:
                    state.searchHistory.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No hay búsquedas recientes',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.searchHistory.length,
                          itemBuilder: (context, index) {
                            final term = state.searchHistory[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.history,
                                color: Colors.grey,
                              ),
                              title: Text(term),
                              onTap: () {
                                cubit.setSearchMode(false);
                                cubit.setSearchTerm(term);
                              },
                            );
                          },
                        ),
              ),
              SliverToBoxAdapter(
                child:
                    state.searchHistory.isNotEmpty
                        ? TextButton(
                          onPressed: cubit.clearSearchHistory,
                          child: const Text('Limpiar historial'),
                        )
                        : const SizedBox.shrink(),
              ),
            ]
            // ── Grid de Productos ─────────────────────────────────────────────
            else if ((state.viewState == ViewState.loading &&
                    state.products.isEmpty) &&
                (state.viewState == ViewState.loading ||
                    state.isLoadingMore)) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, _) => const CatalogProductShimmer(),
                    childCount: 8,
                  ),
                ),
              ),
            ] else if (state.errorMessage != null &&
                state.products.isEmpty) ...[
              SliverToBoxAdapter(
                child: AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  color: Colors.red,
                  title: 'Ocurrió un error',
                  message: state.errorMessage!,
                  action: ElevatedButton.icon(
                    onPressed: cubit.refreshProducts,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ),
              ),
            ] else if (state.products.isEmpty) ...[
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se encontraron productos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Prueba buscando otra cosa o cambiando de categoría.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = state.products[index];
                    return CatalogProductCard(
                      product: product,
                      onAddToCart: widget.onAddToCart ?? (p) async {},
                    );
                  }, childCount: state.products.length),
                ),
              ),
              if ((state.viewState == ViewState.loading ||
                      state.isLoadingMore) &&
                  !(state.viewState == ViewState.loading &&
                      state.products.isEmpty))
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StickySearchDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickySearchDelegate({required this.child});

  @override
  double get minExtent => 68.0;

  @override
  double get maxExtent => 68.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withValues(alpha: 0.82),
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchDelegate old) => old.child != child;
}
