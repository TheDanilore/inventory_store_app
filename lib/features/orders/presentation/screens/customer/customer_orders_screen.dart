import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/customer_layout.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/customer_orders/customer_orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/customer_orders/customer_orders_state.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/customer/orders/customer_order_card.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  static const List<Map<String, String>> _filters = [
    {'value': 'ALL', 'label': 'Todo'},
    {'value': 'PENDING', 'label': 'A pagar'},
    {'value': 'COMPLETED', 'label': 'Completado'},
    {'value': 'CANCELLED', 'label': 'Cancelado'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CustomerOrdersCubit>().init();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final cubit = context.read<CustomerOrdersCubit>();
      final state = cubit.state;
      if (!state.isLoadingMore && state.hasMore) {
        cubit.loadMore();
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<CustomerOrdersCubit>().setSearchQuery(query.trim());
    });
  }

  Future<void> _handleReorder(String orderId) async {
    try {
      final result = await context.read<CustomerOrdersCubit>().reorderOrder(orderId);
      if (!mounted) return;

      result.fold(
        (failure) {
          AppSnackbar.show(
            context,
            message: 'Error al procesar reorden: ${failure.message}',
            type: SnackbarType.error,
          );
        },
        (reorderData) {
          if (reorderData.validItems.isEmpty) {
            AppSnackbar.show(
              context,
              message: 'Los productos de este pedido se encuentran agotados o descontinuados.',
              type: SnackbarType.error,
            );
            return;
          }

          final cartCubit = context.read<CartCubit>();
          for (final cartItem in reorderData.validItems) {
            cartCubit.addItem(cartItem);
          }

          if (reorderData.outOfStock.isNotEmpty || reorderData.priceChanged.isNotEmpty) {
            AppSnackbar.show(
              context,
              message: '¡Productos añadidos al carrito! Nota: Algunos artículos cambiaron de precio o están agotados.',
              type: SnackbarType.warning,
            );
          } else {
            AppSnackbar.show(
              context,
              message: '¡Productos de la orden añadidos al carrito!',
              type: SnackbarType.success,
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error inesperado al recuperar los productos.',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomerOrdersCubit>();

    return CustomerLayout(
      title: 'Mis Pedidos',
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: true,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              await cubit.refresh();
            },
            child: BlocListener<CustomerOrdersCubit, CustomerOrdersState>(
              listener: (context, state) {
                if (state.errorMessage.isNotEmpty &&
                    state.orders.isNotEmpty &&
                    !state.isLoadingMore &&
                    !state.isBackgroundLoading) {
                  AppSnackbar.show(
                    context,
                    message: state.errorMessage,
                    type: SnackbarType.error,
                  );
                }
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BlocSelector<CustomerOrdersCubit, CustomerOrdersState, bool>(
                            selector: (s) => s.isBackgroundLoading,
                            builder: (context, isBackgroundLoading) {
                              if (!isBackgroundLoading) return const SizedBox.shrink();
                              return _buildBackgroundSyncIndicator();
                            },
                          ),
                          _buildHeaderBanner(),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyFiltersDelegate(
                      child: Container(
                        color: AppColors.background,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSearchBar(),
                            const SizedBox(height: 12),
                            _buildFilters(cubit),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: _buildBody(cubit),
                  ),
                  BlocSelector<CustomerOrdersCubit, CustomerOrdersState, bool>(
                    selector: (s) => s.isLoadingMore,
                    builder: (context, isLoadingMore) {
                      if (!isLoadingMore) {
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      }
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundSyncIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Actualizando pedidos...',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return BlocSelector<CustomerOrdersCubit, CustomerOrdersState, int>(
      selector: (state) => state.filteredOrders.length,
      builder: (context, totalOrders) {
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
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
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
                      'Tus pedidos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalOrders pedido${totalOrders == 1 ? '' : 's'} cargados',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(opacity: 0.06),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
        maxLength: 50,
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Buscar por ID de pedido...',
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(CustomerOrdersCubit cubit) {
    return BlocSelector<CustomerOrdersCubit, CustomerOrdersState, String>(
      selector: (state) => state.statusFilter,
      builder: (context, currentFilter) {
        return SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final value = filter['value']!;
              final label = filter['label']!;
              final isSelected = currentFilter == value;

              return Material(
                color: isSelected ? AppColors.primary : AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () => cubit.setStatusFilter(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBody(CustomerOrdersCubit cubit) {
    return BlocBuilder<CustomerOrdersCubit, CustomerOrdersState>(
      builder: (context, state) {
        if (state.isLoading) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: AppShimmer(
                  width: double.infinity,
                  height: 180,
                  borderRadius: 22,
                ),
              ),
              childCount: 5,
            ),
          );
        }

        if (state.profileId == null) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: AppEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Necesitas iniciar sesión',
                message: 'Inicia sesión para ver tu historial de pedidos.',
              ),
            ),
          );
        }

        if (state.errorMessage.isNotEmpty && state.orders.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: AppEmptyState(
                icon: Icons.error_outline,
                title: 'Algo salió mal',
                message: state.errorMessage,
              ),
            ),
          );
        }

        final displayOrders = state.filteredOrders;

        if (displayOrders.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: AppEmptyState(
                icon:
                    state.searchQuery.isNotEmpty
                        ? Icons.search_off_rounded
                        : Icons.receipt_long_outlined,
                title:
                    state.searchQuery.isNotEmpty
                        ? 'No se encontraron resultados'
                        : 'Aún no tienes pedidos',
                message:
                    state.searchQuery.isNotEmpty
                        ? 'Intenta buscar con otro término u otro filtro.'
                        : 'Cuando realices una compra, aparecerá aquí tu historial.',
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final order = displayOrders[index];
            final isProcessing = state.isOrderProcessing(order.id);
            return CustomerOrderCard(
              key: ValueKey(order.id),
              order: order,
              isProcessing: isProcessing,
              onReorder: () => _handleReorder(order.id),
            );
          }, childCount: displayOrders.length),
        );
      },
    );
  }
}

class _StickyFiltersDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyFiltersDelegate({required this.child});

  @override
  double get minExtent => 114.0;

  @override
  double get maxExtent => 114.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 4 : 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
      color: AppColors.background,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFiltersDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
