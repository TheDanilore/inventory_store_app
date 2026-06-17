import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/providers/customer/catalog_provider.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/screens/customer/widgets/cart/cart_variant_picker_sheet.dart';
import 'package:inventory_store_app/screens/customer/widgets/catalog/catalog_search_bar.dart';
import 'package:inventory_store_app/screens/customer/widgets/catalog/catalog_category_list.dart';
import 'package:inventory_store_app/screens/customer/widgets/catalog/catalog_banners.dart';
import 'package:inventory_store_app/screens/customer/widgets/catalog/catalog_product_grid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class CustomerCatalogScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;
  const CustomerCatalogScreen({super.key, this.onTabSelected});

  @override
  State<CustomerCatalogScreen> createState() => _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends State<CustomerCatalogScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  static bool _hasShownLoginPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerCatalogProvider>().init();
      _checkLoginPrompt();
    });

    _scrollController.addListener(() {
      if (_scrollController.offset > 400 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 400 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }

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
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inicia sesión para disfrutar de más beneficios y acumular puntos.',
              key: UniqueKey(),
            ),
            action: SnackBarAction(
              label: 'Iniciar sesión',
              onPressed: () => context.push('/login'),
              textColor: AppColors.accent,
            ),
            duration: const Duration(seconds: 8),
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

  void _scrollToTop() {
    if (!kIsWeb) Vibration.vibrate(duration: 30, amplitude: 64);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
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
      onTabSelected: widget.onTabSelected,
      // Usaremos el appbar normal de customer layout si es que no queremos hacer uno super custom,
      // pero CustomerLayout por defecto esconde el AppBar si pasamos child.
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: provider.refreshProducts,
            color: AppColors.primary,
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

                if (provider.searchTerm.isNotEmpty ||
                    provider.isSearchMode) ...[
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
                else ...[
                  SliverToBoxAdapter(
                    child: CatalogProductGrid(onAddToCart: _handleAddToCart),
                  ),
                ],
              ],
            ),
          ),

          // Scroll to top button
          Positioned(
            right: 16,
            bottom: 16,
            child: AnimatedScale(
              scale: _showBackToTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: FloatingActionButton(
                mini: true,
                onPressed: _scrollToTop,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
            ),
          ),
        ],
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
