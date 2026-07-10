import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/customer_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/customer/catalog/catalog_product_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/customer/catalog/catalog_shimmers.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

class CatalogProductGrid extends StatelessWidget {
  final Future<void> Function(ProductEntity) onAddToCart;

  const CatalogProductGrid({super.key, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CustomerCatalogCubit>().state;

    if (state.viewState == ViewState.initial &&
        state.viewState == ViewState.loading) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 0.58,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 4,
        itemBuilder: (_, _) => const CatalogProductShimmer(),
      );
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        color: Colors.red,
        title: 'Ocurrió un error',
        message: state.errorMessage!,
        action: ElevatedButton.icon(
          onPressed: context.read<CustomerCatalogCubit>().loadInitialData,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      );
    }

    if (state.products.isEmpty) {
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
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 0.58,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: state.products.length,
          itemBuilder: (context, index) {
            final product = state.products[index];
            return CatalogProductCard(
              product: product,
              onAddToCart: onAddToCart,
            );
          },
        ),
        if (state.viewState == ViewState.loading &&
            state.viewState != ViewState.initial)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: CircularProgressIndicator(),
          ),
        const SizedBox(height: 24), // Espacio al final
      ],
    );
  }
}
