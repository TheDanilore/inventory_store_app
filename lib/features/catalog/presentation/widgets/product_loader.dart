import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/product_detail_screen.dart';

class ProductLoader extends StatelessWidget {
  final String productId;
  final String? initialVariantId;

  const ProductLoader({
    super.key,
    required this.productId,
    this.initialVariantId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) =>
              sl<ProductDetailCubit>()..loadProduct(
                productId,
                initialVariantId: initialVariantId,
              ),
      child: BlocBuilder<ProductDetailCubit, ProductDetailState>(
        builder: (context, state) {
          if (state.viewState == ViewState.initial ||
              state.viewState == ViewState.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.viewState == ViewState.error) {
            return Scaffold(
              body: Center(
                child: Text(state.errorMessage ?? 'Ocurrió un error'),
              ),
            );
          }

          if (state.viewState == ViewState.success) {
            final product = state.product;
            if (product == null) {
              return const Scaffold(
                body: Center(child: Text('Producto no encontrado')),
              );
            }

            return ProductDetailScreen(
              product: product,
              initialVariantId: initialVariantId,
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
