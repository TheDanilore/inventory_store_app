import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
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
      create: (_) => sl<ProductDetailCubit>()..loadProduct(productId),
      child: BlocBuilder<ProductDetailCubit, ProductDetailState>(
        builder: (context, state) {
          if (state is ProductDetailLoading || state is ProductDetailInitial) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is ProductDetailError) {
            return Scaffold(body: Center(child: Text(state.message)));
          }

          if (state is ProductDetailLoaded) {
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
