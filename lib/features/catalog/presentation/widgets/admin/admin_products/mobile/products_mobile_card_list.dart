import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/products_mobile_sliver_list.dart';

/// Listado de tarjetas flotantes para móvil estilo Apple / iOS Card-Based.
class ProductsMobileCardList extends StatelessWidget {
  final List<ProductEntity> products;
  final Map<String, String> matchedIngredients;
  final ScrollController? scrollController;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final void Function(ProductEntity product) onTapProduct;
  final void Function(ProductEntity product) onToggleActive;
  final void Function(ProductEntity product) onEdit;
  final void Function(ProductEntity product) onDelete;
  final void Function(ProductEntity product) onOpenFullDetail;

  const ProductsMobileCardList({
    super.key,
    required this.products,
    required this.matchedIngredients,
    this.scrollController,
    this.physics,
    this.shrinkWrap = false,
    required this.onTapProduct,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenFullDetail,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 84),
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      shrinkWrap: shrinkWrap,
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final activeIngredient = matchedIngredients[product.id];
        return ProductsMobileCardItem(
          product: product,
          activeIngredient: activeIngredient,
          onTapProduct: onTapProduct,
          onToggleActive: onToggleActive,
          onEdit: onEdit,
          onDelete: onDelete,
          onOpenFullDetail: onOpenFullDetail,
        );
      },
    );
  }
}
