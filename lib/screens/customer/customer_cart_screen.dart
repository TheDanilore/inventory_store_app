import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';
import 'package:inventory_store_app/screens/customer/address_management_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:inventory_store_app/screens/shared/product_detail_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';

class CustomerCartScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;
  const CustomerCartScreen({super.key, this.onTabSelected});

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  final _supabase = Supabase.instance.client;
  bool _isSending = false;
  bool _usarPuntos = false;
  Map<String, dynamic>? _defaultAddress;

  @override
  void initState() {
    super.initState();
    _cargarDireccion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarStockEnTiempoReal();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _cargarDireccion() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final profile =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', user.id)
                .single();

        final address =
            await _supabase
                .from('user_addresses')
                .select('*')
                .eq('profile_id', profile['id'])
                .eq('is_default', true)
                .maybeSingle();

        if (mounted) {
          setState(() {
            _defaultAddress = address;
          });
        }
      } catch (e) {
        debugPrint('Error cargando dirección: $e');
      }
    }
  }

  Future<void> _verificarStockEnTiempoReal() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;
    try {
      final warehouseResp =
          await _supabase
              .from('warehouses')
              .select('id')
              .eq('is_active', true)
              .limit(1)
              .maybeSingle();
      if (warehouseResp == null) return;
      final warehouseId = warehouseResp['id'];

      for (final entry in cart.items.entries) {
        final item = entry.value;
        if (item.variantId != null) {
          // Cambiamos a warehouse_stock_batches y available_quantity
          final stockResp = await _supabase
              .from('warehouse_stock_batches')
              .select('available_quantity')
              .eq('warehouse_id', warehouseId)
              .eq('variant_id', item.variantId!);

          // Sumamos la cantidad de todos los lotes disponibles para esta variante
          final realStock = List<Map<String, dynamic>>.from(
            stockResp,
          ).fold<int>(
            0,
            (sum, row) =>
                sum + ((row['available_quantity'] as num?)?.toInt() ?? 0),
          );

          cart.updateItemStock(entry.key, realStock);
        }
      }
    } catch (e) {
      debugPrint('Error verificando stock: $e');
    }
  }

  double _wholesalePriceOf(CartItemModel item) {
    // Ya no necesitas castear con "as CartItemModel"
    final product = item.product;
    return item.wholesalePrice ?? product.wholesalePrice ?? item.unitPrice;
  }

  double _maxDiscountSoles(CartProvider cart) {
    double total = 0;
    // ¡Solo calcula descuento sobre ítems SELECCIONADOS!
    for (final item in cart.selectedItems) {
      final unitPrice = item.unitPrice;
      final qty = item.quantity;
      final wholesalePrice = _wholesalePriceOf(item);
      final marginalDescuento = (unitPrice - wholesalePrice).clamp(
        0.0,
        double.infinity,
      );
      total += marginalDescuento * qty;
    }
    return total;
  }

  int _calculateApplicablePoints(
    CartProvider cart,
    double pointsToSolesRatio,
    int saldoPuntos,
  ) {
    if (!_usarPuntos || saldoPuntos <= 0) return 0;
    final maxSoles = _maxDiscountSoles(cart);
    final maxPoints = (maxSoles / pointsToSolesRatio).toInt();
    return saldoPuntos > maxPoints ? maxPoints : saldoPuntos;
  }

  double _calculateFinalTotal(
    CartProvider cart,
    double pointsToSolesRatio,
    int saldoPuntos,
  ) {
    final descuento =
        _calculateApplicablePoints(cart, pointsToSolesRatio, saldoPuntos) *
        pointsToSolesRatio;
    final total = cart.selectedTotalAmount - descuento; // Sobre seleccionados
    return total < 0 ? 0.0 : total;
  }

  // Calcula exactamente cuántas monedas caen en un ítem específico
  int _getAppliedPointsForItem(
    CartProvider cart,
    String targetCartKey,
    int saldoPuntos,
  ) {
    if (!_usarPuntos || saldoPuntos <= 0) return 0;
    final config = context.read<AppConfigProvider>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);

    int remainingPoints = saldoPuntos;
    // Solo distribuye puntos entre los SELECCIONADOS
    for (final item in cart.selectedItems) {
      final wholesale = _wholesalePriceOf(item);
      final marginal = (item.unitPrice - wholesale).clamp(0.0, double.infinity);

      // SOLUCIÓN: Declaramos explícitamente como 'int'
      final int maxItemPoints =
          ((marginal * item.quantity) / pointsToSolesRatio).toInt();
      final int applied =
          remainingPoints > maxItemPoints ? maxItemPoints : remainingPoints;

      if (item.cartKey == targetCartKey) {
        return applied;
      }

      remainingPoints -= applied;
      if (remainingPoints <= 0) break;
    }
    return 0;
  }
  // ─── Navegar al detalle del producto ─────────────────────────────────────

  Future<void> _openProductDetail(CartItemModel cartItem) async {
    // Ya no necesitas castear con "as ProductModel"
    final product = cartItem.product;
    try {
      // Consulta a la vista precalculada o a los lotes
      final stockResp = await _supabase
          .from('warehouse_stock_batches')
          .select('available_quantity')
          .eq('product_id', product.id);

      // Sumamos el stock de todos los lotes
      final totalStock = List<Map<String, dynamic>>.from(stockResp).fold<int>(
        0,
        (s, r) => s + ((r['available_quantity'] as num?)?.toInt() ?? 0),
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => ProductDetailScreen(
                product: product.copyWith(totalStock: totalStock),
              ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      );
    }
  }
  // ─── Cambiar variante de un ítem ─────────────────────────────────────────

  Future<void> _showVariantPicker(
    BuildContext context,
    CartProvider cart,
    String productId,
    CartItemModel cartItem, // <-- Cambiado de dynamic a CartItemModel
  ) async {
    // Ya no necesitas castear con "as ProductModel"
    final product = cartItem.product;
    final productId2 = product.id;

    List<ProductVariantModel> variants = [];
    Map<String, int> stockByVariant = {};
    try {
      final varResp = await _supabase
          .from('product_variants')
          .select(
            // Añadir unit_cost a la consulta
            'id, product_id, sku, attributes, product_images(*), sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, unit_cost',
          )
          .eq('product_id', productId2)
          .eq('is_active', true)
          .order('created_at', ascending: true);
      variants =
          List<Map<String, dynamic>>.from(
            varResp,
          ).map(ProductVariantModel.fromJson).toList();

      // Cambiamos tabla y columna
      final invResp = await _supabase
          .from('warehouse_stock_batches')
          .select('variant_id, available_quantity')
          .eq('product_id', productId2);

      for (final row in List<Map<String, dynamic>>.from(invResp)) {
        final vid = row['variant_id'] as String?;
        if (vid == null) continue;
        // Sumamos las cantidades de los diferentes lotes de la variante
        stockByVariant[vid] =
            (stockByVariant[vid] ?? 0) +
            ((row['available_quantity'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}

    if (!context.mounted || variants.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _VariantPickerSheet(
            product: product,
            variants: variants,
            stockByVariant: stockByVariant,
            currentVariantId: cartItem.variantId,
            cartItemImageUrl: cartItem.imageUrl,
            onSelect: (variant, stock) {
              cart.removeItem(productId);
              cart.addItem(
                product,
                quantity: cartItem.quantity,
                variantId: variant.id,
                variantLabel: variant.label,
                unitPrice: variant.salePrice ?? product.salePrice,
                wholesalePrice:
                    variant.wholesalePrice ?? product.wholesalePrice,
                // 🟢 2. Enviar el costo unitario real al carrito
                unitCost: variant.unitCost ?? product.unitCost,
                imageUrl:
                    variant.images.isNotEmpty
                        ? variant.images.first.imageUrl
                        : cartItem.imageUrl,
                sku: variant.sku,
                availableStock: stock,
              );
            },
          ),
    );
  }

  // ─── Tarjeta Dirección ────────────────────────────────────────────────────
  Widget _buildAddressCard() {
    final hasAddress = _defaultAddress != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddressManagementScreen(),
              ),
            );
            if (mounted) _cargarDireccion();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12), // Reducido de 14 a 12
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    hasAddress
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.border,
                width: hasAddress ? 1.5 : 1,
              ),
              boxShadow:
                  hasAddress
                      ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : [],
            ),
            child: Row(
              children: [
                Container(
                  width: 36, // Reducido de 42
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primary.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 18, // Reducido de 20
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      hasAddress
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dirección de envío',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_defaultAddress!['address_line']}, ${_defaultAddress!['district']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_defaultAddress!['reference'] != null) ...[
                                Text(
                                  'Ref: ${_defaultAddress!['reference']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          )
                          : const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sin dirección',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Toca para agregar',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header de acciones (Seleccionar / Borrar) ──────────────────────────
  Widget _buildActionHeader(BuildContext context, CartProvider cart) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: cart.isAllSelected,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (val) {
                    if (val != null) cart.toggleAllSelection(val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Seleccionar todo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (cart.selectedItemCount > 0)
            TextButton.icon(
              onPressed: () {
                cart.removeSelectedItems();
                AppSnackbar.show(context, message: 'Productos eliminados.');
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.error,
              ),
              label: const Text(
                'Eliminar',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWalletSummary(
    BuildContext context,
    CartProvider cart,
    int saldoPuntos,
  ) {
    final config = context.watch<AppConfigProvider>();
    final earningRate = config.getDouble('points_earning_rate', 0.03);
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final puntosSolicitados = _calculateApplicablePoints(
      cart,
      pointsToSolesRatio,
      saldoPuntos,
    );
    final totalFinal = _calculateFinalTotal(
      cart,
      pointsToSolesRatio,
      saldoPuntos,
    );
    final puntosAGanar =
        (totalFinal * earningRate / pointsToSolesRatio).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14), // Reducido de 18 a 14
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, // Reducido de 38
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: AppColors.gold,
                    size: 18, // Reducido de 20
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monedas disponibles',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$saldoPuntos monedas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15, // Reducido de 16
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildToggle(saldoPuntos),
              ],
            ),
            if (_usarPuntos && puntosSolicitados > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Se aplicarán $puntosSolicitados monedas → -S/ ${(puntosSolicitados * pointsToSolesRatio).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  size: 12,
                  color: Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  'Ganarás $puntosAGanar monedas con este pedido',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(int saldoPuntos) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            saldoPuntos > 0
                ? () => setState(() => _usarPuntos = !_usarPuntos)
                : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, // Reducido de 52
          height: 24, // Reducido de 28
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                _usarPuntos && saldoPuntos > 0
                    ? AppColors.gold
                    : Colors.white.withValues(alpha: 0.15),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment:
                _usarPuntos && saldoPuntos > 0
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 20, // Reducido de 22
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
  // ─── Cart Item Card ───────────────────────────────────────────────────────

  Widget _buildCartItem(
    BuildContext context,
    CartProvider cart,
    String productId,
    CartItemModel cartItem, // <-- Cambiado de dynamic a CartItemModel
    int saldoPuntos,
  ) {
    // Ya no necesitas usar "as double" ni "as int"
    final unitPrice = cartItem.unitPrice;
    final quantity = cartItem.quantity;
    final lineTotal = unitPrice * quantity;
    final hasVariant = cartItem.variantLabel != null;

    final appliedPoints = _getAppliedPointsForItem(
      cart,
      productId,
      saldoPuntos,
    );
    final bool isMaxStockReached = quantity >= cartItem.availableStock;
    final bool isSelected = cartItem.isSelected;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.transparent : AppColors.border,
          width: 1,
        ),
        boxShadow:
            isSelected
                ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
                : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openProductDetail(cartItem),
          child: Padding(
            padding: const EdgeInsets.all(10), // Reducido de 12
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (_) => cart.toggleItemSelection(productId),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      (cartItem.imageUrl != null ||
                              cartItem.product.images.isNotEmpty)
                          ? CachedNetworkImage(
                            imageUrl:
                                cartItem.imageUrl ??
                                cartItem.product.images.first.imageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder:
                                (_, __) => const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (_, __, ___) => _buildImagePlaceholder(),
                          )
                          : _buildImagePlaceholder(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Opacity(
                    opacity: isSelected ? 1.0 : 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cartItem.product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13, // Reducido de 14
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasVariant) ...[
                          const SizedBox(height: 4),
                          Material(
                            color: AppColors.primary.withValues(alpha: 0.07),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                            child: InkWell(
                              onTap:
                                  () => _showVariantPicker(
                                    context,
                                    cart,
                                    productId,
                                    cartItem,
                                  ),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      cartItem.variantLabel!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.expand_more_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        if (_usarPuntos && appliedPoints > 0 && isSelected) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.goldLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  size: 10,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Aplicando $appliedPoints monedas',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF8A6300),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'S/ ${unitPrice.toStringAsFixed(2)} c/u',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'S/ ${lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    _stepperButton(
                      icon: Icons.add_rounded,
                      isDisabled: isMaxStockReached,
                      onTap: () {
                        cart.setQuantity(productId, quantity + 1);
                        if (!isSelected) cart.toggleItemSelection(productId);
                      },
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap:
                            () => _mostrarDialogoCantidad(
                              context,
                              cart,
                              productId,
                              quantity,
                              cartItem.availableStock,
                            ),
                        child: Container(
                          width: 28, // Reducido
                          height: 28,
                          alignment: Alignment.center,
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _stepperButton(
                      icon: Icons.remove_rounded,
                      isRemove: true,
                      onTap: () => cart.removeSingleItem(productId),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool isRemove = false,
    bool isDisabled = false,
  }) {
    return Material(
      color:
          isDisabled
              ? Colors.grey.shade100
              : isRemove
              ? AppColors.accent.withValues(alpha: 0.08)
              : AppColors.primary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28, // Reducido de 32 a 28
          height: 28,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color:
                isDisabled
                    ? Colors.grey.shade400
                    : isRemove
                    ? AppColors.accent
                    : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutFooter(
    BuildContext context,
    CartProvider cart,
    int saldoPuntos,
  ) {
    final config = context.watch<AppConfigProvider>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final puntosAplicables = _calculateApplicablePoints(
      cart,
      pointsToSolesRatio,
      saldoPuntos,
    );
    final descuento = puntosAplicables * pointsToSolesRatio;

    final totalFinal =
        (cart.selectedTotalAmount - descuento) < 0
            ? 0.0
            : (cart.selectedTotalAmount - descuento);
    final isOrderReady = cart.selectedItemCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), // Reducido de 20 a 16
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_usarPuntos && puntosAplicables > 0) ...[
              _buildPriceRow(
                'Subtotal (${cart.selectedItemCount})',
                'S/ ${cart.selectedTotalAmount.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 4),
              _buildPriceRow(
                'Descuento monedas',
                '-S/ ${descuento.toStringAsFixed(2)}',
                valueColor: AppColors.success,
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total a pagar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'S/',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          totalFinal.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -1,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isOrderReady
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${cart.selectedItemCount} ${cart.selectedItemCount == 1 ? 'prod.' : 'prods.'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color:
                          isOrderReady
                              ? AppColors.primary
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50, // Reducido de 56 a 50
              child: ElevatedButton(
                onPressed:
                    (_isSending || !isOrderReady)
                        ? null
                        : () => _procesarPedido(context, cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  disabledBackgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child:
                    _isSending
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                        : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Enviar por WhatsApp',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 64,
      height: 64,
      color: AppColors.background,
      child: const Icon(
        Icons.image_outlined,
        size: 26,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final wallet = Provider.of<WalletProvider>(context);
    final saldoPuntos = wallet.balance ?? 0;

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
              ? AppEmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Tu carrito está vacío',
                message:
                    'Agrega productos desde el catálogo para armar tu pedido.',
              )
              : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 20),
                      // +3: Wallet, Direccion, ActionHeader
                      itemCount: cart.items.length + 3,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _buildWalletSummary(
                            context,
                            cart,
                            saldoPuntos,
                          );
                        }
                        if (i == 1) return _buildAddressCard();
                        if (i == 2) return _buildActionHeader(context, cart);

                        final index = i - 3;
                        final cartItem = cart.items.values.toList()[index];
                        final productId = cart.items.keys.toList()[index];
                        return _buildCartItem(
                          context,
                          cart,
                          productId,
                          cartItem,
                          saldoPuntos,
                        );
                      },
                    ),
                  ),
                  _buildCheckoutFooter(context, cart, saldoPuntos),
                ],
              ),
    );
  }

  Future<void> _procesarPedido(BuildContext context, CartProvider cart) async {
    // AQUÍ ESTÁ LA SOLUCIÓN: Casteamos explícitamente a List<CartItemModel>
    final List<CartItemModel> itemsToBuy =
        cart.selectedItems.cast<CartItemModel>().toList();

    if (itemsToBuy.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final config = context.read<AppConfigProvider>();
      final saldoPuntos = context.read<WalletProvider>().balance ?? 0;
      final earningRate = config.getDouble('points_earning_rate', 0.03);
      final pointsToSolesRatio = config.getDouble(
        'points_to_soles_ratio',
        0.01,
      );

      final warehouseResp =
          await _supabase
              .from('warehouses')
              .select('id')
              .eq('is_active', true)
              .limit(1)
              .maybeSingle();
      if (warehouseResp == null) throw Exception('No hay almacenes activos.');
      final warehouseId = warehouseResp['id'];

      // ─── NUEVA VALIDACIÓN PREVIA DE STOCK EN TIEMPO REAL ───
      List<String> outOfStockMessages = [];

      for (final item in itemsToBuy) {
        final safeVariantId = item.variantId ?? '';

        // Cambiamos a warehouse_stock_batches y removemos el .maybeSingle()
        final stockResp = await _supabase
            .from('warehouse_stock_batches')
            .select('available_quantity')
            .eq('warehouse_id', warehouseId)
            .eq('variant_id', safeVariantId);

        // Sumamos el stock disponible en los lotes
        final currentStock = List<Map<String, dynamic>>.from(
          stockResp,
        ).fold<int>(
          0,
          (sum, row) =>
              sum + ((row['available_quantity'] as num?)?.toInt() ?? 0),
        );

        // Si el stock actual es menor a lo que quiere comprar, bloqueamos
        if (currentStock < item.quantity) {
          final variantLabel =
              item.variantLabel != null ? ' - ${item.variantLabel}' : '';
          outOfStockMessages.add(
            '• ${item.product.name}$variantLabel (Stock disponible: $currentStock, Tu pedido: ${item.quantity})',
          );
        }
      }

      // Mostrar alerta si falta stock y detener el proceso
      if (outOfStockMessages.isNotEmpty) {
        if (mounted) {
          showDialog(
            // ignore: use_build_context_synchronously
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text(
                    'Stock Insuficiente',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    'Lo sentimos, el stock ha variado y algunos productos ya no están disponibles en las cantidades solicitadas:\n\n${outOfStockMessages.join('\n')}',
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
        }
        setState(() => _isSending = false);
        return; // Detenemos la operación antes de crear la orden
      }
      // ─── FIN VALIDACIÓN ───

      String? customerId;
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        final profileResp =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', currentUser.id)
                .maybeSingle();
        customerId = profileResp?['id'];
      }

      final puntosUsados =
          customerId != null
              ? _calculateApplicablePoints(
                cart,
                pointsToSolesRatio,
                saldoPuntos,
              )
              : 0;
      final totalAPagar = _calculateFinalTotal(
        cart,
        pointsToSolesRatio,
        saldoPuntos,
      );
      final puntosAGanar =
          (totalAPagar * earningRate / pointsToSolesRatio).toInt();

      // Calcular la ganancia total real sumando las ganancias netas
      double totalProfit = 0.0;
      for (final item in itemsToBuy) {
        totalProfit += (item.unitPrice - item.unitCost) * item.quantity;
      }

      final orderResp =
          await _supabase
              .from('orders')
              .insert({
                'customer_id': customerId,
                'total_amount': totalAPagar,
                'points_used': puntosUsados,
                'points_earned': puntosAGanar,
                // Usar la ganancia calculada en lugar de 0
                'total_profit': totalProfit,
                'payment_method': 'POR ACORDAR',
                'status': 'PENDING',
                'warehouse_id': warehouseId,
              })
              .select('id')
              .single();

      final orderId = orderResp['id'];

      // Inserta solo los seleccionados
      final itemsToInsert =
          itemsToBuy.map((item) {
            return {
              'order_id': orderId,
              'product_id': item.product.id,
              'variant_id': item.variantId,
              'quantity': item.quantity,
              // Usar item.unitCost
              'unit_cost': item.unitCost,
              'applied_price': item.unitPrice,
              // Calcular usando item.unitCost
              'net_profit': (item.unitPrice - item.unitCost) * item.quantity,
            };
          }).toList();

      await _supabase.from('order_items').insert(itemsToInsert);

      final orderIdCorto = orderId.toString().substring(0, 8).toUpperCase();

      await _enviarPedidoWhatsApp(
        itemsToBuy,
        orderIdCorto,
        totalAPagar,
        puntosUsados,
      );

      // Remueve los ítems del carrito que ya se compraron
      cart.removeSelectedItems();

      // Forzar recarga del saldo por si la Base de Datos aplicó un trigger al restar/sumar
      if (context.mounted) {
        await context.read<WalletProvider>().refresh();
      }

      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: '¡Pedido registrado!',
          backgroundColor: AppColors.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          backgroundColor: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _enviarPedidoWhatsApp(
    List<CartItemModel> selectedItems,
    String orderIdCorto,
    double totalAPagar,
    int puntosUsados,
  ) async {
    const numeroTienda = '51936081881';
    final sb = StringBuffer();
    sb.writeln(
      '👋 Hola, deseo realizar el pago de mi pedido (*#$orderIdCorto*):',
    );

    for (var item in selectedItems) {
      sb.writeln(
        '• ${item.quantity}x ${item.product.name} (S/ ${item.unitPrice.toStringAsFixed(2)})',
      );
    }

    if (puntosUsados > 0) {
      sb.writeln('');
      sb.writeln('*Monedas solicitadas:* $puntosUsados');
    }

    if (_defaultAddress != null) {
      sb.writeln('');
      sb.writeln('*📍 Dirección de envío:*');
      sb.writeln(
        '${_defaultAddress!['address_line']}, ${_defaultAddress!['district']}',
      );
      if (_defaultAddress!['reference'] != null) {
        sb.writeln('Ref: ${_defaultAddress!['reference']}');
      }
    }

    sb.writeln('');
    sb.writeln('*Total a Pagar: S/ ${totalAPagar.toStringAsFixed(2)}*');
    sb.writeln('');
    sb.writeln(
      'Por favor, indícame los números de cuenta (Yape/Plin/Transferencia). ¡Quedo a la espera!',
    );

    final url = Uri.parse(
      'https://wa.me/$numeroTienda?text=${Uri.encodeComponent(sb.toString())}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppSnackbar.show(context, message: 'No se pudo abrir WhatsApp.');
      }
    }
  }

  Future<void> _mostrarDialogoCantidad(
    BuildContext context,
    CartProvider cart,
    String productId,
    int cantidadActual,
    int availableStock,
  ) async {
    final qtyCtrl = TextEditingController(text: cantidadActual.toString());
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad exacta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                // Muestra el límite al usuario:
                helperText: 'Stock máximo disponible: $availableStock',
                helperStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  final newQty = int.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    cart.setQuantity(productId, newQty);
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}

// ─── Variant Picker Bottom Sheet ──────────────────────────────────────────────

class _VariantPickerSheet extends StatelessWidget {
  final ProductModel product;
  final List<ProductVariantModel> variants;
  final Map<String, int> stockByVariant;
  final String? currentVariantId;
  final String? cartItemImageUrl;
  final void Function(ProductVariantModel variant, int stock) onSelect;

  const _VariantPickerSheet({
    required this.product,
    required this.variants,
    required this.stockByVariant,
    required this.currentVariantId,
    this.cartItemImageUrl,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // ─── SOLUCIÓN: Agregamos SingleChildScrollView aquí ───
      child: SingleChildScrollView(
        // Añadimos el padding.bottom del dispositivo para evitar que la barra de navegación tape el último item
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).padding.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const Text(
              'Cambiar variante',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ...variants.map((variant) {
              final stock = stockByVariant[variant.id] ?? 0;
              final isOut = stock <= 0;
              final isCurrent = variant.id == currentVariantId;

              final String? displayImageUrl =
                  variant.images.isNotEmpty
                      ? variant.images.first.imageUrl
                      : (product.images.isNotEmpty
                          ? product.images.first.imageUrl
                          : cartItemImageUrl);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color:
                      isCurrent
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color:
                          isCurrent
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.border,
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap:
                        isOut
                            ? null
                            : () {
                              Navigator.pop(context);
                              onSelect(variant, stock);
                            },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child:
                                displayImageUrl != null
                                    ? CachedNetworkImage(
                                      imageUrl: displayImageUrl,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (_, __) => const Center(
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                      errorWidget:
                                          (_, __, ___) => _imgFallback(),
                                    )
                                    : _imgFallback(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  variant.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isOut
                                            ? AppColors.textHint
                                            : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      'S/ ${(variant.salePrice ?? product.salePrice).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color:
                                            isOut
                                                ? AppColors.textHint
                                                : AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isOut ? 'Agotado' : '$stock en stock',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            isOut
                                                ? AppColors.error
                                                : AppColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            )
                          else if (!isOut)
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.textHint,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
    width: 48,
    height: 48,
    color: AppColors.background,
    child: const Icon(
      Icons.image_outlined,
      size: 22,
      color: AppColors.textSecondary,
    ),
  );
}
