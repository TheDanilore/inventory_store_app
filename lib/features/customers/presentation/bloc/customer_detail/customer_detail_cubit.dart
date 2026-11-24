import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
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

  static const String _tag = 'CUSTOMER_DETAIL_CUBIT';

  CustomerDetailCubit(
    this._getCustomerDetailUseCase,
    this._updateCustomerUseCase,
    this._getRecentOrdersUseCase,
    this._getTopProductsUseCase,
  ) : super(CustomerDetailInitial());

  void initWithCustomer(CustomerEntity customer) {
    if (state is CustomerDetailInitial && !isClosed) {
      emit(
        CustomerDetailLoaded(
          customer: customer,
          recentOrders: const [],
          topProducts: const [],
        ),
      );
    }
  }

  Future<void> loadCustomer(String customerId) async {
    final previousState = state;
    if (previousState is! CustomerDetailLoaded && !isClosed) {
      emit(CustomerDetailLoading());
    }

    final (detailResult, ordersResult, productsResult) =
        await (
          _getCustomerDetailUseCase(customerId),
          _getRecentOrdersUseCase(customerId),
          _getTopProductsUseCase(customerId),
        ).wait;

    if (isClosed) return;

    final orders = ordersResult.fold<List<RecentOrderEntity>>((failure) {
      LoggerService.w(
        'Error loading recent orders for $customerId: ${failure.message}',
        tag: _tag,
      );
      return previousState is CustomerDetailLoaded
          ? previousState.recentOrders
          : const [];
    }, identity);

    final products = productsResult.fold<List<TopProductEntity>>((failure) {
      LoggerService.w(
        'Error loading top products for $customerId: ${failure.message}',
        tag: _tag,
      );
      return previousState is CustomerDetailLoaded
          ? previousState.topProducts
          : const [];
    }, identity);

    detailResult.fold(
      (failure) {
        LoggerService.e(
          'Error loading customer detail for $customerId: ${failure.message}',
          tag: _tag,
        );
        if (previousState is CustomerDetailLoaded) {
          emit(previousState);
        } else {
          emit(CustomerDetailError(failure.message));
        }
      },
      (customer) {
        emit(
          CustomerDetailLoaded(
            customer: customer,
            recentOrders: orders,
            topProducts: products,
          ),
        );
      },
    );
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
    if (!isClosed) emit(CustomerDetailLoading());

    final Either<Failure, CustomerEntity> result = await _updateCustomerUseCase(
      customerId: customerId,
      fullName: fullName,
      phone: phone,
      documentNumber: documentNumber,
      documentType: documentType,
      isActive: isActive,
    );

    if (isClosed) return;

    await result.fold(
      (failure) async {
        LoggerService.e(
          'Error updating customer $customerId: ${failure.message}',
          tag: _tag,
        );
        emit(CustomerDetailError(failure.message));
        if (previousState is CustomerDetailLoaded) {
          emit(previousState);
        }
      },
      (updated) async {
        if (previousState is CustomerDetailLoaded) {
          emit(previousState.copyWith(customer: updated));
        } else {
          await loadCustomer(customerId);
        }
      },
    );
  }
}
