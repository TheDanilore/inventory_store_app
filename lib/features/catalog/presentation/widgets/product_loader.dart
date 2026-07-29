import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/product_detail_screen.dart';

class ProductLoader extends StatelessWidget {
  final String productId;
  final bool isAdmin;
  final String? initialVariantId;

  const ProductLoader({
    super.key,
    required this.productId,
    required this.isAdmin,
    this.initialVariantId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) =>
              sl<ProductDetailCubit>()..loadProduct(
                productId,
                isAdmin: isAdmin,
                initialVariantId: initialVariantId,
              ),
      child: BlocBuilder<ProductDetailCubit, ProductDetailState>(
        builder: (context, state) {
          // 1. Verificamos si está cargando o en estado inicial
          if (state.viewState == ViewState.initial ||
              state.viewState == ViewState.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 2. Verificamos si hubo un error
          if (state.viewState == ViewState.error) {
            return Scaffold(
              body: Center(
                child: Text(state.errorMessage ?? 'Ocurrió un error'),
              ),
            );
          }

          // 3. Verificamos si se cargó exitosamente
          if (state.viewState == ViewState.success) {
            final product = state.product;
            if (product == null) {
              return const Scaffold(
                body: Center(child: Text('Producto no encontrado')),
              );
            }

            return ProductDetailScreen(
              product: product,
              isAdmin: isAdmin,
              initialVariantId: initialVariantId,
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
