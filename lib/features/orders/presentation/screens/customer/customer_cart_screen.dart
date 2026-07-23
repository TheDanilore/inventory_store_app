import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/wallet_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/checkout_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/checkout_state.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/customer/cart/cart_action_header.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/customer/cart/cart_address_card.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/customer/cart/cart_checkout_footer.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/customer/cart/cart_item_card.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/customer/cart/cart_stock_error_dialog.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/customer/cart/cart_wallet_summary.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_state.dart';

class CustomerCartScreen extends StatefulWidget {
  const CustomerCartScreen({super.key});

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthCubit>().state.currentUser?.id;
      final checkoutCubit = context.read<CheckoutCubit>();
      if (userId != null &&
          userId.isNotEmpty &&
          checkoutCubit.state.defaultAddress == null) {
        checkoutCubit.loadAddress(userId);
      }
    });
  }

  void _handleCheckout() {
    final user = context.read<AuthCubit>().state.currentUser;

    if (user == null || user.id.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Debes iniciar sesión para hacer tu pedido.',
        type: SnackbarType.warning,
      );
      context.push('/login');
      return;
    }

    final cartCubit = context.read<CartCubit>();
    final walletState = context.read<WalletCubit>().state;
    final config = context.read<AppConfigCubit>();

    context.read<CheckoutCubit>().submitOrder(
      itemsToBuy: cartCubit.state.items.values.toList(),
      cartCubit: cartCubit,
      profileId: user.id,
      pointsToSolesRatio: config.getDouble('points_to_soles_ratio', 0.01),
      conversionRate: config.getDouble('loyalty_earning_rate', 1.0).toInt(),
      saldoPuntos: walletState.balance ?? 0,
      activeWarehouseId:
          config.state.values['active_warehouse_id'] as String?,
      whatsappNumber: config.businessPhone,
    );
  }

  void _handleAddressNavigation() async {
    final user = context.read<AuthCubit>().state.currentUser;

    if (user == null || user.id.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Inicia sesión para gestionar ubicaciones',
        type: SnackbarType.warning,
      );
      context.go('/login');
      return;
    }

    context.go('/locations');
    if (mounted) {
      context.read<CheckoutCubit>().loadAddress(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CheckoutCubit, CheckoutState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        switch (state.status) {
          case CheckoutStatus.stockError:
            CartStockErrorDialog.show(
              context,
              messages: state.stockMessages,
            );
            context.read<CheckoutCubit>().resetStatus();
          case CheckoutStatus.failure:
            AppSnackbar.show(
              context,
              message:
                  state.errorMessage ??
                  'Ocurrió un error al procesar el pedido.',
              type: SnackbarType.error,
            );
            context.read<CheckoutCubit>().resetStatus();
          case CheckoutStatus.success:
            AppSnackbar.show(
              context,
              message: '¡Pedido registrado exitosamente!',
              type: SnackbarType.success,
            );
            context.read<CheckoutCubit>().resetStatus();
          default:
            break;
        }
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        if (cartState.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          );
        }

        if (cartState.items.isEmpty) {
          return const AppEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Tu carrito está vacío',
            message:
                'Agrega productos desde el catálogo para armar tu pedido.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            if (isDesktop) {
              return _buildDesktopSplitLayout(context, cartState);
            }

            return _buildMobileSingleColumnLayout(context, cartState);
          },
        );
      },
    );
  }

  // ── Layout Desktop: Split Checkout ERP (60% Items / 40% Panel Fijo) ─────────
  Widget _buildDesktopSplitLayout(BuildContext context, CartState cartState) {
    final cartCubit = context.read<CartCubit>();
    final checkoutCubit = context.read<CheckoutCubit>();

    final isLoyaltyGlobal = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyGlobalEnabled ?? false,
    );
    final isLoyaltyCustomer = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyCustomerVisible ?? false,
    );
    final pointsToSolesRatio = context.select<AppConfigCubit, double>(
      (c) => c.getDouble('points_to_soles_ratio', 0.01),
    );
    final saldoPuntos = context.select<WalletCubit, int>(
      (w) => w.state.balance ?? 0,
    );

    final defaultAddress = context.select<CheckoutCubit, dynamic>(
      (c) => c.state.defaultAddress,
    );
    final isLoadingAddress = context.select<CheckoutCubit, bool>(
      (c) => c.state.isLoadingAddress,
    );
    final isSending = context.select<CheckoutCubit, bool>(
      (c) => c.state.isSending,
    );
    final isVerifyingStock = context.select<CheckoutCubit, bool>(
      (c) => c.state.isVerifyingStock,
    );

    final subtotal = cartCubit.state.selectedTotalAmount;
    final isLoyaltyEnabled = isLoyaltyGlobal && isLoyaltyCustomer;
    final puntosUsados =
        isLoyaltyEnabled
            ? checkoutCubit.calculateApplicablePoints(
              cartCubit,
              pointsToSolesRatio,
              saldoPuntos,
            )
            : 0;
    final descuentoSoles = puntosUsados * pointsToSolesRatio;
    final totalAPagar =
        isLoyaltyEnabled
            ? checkoutCubit.calculateFinalTotal(
              cartCubit,
              pointsToSolesRatio,
              saldoPuntos,
            )
            : subtotal;

    final sortedCartItems =
        cartState.items.values.toList()..sort((a, b) {
          final aInStock = a.availableStock > 0 ? 1 : 0;
          final bInStock = b.availableStock > 0 ? 1 : 0;
          return bInStock.compareTo(aInStock);
        });

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Izquierda: Lista de Productos (60%)
              Expanded(
                flex: 60,
                child: Column(
                  children: [
                    CartActionHeader(
                      cartCubit: cartCubit,
                      cartState: cartState,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sortedCartItems.length,
                        itemBuilder: (context, i) {
                          final item = sortedCartItems[i];
                          return CartItemCard(
                            productId: item.productId,
                            item: item,
                            cartCubit: cartCubit,
                            saldoPuntos: saldoPuntos,
                            pointsToSolesRatio: pointsToSolesRatio,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Columna Derecha: Panel Fijo de Resumen & Checkout (40%)
              Expanded(
                flex: 40,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      CartAddressCard(
                        address: defaultAddress,
                        isLoading: isLoadingAddress,
                        onTap: _handleAddressNavigation,
                      ),
                      const SizedBox(height: 16),
                      if (isLoyaltyEnabled) ...[
                        CartWalletSummary(
                          cartCubit: cartCubit,
                          saldoPuntos: saldoPuntos,
                        ),
                        const SizedBox(height: 16),
                      ],
                      CartCheckoutFooter(
                        subtotal: subtotal,
                        totalAPagar: totalAPagar,
                        descuentoSoles: descuentoSoles,
                        selectedCount: cartState.selectedItems.length,
                        isSending: isSending,
                        isVerifyingStock: isVerifyingStock,
                        onProcessCheckout: _handleCheckout,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Layout Móvil / Tablet: 1 Columna Continua con Footer Flotante ───────────
  Widget _buildMobileSingleColumnLayout(
    BuildContext context,
    CartState cartState,
  ) {
    final cartCubit = context.read<CartCubit>();
    final checkoutCubit = context.read<CheckoutCubit>();

    final isLoyaltyGlobal = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyGlobalEnabled ?? false,
    );
    final isLoyaltyCustomer = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyCustomerVisible ?? false,
    );
    final pointsToSolesRatio = context.select<AppConfigCubit, double>(
      (c) => c.getDouble('points_to_soles_ratio', 0.01),
    );
    final saldoPuntos = context.select<WalletCubit, int>(
      (w) => w.state.balance ?? 0,
    );

    final defaultAddress = context.select<CheckoutCubit, dynamic>(
      (c) => c.state.defaultAddress,
    );
    final isLoadingAddress = context.select<CheckoutCubit, bool>(
      (c) => c.state.isLoadingAddress,
    );
    final isSending = context.select<CheckoutCubit, bool>(
      (c) => c.state.isSending,
    );
    final isVerifyingStock = context.select<CheckoutCubit, bool>(
      (c) => c.state.isVerifyingStock,
    );

    final subtotal = cartCubit.state.selectedTotalAmount;
    final isLoyaltyEnabled = isLoyaltyGlobal && isLoyaltyCustomer;
    final puntosUsados =
        isLoyaltyEnabled
            ? checkoutCubit.calculateApplicablePoints(
              cartCubit,
              pointsToSolesRatio,
              saldoPuntos,
            )
            : 0;
    final descuentoSoles = puntosUsados * pointsToSolesRatio;
    final totalAPagar =
        isLoyaltyEnabled
            ? checkoutCubit.calculateFinalTotal(
              cartCubit,
              pointsToSolesRatio,
              saldoPuntos,
            )
            : subtotal;

    final sortedCartItems =
        cartState.items.values.toList()..sort((a, b) {
          final aInStock = a.availableStock > 0 ? 1 : 0;
          final bInStock = b.availableStock > 0 ? 1 : 0;
          return bInStock.compareTo(aInStock);
        });

    return SizedBox(
      height: double.infinity,
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child:
                isVerifyingStock
                    ? const LinearProgressIndicator(color: AppColors.primary)
                    : const SizedBox.shrink(),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              itemCount: sortedCartItems.length + 3,
              itemBuilder: (context, i) {
                if (i == 0) {
                  if (!isLoyaltyEnabled) return const SizedBox.shrink();
                  return CartWalletSummary(
                    cartCubit: cartCubit,
                    saldoPuntos: saldoPuntos,
                  );
                }

                if (i == 1) {
                  return CartAddressCard(
                    address: defaultAddress,
                    isLoading: isLoadingAddress,
                    onTap: _handleAddressNavigation,
                  );
                }

                if (i == 2) {
                  return CartActionHeader(
                    cartCubit: cartCubit,
                    cartState: cartState,
                  );
                }

                final item = sortedCartItems[i - 3];
                return CartItemCard(
                  productId: item.productId,
                  item: item,
                  cartCubit: cartCubit,
                  saldoPuntos: saldoPuntos,
                  pointsToSolesRatio: pointsToSolesRatio,
                );
              },
            ),
          ),

          CartCheckoutFooter(
            subtotal: subtotal,
            totalAPagar: totalAPagar,
            descuentoSoles: descuentoSoles,
            selectedCount: cartState.selectedItems.length,
            isSending: isSending,
            isVerifyingStock: isVerifyingStock,
            onProcessCheckout: _handleCheckout,
          ),
        ],
      ),
    );
  }
}
