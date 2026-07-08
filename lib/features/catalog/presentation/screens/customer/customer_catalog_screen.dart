import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:inventory_store_app/core/widgets/customer_layout.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cart_provider.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/widgets/cart/cart_variant_picker_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/customer/widgets/catalog/catalog_search_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/customer/widgets/catalog/catalog_category_list.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/customer/widgets/catalog/catalog_banners.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/customer/widgets/catalog/catalog_product_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/customer/widgets/catalog/catalog_shimmers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class CustomerCatalogScreen extends StatefulWidget {
  const CustomerCatalogScreen({super.key});

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
      context.read<CustomerCatalogProvider>().init();
      _checkLoginPrompt();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<CustomerCatalogProvider>().loadMoreProducts();
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

  Future<void> _handleAddToCart(ProductModel product) async {
    final cart = context.read<CartProvider>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CartVariantPickerSheet(cart: cart, product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerCatalogProvider>();

    return CustomerLayout(
      title: 'Catálogo',
      currentIndex: 0,
      showAppBar: false,
      body: RefreshIndicator(
        onRefresh: provider.refreshProducts,
        color: AppColors.primary,
        child: SizedBox(
          height: double.infinity,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // --- Banners ---
              if (!provider.isSearchMode && provider.searchTerm.isEmpty) ...[
                const SliverToBoxAdapter(child: CatalogWelcomeBanner()),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                const SliverToBoxAdapter(child: CatalogPromoBanner()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // --- Search Bar (Sticky) ---
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickySearchDelegate(
                  child: const CatalogSearchBar(),
                ),
              ),

              // --- Categories ---
              if (!provider.isSearchMode && provider.searchTerm.isEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Categorías',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                const SliverToBoxAdapter(child: CatalogCategoryList()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Titulo de Todos los productos
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Todos los Productos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],

              if (provider.searchTerm.isNotEmpty || provider.isSearchMode) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Text(
                      provider.searchTerm.isEmpty
                          ? 'Busquedas recientes'
                          : 'Resultados',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],

              // --- Historial de Búsqueda ---
              if (provider.isSearchMode && provider.searchTerm.isEmpty) ...[
                SliverToBoxAdapter(
                  child:
                      provider.searchHistory.isEmpty
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
                            itemCount: provider.searchHistory.length,
                            itemBuilder: (context, index) {
                              final term = provider.searchHistory[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.history,
                                  color: Colors.grey,
                                ),
                                title: Text(term),
                                onTap: () {
                                  provider.setSearchMode(false);
                                  provider.setSearchTerm(term);
                                },
                              );
                            },
                          ),
                ),
                SliverToBoxAdapter(
                  child:
                      provider.searchHistory.isNotEmpty
                          ? TextButton(
                            onPressed: provider.clearSearchHistory,
                            child: const Text('Limpiar historial'),
                          )
                          : const SizedBox.shrink(),
                ),
              ]
              // --- Product Grid ---
              else if (provider.isInitialLoad && provider.isLoadingProducts) ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              ] else if (provider.productsError != null && provider.products.isEmpty) ...[
                SliverToBoxAdapter(
                  child: AppEmptyState(
                    icon: Icons.error_outline_rounded,
                    color: Colors.red,
                    title: 'Ocurrió un error',
                    message: provider.productsError!,
                    action: ElevatedButton.icon(
                      onPressed: provider.refreshProducts,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ),
              ] else if (provider.products.isEmpty) ...[
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.58,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = provider.products[index];
                        return CatalogProductCard(
                          product: product,
                          onAddToCart: _handleAddToCart,
                        );
                      },
                      childCount: provider.products.length,
                    ),
                  ),
                ),
                if (provider.isLoadingProducts && !provider.isInitialLoad)
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
