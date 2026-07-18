import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_ucs.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/get_customer_recent_orders_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/get_customer_top_products_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_detail_state.dart';

@injectable
class CustomerDetailCubit extends Cubit<CustomerDetailState> {
  final GetCustomerDetailUseCase _getCustomerDetailUseCase;
  final UpdateCustomerUseCase _updateCustomerUseCase;
  final GetCustomerRecentOrdersUseCase _getRecentOrdersUseCase;
  final GetCustomerTopProductsUseCase _getTopProductsUseCase;

  CustomerDetailCubit(
    this._getCustomerDetailUseCase,
    this._updateCustomerUseCase,
    this._getRecentOrdersUseCase,
    this._getTopProductsUseCase,
  ) : super(CustomerDetailInitial());

  Future<void> loadCustomer(String customerId) async {
    emit(CustomerDetailLoading());
    try {
      final customer = await _getCustomerDetailUseCase(customerId);
      final recentOrders = await _getRecentOrdersUseCase(customerId);
      final topProducts = await _getTopProductsUseCase(customerId);

      emit(
        CustomerDetailLoaded(
          customer: customer,
          recentOrders: recentOrders,
          topProducts: topProducts,
        ),
      );
    } catch (e) {
      emit(CustomerDetailError(e.toString()));
    }
  }

  Future<void> updateCustomer({
    required String customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    bool? isActive,
  }) async {
    final previousState = state;
    emit(CustomerDetailLoading());
    try {
      final updated = await _updateCustomerUseCase(
        customerId: customerId,
        fullName: fullName,
        phone: phone,
        documentNumber: documentNumber,
        documentType: documentType,
        isActive: isActive,
      );

      if (previousState is CustomerDetailLoaded) {
        emit(previousState.copyWith(customer: updated));
      } else {
        await loadCustomer(customerId);
      }
    } catch (e) {
      emit(CustomerDetailError(e.toString()));
      if (previousState is CustomerDetailLoaded) {
        emit(previousState);
      }
    }
  }


}
