import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_by_id_usecase.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_state.dart';

@injectable
class ProductDetailCubit extends Cubit<ProductDetailState> {
  final GetProductByIdUseCase _getProductByIdUseCase;

  ProductDetailCubit(this._getProductByIdUseCase) : super(ProductDetailInitial());

  Future<void> loadProduct(String productId) async {
    emit(ProductDetailLoading());
    final result = await _getProductByIdUseCase(productId);
    result.fold(
      (failure) => emit(ProductDetailError(failure.message)),
      (product) => emit(ProductDetailLoaded(product)),
    );
  }
}
