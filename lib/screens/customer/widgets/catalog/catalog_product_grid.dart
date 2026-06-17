import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/customer/catalog_provider.dart';
import 'package:inventory_store_app/screens/customer/widgets/catalog/catalog_product_card.dart';
import 'package:inventory_store_app/screens/customer/widgets/catalog/catalog_shimmers.dart';
import 'package:inventory_store_app/models/product_model.dart';

class CatalogProductGrid extends StatelessWidget {
  final Future<void> Function(ProductModel) onAddToCart;

  const CatalogProductGrid({super.key, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerCatalogProvider>();

    if (provider.isInitialLoad && provider.isLoadingProducts) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.58,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 4,
        itemBuilder: (_, _) => const CatalogProductShimmer(),
      );
    }

    if (provider.productsError != null && provider.products.isEmpty) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        color: Colors.red,
        title: 'Ocurrió un error',
        message: provider.productsError!,
        action: ElevatedButton.icon(
          onPressed: provider.refreshProducts,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      );
    }

    if (provider.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'No se encontraron productos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Prueba buscando otra cosa o cambiando de categoría.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.58,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: provider.products.length,
          itemBuilder: (context, index) {
            final product = provider.products[index];
            return CatalogProductCard(
              product: product,
              onAddToCart: onAddToCart,
            );
          },
        ),
        if (provider.isLoadingProducts && !provider.isInitialLoad)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: CircularProgressIndicator(),
          ),
        const SizedBox(height: 80), // Espacio para scroll y FAB
      ],
    );
  }
}
