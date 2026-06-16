import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:inventory_store_app/providers/customer/cart_checkout_provider.dart';
import 'package:inventory_store_app/screens/customer/widgets/cart/cart_action_header.dart';
import 'package:inventory_store_app/screens/customer/widgets/cart/cart_address_card.dart';
import 'package:inventory_store_app/screens/customer/widgets/cart/cart_checkout_footer.dart';
import 'package:inventory_store_app/screens/customer/widgets/cart/cart_item_card.dart';
import 'package:inventory_store_app/screens/customer/widgets/cart/cart_wallet_summary.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';

class CustomerCartScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;
  const CustomerCartScreen({super.key, this.onTabSelected});

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
    final config = context.read<AppConfigProvider>();
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
    final config = context.read<AppConfigProvider>();
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
    final config = context.watch<AppConfigProvider>();

    final saldoPuntos = wallet.balance ?? 0;
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);

    return CustomerLayout(
      onTabSelected: widget.onTabSelected,
      title: 'Mi Carrito',
      showBackButton: false,
      showProfileIcon: false,
      showBottomNav: true,
      showCartIcon: false,
      currentIndex: 1,
      body:
          cart.items.isEmpty
              ? const AppEmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Tu carrito está vacío',
                message:
                    'Agrega productos desde el catálogo para armar tu pedido.',
              )
              : Column(
                children: [
                  if (checkout.isVerifyingStock)
                    const LinearProgressIndicator(color: AppColors.primary),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 20),
                      itemCount: cart.items.length + 3,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return CartWalletSummary(
                            cart: cart,
                            saldoPuntos: saldoPuntos,
                          );
                        }
                        if (i == 1) {
                          return CartAddressCard(
                            address: checkout.defaultAddress,
                            isLoading: checkout.isLoadingAddress,
                          );
                        }
                        if (i == 2) {
                          return CartActionHeader(cart: cart);
                        }

                        final index = i - 3;
                        final cartItem = cart.items.values.toList()[index];
                        final productId = cart.items.keys.toList()[index];
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
    );
  }
}
