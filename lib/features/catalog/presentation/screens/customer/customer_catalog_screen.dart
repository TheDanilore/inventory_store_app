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
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                ),
                title: const Text(
                  '¡Bienvenido!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                content: const Text(
                  'Inicia sesión para disfrutar de más beneficios, guardar tus favoritos y acumular puntos en tus compras.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Ahora no',
                      style: TextStyle(color: AppColors.textMuted),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radius),
                      ),
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

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection(
    BuildContext context,
    List<ProductEntity> products,
  ) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      // Usuario Autenticado: Mostrar Carrusel de Recomendaciones Personalizadas
      final recommended =
          products
              .where((p) => !p.stockControl || p.totalStock > 0)
              .skip(2)
              .take(6)
              .toList();

      if (recommended.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            '✨ Recomendados para ti',
            'Selección especial según tu perfil',
          ),
          const SizedBox(height: 10),
          _HorizontalProductList(
            products: recommended,
            onAddToCart: widget.onAddToCart,
          ),
        ],
      );
    }

    // Usuario Invitado: Mostrar Tarjeta de Fidelización para Iniciar Sesión
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          boxShadow: AppColors.cardShadow(opacity: 0.15),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Recomendaciones Personalizadas',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Inicia sesión para ver sugerencias adaptadas a tus intereses.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => context.push('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Entrar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomerCatalogCubit>();
    final state = context.watch<CustomerCatalogCubit>().state;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          final maxExtent = isDesktop ? 240.0 : 200.0;

          return RefreshIndicator(
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
                  delegate: _StickySearchDelegate(
                    child: const CatalogSearchBar(),
                  ),
                ),

                // ── Categorías ────────────────────────────────────────────────────
                if (!state.isSearchMode && state.searchTerm.isEmpty) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Categorías',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  const SliverToBoxAdapter(child: CatalogCategoryList()),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ── 🔥 Más Vendidos ───────────────────────────────────────────
                  if (state.products.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _buildSectionTitle(
                        '🔥 Más Vendidos',
                        'Top de preferencia',
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverToBoxAdapter(
                      child: _HorizontalProductList(
                        products:
                            state.products
                                .where(
                                  (p) => !p.stockControl || p.totalStock > 0,
                                )
                                .take(6)
                                .toList(),
                        onAddToCart: widget.onAddToCart,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],

                  // ── ✨ Recomendados para Ti ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildRecommendedSection(context, state.products),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Todos los Productos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
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
                          color: AppColors.textPrimary,
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
                            ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  'No hay búsquedas recientes',
                                  style: TextStyle(color: AppColors.textMuted),
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
                                    color: AppColors.textMuted,
                                  ),
                                  title: Text(
                                    term,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
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
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
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
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: maxExtent,
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
                      color: AppColors.error,
                      title: 'Ocurrió un error',
                      message: state.errorMessage!,
                      action: ElevatedButton.icon(
                        onPressed: cubit.refreshProducts,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
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
                          children: const [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No se encontraron productos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Prueba buscando otra cosa o cambiando de categoría.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
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
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: maxExtent,
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
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ],
            ),
          );
        },
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
          color: AppColors.surface.withValues(alpha: 0.85),
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchDelegate old) => false;
}

class _HorizontalProductList extends StatelessWidget {
  final List<ProductEntity> products;
  final Future<void> Function(ProductEntity product)? onAddToCart;

  const _HorizontalProductList({required this.products, this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final p = products[index];
          return SizedBox(
            width: 160,
            child: CatalogProductCard(
              product: p,
              onAddToCart: onAddToCart ?? (p) async {},
            ),
          );
        },
      ),
    );
  }
}
