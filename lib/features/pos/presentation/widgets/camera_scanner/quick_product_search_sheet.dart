import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

/// Modal rápido para buscar productos por nombre o SKU e insertarlos al carrito.
class QuickProductSearchSheet extends StatefulWidget {
  final String? warehouseId;
  final ValueChanged<ProductEntity> onProductSelected;

  const QuickProductSearchSheet({
    super.key,
    required this.warehouseId,
    required this.onProductSelected,
  });

  static Future<void> show(
    BuildContext context, {
    String? warehouseId,
    required ValueChanged<ProductEntity> onProductSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetCtx) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: QuickProductSearchSheet(
              warehouseId: warehouseId,
              onProductSelected: onProductSelected,
            ),
          ),
    );
  }

  @override
  State<QuickProductSearchSheet> createState() =>
      _QuickProductSearchSheetState();
}

class _QuickProductSearchSheetState extends State<QuickProductSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<ProductEntity> _products = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final repo = sl<ProductsRepository>();
      final res = await repo.getProducts(
        searchQuery: query.trim().isEmpty ? null : query.trim(),
        limit: 25,
        isActive: true,
      );
      if (!mounted) return;
      res.fold(
        (failure) => setState(() => _products = []),
        (data) => setState(() => _products = data.products),
      );
    } catch (_) {
      if (mounted) setState(() => _products = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.manage_search_rounded,
                  color: AppColors.teal,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Buscar Producto por Nombre o SKU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onChanged,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E293B),
                hintText: 'Escribe ej: Arroz, Fideo, Aceite, Leche...',
                hintStyle: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.teal,
                  size: 20,
                ),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            _performSearch('');
                          },
                        )
                        : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.teal,
                        strokeWidth: 2.5,
                      ),
                    )
                    : _products.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _searchCtrl.text.isEmpty
                              ? 'No hay productos disponibles.'
                              : 'No se encontraron productos para "${_searchCtrl.text}".',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _products.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final price = product.displaySalePrice ?? 0.0;
                        return InkWell(
                          onTap: () => widget.onProductSelected(product),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child:
                                      product.primaryImageUrl != null
                                          ? Image.network(
                                            product.primaryImageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      color: Colors.white38,
                                                      size: 20,
                                                    ),
                                          )
                                          : const Icon(
                                            Icons.inventory_2_outlined,
                                            color: Colors.white38,
                                            size: 20,
                                          ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            'S/ ${price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Color(0xFF34D399),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (product.brandName != null &&
                                              product
                                                  .brandName!
                                                  .isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              product.brandName!,
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton(
                                  onPressed:
                                      () => widget.onProductSelected(product),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.teal,
                                    foregroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  child: const Text('+ Agregar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
