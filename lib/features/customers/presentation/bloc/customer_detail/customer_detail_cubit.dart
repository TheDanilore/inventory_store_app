import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/recent_order_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/get_customer_recent_orders_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/get_customer_top_products_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_detail/customer_detail_state.dart';

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
      final results = await Future.wait([
        _getCustomerDetailUseCase(customerId),
        _getRecentOrdersUseCase(customerId),
        _getTopProductsUseCase(customerId),
      ]);

      emit(
        CustomerDetailLoaded(
          customer: results[0] as CustomerEntity,
          recentOrders: results[1] as List<RecentOrderEntity>,
          topProducts: results[2] as List<TopProductEntity>,
        ),
      );
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error loading customer detail for $customerId',
        error: e,
        stackTrace: stackTrace,
      );
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
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error updating customer $customerId',
        error: e,
        stackTrace: stackTrace,
      );
      emit(CustomerDetailError(e.toString()));
      if (previousState is CustomerDetailLoaded) {
        emit(previousState);
      }
    }
  }
}
