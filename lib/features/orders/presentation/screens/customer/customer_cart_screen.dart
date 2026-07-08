import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/config/presentation/bloc/app_config_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cart_provider.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/wallet_provider.dart';
import 'package:inventory_store_app/features/orders/presentation/providers/cart_checkout_provider.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/widgets/cart/cart_action_header.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/widgets/cart/cart_address_card.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/widgets/cart/cart_checkout_footer.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/widgets/cart/cart_item_card.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/widgets/cart/cart_wallet_summary.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/customer_layout.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/features/pos/data/models/cart_item_model.dart';
import 'package:go_router/go_router.dart';

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
      context.read<CartCheckoutProvider>().loadAddress();
    });
  }

  Future<void> _enviarPedidoWhatsApp(
    List<CartItemModel> selectedItems,
    String orderId,
    double totalAPagar,
    int puntosUsados,
  ) async {
    final config = context.read<AppConfigCubit>();
    final whatsappNumber = config.businessPhone;
    if (whatsappNumber.isEmpty) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Número de WhatsApp de la tienda no configurado.',
          backgroundColor: AppColors.error,
        );
      }
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Hola, me gustaría confirmar mi pedido (#$orderId):');
    buffer.writeln();

    for (final item in selectedItems) {
      final variantLabel =
          item.variantLabel != null ? ' Modelo: ${item.variantLabel}' : '';
      buffer.writeln('• ${item.quantity} x ${item.product.name}$variantLabel');
    }

    buffer.writeln();
    if (puntosUsados > 0) {
      buffer.writeln('Puntos de billetera usados: $puntosUsados');
    }
    buffer.writeln('*Total a Pagar: S/ ${totalAPagar.toStringAsFixed(2)}*');

    final message = Uri.encodeComponent(buffer.toString());
    final url = Uri.parse('https://wa.me/$whatsappNumber?text=$message');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo abrir WhatsApp',
          backgroundColor: AppColors.error,
        );
      }
    }
  }

  void _handleCheckout() async {
    final cart = context.read<CartProvider>();
    final wallet = context.read<WalletProvider>();
    final config = context.read<AppConfigCubit>();
    final checkout = context.read<CartCheckoutProvider>();

    final result = await checkout.processCheckout(
      cart: cart,
      wallet: wallet,
      config: config,
    );

    if (result == null) return;

    if (!mounted) return;

    if (result['error'] == 'STOCK') {
      final messages = result['messages'] as List<String>;
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text(
                'Stock Insuficiente',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Lo sentimos, el stock ha variado y algunos productos ya no están disponibles en las cantidades solicitadas:\n\n${messages.join('\n')}',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );
    } else if (result['error'] != null) {
      AppSnackbar.show(
        context,
        message: result['message'] ?? 'Ocurrió un error al procesar el pedido.',
        backgroundColor: AppColors.error,
      );
    } else if (result['success'] == true) {
      final orderIdCorto =
          result['orderId'].toString().substring(0, 8).toUpperCase();

      await _enviarPedidoWhatsApp(
        result['itemsToBuy'] as List<CartItemModel>,
        orderIdCorto,
        result['totalAPagar'] as double,
        result['puntosUsados'] as int,
      );

      // Refresh wallet balance
      if (mounted) {
        await context.read<WalletProvider>().refresh();
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: '¡Pedido registrado exitosamente!',
          backgroundColor: AppColors.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final wallet = context.watch<WalletProvider>();
    final checkout = context.watch<CartCheckoutProvider>();
    final config = context.watch<AppConfigCubit>();

    final saldoPuntos = wallet.balance ?? 0;
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);

    final sortedCartItems =
        cart.items.values.toList()..sort((a, b) {
          final aInStock = a.availableStock > 0 ? 1 : 0;
          final bInStock = b.availableStock > 0 ? 1 : 0;
          return bInStock.compareTo(aInStock);
        });

    return CustomerLayout(
      title: 'Danilore Store',
      showBackButton: false,
      showProfileIcon: false,
      showBottomNav: true,
      showCartIcon: false,
      showWalletChip: true,
      currentIndex: 1,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child:
            cart.isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                )
                : cart.items.isEmpty
                ? const AppEmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Tu carrito está vacío',
                  message:
                      'Agrega productos desde el catálogo para armar tu pedido.',
                )
                : SizedBox(
                  height: double.infinity,
                  child: Column(
                    children: [
                      if (checkout.isVerifyingStock)
                        const LinearProgressIndicator(color: AppColors.primary),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 20),
                          itemCount: cart.items.length + 3,
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              if (!config.loyaltyGlobalEnabled ||
                                  !config.loyaltyCustomerVisible) {
                                return const SizedBox.shrink();
                              }
                              return CartWalletSummary(
                                cart: cart,
                                saldoPuntos: saldoPuntos,
                              );
                            }
                            if (i == 1) {
                              return CartAddressCard(
                                address: checkout.defaultAddress,
                                isLoading: checkout.isLoadingAddress,
                                onTap: () async {
                                  await context.push('/customer/locations');
                                  if (context.mounted) {
                                    context
                                        .read<CartCheckoutProvider>()
                                        .loadAddress();
                                  }
                                },
                              );
                            }
                            if (i == 2) {
                              return CartActionHeader(cart: cart);
                            }

                            final index = i - 3;
                            final cartItem = sortedCartItems[index];
                            final productId = cartItem.product.id;
                            return CartItemCard(
                              productId: productId,
                              item: cartItem,
                              cart: cart,
                              saldoPuntos: saldoPuntos,
                              pointsToSolesRatio: pointsToSolesRatio,
                            );
                          },
                        ),
                      ),
                      CartCheckoutFooter(
                        cart: cart,
                        saldoPuntos: saldoPuntos,
                        pointsToSolesRatio: pointsToSolesRatio,
                        onProcessCheckout: _handleCheckout,
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
