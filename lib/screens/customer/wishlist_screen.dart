import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _profileId;
  List<_WishlistEntry> _items = [];

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  // ─── Data ─────────────────────────────────────────────────────────────────

  Future<Map<String, int>> _loadStockByProductIds(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return {};

    final response = await _supabase
        .from('product_stock_summary')
        .select()
        .inFilter('product_id', productIds);

    final stock = <String, int>{};

    for (final row in List<Map<String, dynamic>>.from(response)) {
      final productId = row['product_id'] as String?;

      if (productId == null) continue;

      stock[productId] =
          (stock[productId] ?? 0) +
          ((row['available_quantity'] as num?)?.toDouble().round() ?? 0);
    }

    return stock;
  }

  Future<void> _loadWishlist() async {
    if (mounted) setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final profile =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .maybeSingle();
      final profileId = profile?['id'] as String?;
      if (profileId == null) {
        if (mounted) {
          setState(() {
            _profileId = null;
            _items = [];
          });
        }
        return;
      }
      final response = await _supabase
          .from('wishlist')
          .select(
            'id, profile_id, product_id, created_at, products(id, name, unit_cost, sale_price, description, wholesale_price, wholesale_min_quantity, is_active, product_images(*))',
          )
          .eq('profile_id', profileId)
          .order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(response);
      final productIds =
          rows
              .map(
                (r) =>
                    (r['products'] as Map<String, dynamic>?)?['id'] as String?,
              )
              .whereType<String>()
              .toList();
      final stockByProduct = await _loadStockByProductIds(productIds);
      final entries =
          rows.map((row) {
            final productJson = Map<String, dynamic>.from(
              row['products'] as Map,
            );
            final pid = productJson['id'] as String?;
            final stock = pid == null ? 0 : (stockByProduct[pid] ?? 0);
            return _WishlistEntry(
              wishlistId: row['id'] as String,
              createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
              product: ProductModel.fromJson(
                productJson,
              ).copyWith(totalStock: stock),
            );
          }).toList();
      if (mounted) {
        setState(() {
          _profileId = profileId;
          _items = entries;
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            e.toString().contains('row-level security')
                ? 'La lista de deseos necesita una policy RLS en Supabase.'
                : 'Error al cargar la lista de deseos: $e',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFromWishlist(_WishlistEntry entry) async {
    if (_profileId == null) return;
    try {
      await _supabase
          .from('wishlist')
          .delete()
          .eq('profile_id', _profileId!)
          .eq('product_id', entry.product.id);
      if (!mounted) return;
      setState(
        () => _items.removeWhere((i) => i.wishlistId == entry.wishlistId),
      );
      AppSnackbar.show(context, message: 'Eliminado de tu lista de deseos');
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo eliminar: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _addEntryToCart(_WishlistEntry entry) {
    final cart = context.read<CartProvider>();
    final product = entry.product;
    cart.addItem(
      product,
      quantity: 1,
      availableStock: product.totalStock,
      imageUrl: product.primaryImageUrl,
    );
    AppSnackbar.show(
      context,
      message: '${product.name} añadido al carrito',
      type: SnackbarType.success,
    );
  }

  void _addAllToCart() {
    final cart = context.read<CartProvider>();
    var added = 0;
    for (final entry in _items) {
      // AGREGAMOS LA CONDICIÓN !entry.product.isActive
      if (entry.product.totalStock <= 0 || !entry.product.isActive) {
        continue;
      }
      cart.addItem(
        entry.product,
        quantity: 1,
        availableStock: entry.product.totalStock,
        imageUrl: entry.product.primaryImageUrl,
      );
      added++;
    }
    AppSnackbar.show(
      context,
      message:
          added > 0
              ? '$added producto${added == 1 ? '' : 's'} añadido${added == 1 ? '' : 's'} al carrito'
              : 'No hay productos disponibles para añadir',
      type: added > 0 ? SnackbarType.success : SnackbarType.warning,
    );
  }

  // ─── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildHeaderBanner() {
    final availableCount =
        _items
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
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
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
                      '${_items.length} guardado${_items.length == 1 ? '' : 's'}  ·  $availableCount disponibles',
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
        ],
      ),
    );
  }

  Widget _buildAddAllButton() {
    // EVALUAR STOCK Y ESTADO ACTIVO
    final availableCount =
        _items
            .where((e) => e.product.totalStock > 0 && e.product.isActive)
            .length;
    final canAdd = availableCount > 0;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: canAdd ? _addAllToCart : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canAdd ? AppColors.primary : AppColors.background,
          foregroundColor: canAdd ? Colors.white : AppColors.textHint,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
        label: Text(
          'Añadir todo al carrito ($availableCount)', // ACTUALIZA EL CONTADOR DEL BOTÓN
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildWishlistCard(_WishlistEntry entry) {
    final product = entry.product;
    final imageUrl = product.primaryImageUrl;
    final isActive = product.isActive;
    final inStock = product.totalStock > 0;
    final canBuy = isActive && inStock; //  CONDICIÓN FINAL PARA COMPRAR

    // LÓGICA DE ESTILOS SEGÚN EL ESTADO
    String statusText;
    Color statusColor;
    Color statusBgColor;

    if (!isActive) {
      statusText = 'No disponible';
      statusColor = AppColors.textHint;
      statusBgColor = AppColors.background;
    } else if (inStock) {
      statusText = 'En stock';
      statusColor = AppColors.success;
      statusBgColor = AppColors.success.withValues(alpha: 0.10);
    } else {
      statusText = 'Agotado';
      statusColor = AppColors.error;
      statusBgColor = AppColors.error.withValues(alpha: 0.10);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap:
              () => context.push('/product/${product.id}', extra: product),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Imagen ────────────────────────────────────────────
                // ── Imagen ────────────────────────────────────────────
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child:
                          (imageUrl != null && imageUrl.isNotEmpty)
                              ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      width: 88,
                                      height: 88,
                                      color: AppColors.background,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.textHint,
                                          ),
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => _imgFallback(),
                              )
                              : _imgFallback(),
                    ),
                    // Stock dot
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor, // USA EL COLOR DEFINIDO ARRIBA
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // ── Info ──────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color:
                              isActive
                                  ? AppColors.textPrimary
                                  : AppColors
                                      .textHint, // SE VUELVE GRIS SI NO ESTÁ ACTIVO
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Precio + estado stock en misma línea
                      Row(
                        children: [
                          Text(
                            'S/ ${product.salePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color:
                                  isActive
                                      ? AppColors.primary
                                      : AppColors.textHint,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusBgColor, // USA EL FONDO DINÁMICO
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText, // USA EL TEXTO DINÁMICO
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor, // USA EL COLOR DINÁMICO
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Fecha
                      if (entry.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.bookmark_outline_rounded,
                              size: 11,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'dd MMM yyyy',
                              ).format(entry.createdAt!.toLocal()),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Acciones
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap:
                                  canBuy
                                      ? () => _addEntryToCart(entry)
                                      : null, // AHORA USA canBuy
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color:
                                      canBuy
                                          ? AppColors.primary
                                          : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 15,
                                      color:
                                          canBuy
                                              ? Colors.white
                                              : AppColors.textHint,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      !isActive
                                          ? 'No disponible'
                                          : (inStock
                                              ? 'Al carrito'
                                              : 'Sin stock'), // TEXTO DEL BOTÓN DINÁMICO
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            canBuy
                                                ? Colors.white
                                                : AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Eliminar
                          GestureDetector(
                            onTap: () => _confirmRemove(entry),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                size: 18,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
    width: 88,
    height: 88,
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(
      Icons.inventory_2_outlined,
      size: 32,
      color: AppColors.textSecondary,
    ),
  );

  Future<void> _confirmRemove(_WishlistEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text(
              'Eliminar de deseos',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
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
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
    if (confirm == true) _removeFromWishlist(entry);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      title: 'Mis Deseos',
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: true,
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              )
              : _profileId == null
              ? AppEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Necesitas iniciar sesión',
                message: 'Inicia sesión para ver tu lista de deseos.',
              )
              : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadWishlist,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _buildHeaderBanner(),
                    const SizedBox(height: 14),

                    if (_items.isNotEmpty) ...[
                      _buildAddAllButton(),
                      const SizedBox(height: 16),
                      ..._items.map(_buildWishlistCard),
                    ] else ...[
                      const SizedBox(height: 24),
                      AppEmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'Tu lista está vacía',
                        message:
                            'Toca el corazón en cualquier producto para guardarlo aquí.',
                        action: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.storefront_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Explorar catálogo',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class _WishlistEntry {
  final String wishlistId;
  final DateTime? createdAt;
  final ProductModel product;

  const _WishlistEntry({
    required this.wishlistId,
    required this.createdAt,
    required this.product,
  });
}
