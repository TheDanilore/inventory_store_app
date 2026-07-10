import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/customer_layout.dart';
import 'package:inventory_store_app/features/customers/presentation/providers/customer_wishlist_provider.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cart_provider.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/widgets/wishlist/wishlist_card.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/widgets/cart/cart_variant_picker_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerWishlistProvider>().init();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<CustomerWishlistProvider>();
      if (!provider.isLoadingMore && provider.hasMore) {
        provider.fetchWishlist(reset: false);
      }
    }
  }

  Future<void> _handleAddToCart(WishlistEntryModel entry) async {
    final cart = context.read<CartProvider>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              CartVariantPickerSheet(cart: cart, product: entry.product.toEntity()),
    );
  }

  Future<void> _confirmRemove(WishlistEntryModel entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Eliminar de deseos',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            content: Text(
              '¿Quitar "${entry.product.name}" de tu lista?',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF0F0),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final provider = context.read<CustomerWishlistProvider>();
      try {
        await provider.removeFromWishlist(entry);
        if (mounted) {
          AppSnackbar.show(context, message: 'Eliminado de tu lista de deseos');
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: e.toString(),
            type: SnackbarType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerWishlistProvider>();

    return CustomerLayout(
      title: 'Mis Deseos',
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: true,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await provider.fetchWishlist(reset: true);
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    _buildHeaderBanner(provider),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _buildBody(provider),
            ),

            if (provider.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(CustomerWishlistProvider provider) {
    final availableCount =
        provider.items
            .where((e) => e.product.totalStock > 0 && e.product.isActive)
            .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lista de deseos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${provider.items.length} guardado${provider.items.length == 1 ? '' : 's'}  ·  $availableCount disponibles',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(CustomerWishlistProvider provider) {
    if (provider.isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: AppShimmer(
              width: double.infinity,
              height: 130,
              borderRadius: 22,
            ),
          ),
          childCount: 5,
        ),
      );
    }

    if (provider.profileId == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: AppEmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'Necesitas iniciar sesión',
            message: 'Inicia sesión para ver tu lista de deseos.',
          ),
        ),
      );
    }

    if (provider.errorMessage.isNotEmpty && provider.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: AppEmptyState(
            icon: Icons.error_outline,
            title: 'Algo salió mal',
            message: provider.errorMessage,
          ),
        ),
      );
    }

    if (provider.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: AppEmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'Tu lista está vacía',
            message:
                'Toca el corazón en cualquier producto para guardarlo aquí.',
            action: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/customer/catalog'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: const Text(
                  'Explorar catálogo',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = provider.items[index];
        final isProcessing = provider.isItemProcessing(entry.wishlistId);
        return WishlistCard(
          key: ValueKey(entry.wishlistId),
          entry: entry,
          isProcessing: isProcessing,
          onAddToCart: () => _handleAddToCart(entry),
          onRemove: () => _confirmRemove(entry),
        );
      }, childCount: provider.items.length),
    );
  }
}
