import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_wishlist_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_wishlist_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/wishlist/wishlist_card.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/wishlist_entry_entity.dart';

class WishlistScreen extends StatelessWidget {
  final void Function(BuildContext context, ProductEntity product)? onAddToCart;

  const WishlistScreen({super.key, this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerWishlistCubit>(),
      child: _WishlistScreenContent(onAddToCart: onAddToCart),
    );
  }
}

class _WishlistScreenContent extends StatefulWidget {
  final void Function(BuildContext context, ProductEntity product)? onAddToCart;

  const _WishlistScreenContent({this.onAddToCart});

  @override
  State<_WishlistScreenContent> createState() => _WishlistScreenContentState();
}

class _WishlistScreenContentState extends State<_WishlistScreenContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerWishlistCubit>().fetchWishlist(reset: true);
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
      final state = context.read<CustomerWishlistCubit>().state;
      if (state is CustomerWishlistLoaded && !state.hasReachedMax) {
        context.read<CustomerWishlistCubit>().fetchWishlist(reset: false);
      }
    }
  }

  void _handleAddToCart(WishlistEntryEntity entry) {
    if (widget.onAddToCart != null) {
      widget.onAddToCart!(context, entry.product);
    } else {
      AppSnackbar.show(context, message: 'Función añadir al carrito no disponible.');
    }
  }

  Future<void> _confirmRemove(WishlistEntryEntity entry) async {
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
      context.read<CustomerWishlistCubit>().removeFromWishlist(entry);
      AppSnackbar.show(context, message: 'Eliminado de tu lista de deseos');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Deseos'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await context.read<CustomerWishlistCubit>().fetchWishlist(reset: true);
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            BlocBuilder<CustomerWishlistCubit, CustomerWishlistState>(
              builder: (context, state) {
                if (state is CustomerWishlistLoaded) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        children: [
                          _buildHeaderBanner(state.items),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: BlocBuilder<CustomerWishlistCubit, CustomerWishlistState>(
                builder: (context, state) => _buildBody(state),
              ),
            ),

            BlocBuilder<CustomerWishlistCubit, CustomerWishlistState>(
              builder: (context, state) {
                if (state is CustomerWishlistLoaded && !state.hasReachedMax) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(List<WishlistEntryEntity> items) {
    final availableCount = items.where((e) => e.product.totalStock > 0 && e.product.isActive).length;

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
                  '${items.length} guardado${items.length == 1 ? '' : 's'}  •  $availableCount disponibles',
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

  Widget _buildBody(CustomerWishlistState state) {
    if (state is CustomerWishlistLoading || state is CustomerWishlistInitial) {
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

    if (state is CustomerWishlistError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: AppEmptyState(
            icon: Icons.error_outline,
            title: 'Algo salió mal',
            message: state.message,
          ),
        ),
      );
    }

    if (state is CustomerWishlistLoaded) {
      if (state.items.isEmpty) {
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
          final entry = state.items[index];
          return WishlistCard(
            key: ValueKey(entry.wishlistId),
            entry: entry,
            isProcessing: false,
            onAddToCart: () => _handleAddToCart(entry),
            onRemove: () => _confirmRemove(entry),
          );
        }, childCount: state.items.length),
      );
    }

    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}

