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
      if (userId != null && userId.isNotEmpty) {
        context.read<CheckoutCubit>().loadAddress(userId);
      }
    });
  }

  void _handleCheckout() {
    final user = context.read<AuthCubit>().state.currentUser;

    // Validar sesión antes de proceder
    if (user == null || user.id.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Debes iniciar sesión para hacer tu pedido.',
        type: SnackbarType.warning,
      );
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) context.push('/login');
      });
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
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) context.push('/login');
      });
      return;
    }

    await context.push('/locations');
    if (mounted) {
      context.read<CheckoutCubit>().loadAddress(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // BlocListener reacciona a los estados del CheckoutCubit sin rebuilds.
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

        return _buildCartContent(context, cartState);
      },
    );
  }

  Widget _buildCartContent(BuildContext context, CartState cartState) {
    final cartCubit = context.read<CartCubit>();
    final config = context.watch<AppConfigCubit>();
    final walletState = context.watch<WalletCubit>().state;
    final checkoutState = context.watch<CheckoutCubit>().state;
    final checkoutCubit = context.read<CheckoutCubit>();

    final saldoPuntos = walletState.balance ?? 0;
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);

    // Calcular totales en la pantalla y pasarlos al footer (sin lógica en widgets hijos)
    final subtotal = cartCubit.state.selectedTotalAmount;
    final isLoyaltyEnabled =
        config.loyaltyGlobalEnabled && config.loyaltyCustomerVisible;
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

    // Ordenar: primero los items con stock
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
          // Barra de verificación de stock
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child:
                checkoutState.isVerifyingStock
                    ? const LinearProgressIndicator(color: AppColors.primary)
                    : const SizedBox.shrink(),
          ),

          // Lista del carrito
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              itemCount: sortedCartItems.length + 3,
              itemBuilder: (context, i) {
                // Slot 0: Resumen de billetera
                if (i == 0) {
                  if (!isLoyaltyEnabled) return const SizedBox.shrink();
                  return CartWalletSummary(
                    cartCubit: cartCubit,
                    saldoPuntos: saldoPuntos,
                  );
                }

                // Slot 1: Dirección de entrega
                if (i == 1) {
                  return CartAddressCard(
                    address: checkoutState.defaultAddress,
                    isLoading: checkoutState.isLoadingAddress,
                    onTap: _handleAddressNavigation,
                  );
                }

                // Slot 2: Header con acciones de selección
                if (i == 2) {
                  return CartActionHeader(
                    cartCubit: cartCubit,
                    cartState: cartState,
                  );
                }

                // Items del carrito
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

          // Footer con total y botón de checkout
          CartCheckoutFooter(
            subtotal: subtotal,
            totalAPagar: totalAPagar,
            descuentoSoles: descuentoSoles,
            selectedCount: cartState.selectedItems.length,
            isSending: checkoutState.isSending,
            isVerifyingStock: checkoutState.isVerifyingStock,
            onProcessCheckout: _handleCheckout,
          ),
        ],
      ),
    );
  }
}
