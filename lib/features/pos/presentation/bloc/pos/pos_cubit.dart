import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/load_initial_pos_data_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_order_details_uc.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/check_active_shift_uc.dart';
import 'package:inventory_store_app/features/pos/domain/entities/sale_entity.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'dart:developer' as developer;

@injectable
class PosCubit extends Cubit<PosState> {
  final LoadInitialPosDataUseCase _loadInitialPosData;
  final GetOrderDetailsUc _getOrderDetails;
  final PosRepository _posRepository;
  final CheckActiveShiftUc _checkActiveShiftUc;

  PosCubit({
    required LoadInitialPosDataUseCase loadInitialPosData,
    required GetOrderDetailsUc getOrderDetails,
    required PosRepository posRepository,
    required CheckActiveShiftUc checkActiveShiftUc,
  }) : _loadInitialPosData = loadInitialPosData,
       _getOrderDetails = getOrderDetails,
       _posRepository = posRepository,
       _checkActiveShiftUc = checkActiveShiftUc,
       super(const PosState());
  int _searchRequestId = 0;

  Future<void> initPosData({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        state.warehouses.isNotEmpty &&
        state.accounts.isNotEmpty) {
      return; // Hit caché de datos iniciales
    }
    emit(state.copyWith(isLoading: true, errorMessage: ''));

    final res = await _loadInitialPosData(
      LoadInitialPosDataParams(forceRefresh: forceRefresh),
    );
    res.fold(
      (failure) {
        developer.log('Error loading initial POS data', error: failure.message);
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
            status: PosStatus.error,
          ),
        );
      },
      (data) {
        String? initialAccountId;
        String? initialPaymentMethod;

        if (data.accounts.isNotEmpty) {
          final firstAcc = data.accounts.firstWhere(
            (a) => a['type'] == 'CAJA' || a['type'] == 'CASH_REGISTER',
            orElse: () => data.accounts.first,
          );
          initialAccountId = firstAcc['id'] as String;
          if (state.paymentMethod != 'CRÉDITO') {
            initialPaymentMethod = firstAcc['name'] as String? ?? 'EFECTIVO';
          }
        }

        emit(
          state.copyWith(
            isLoading: false,
            warehouses: data.warehouses,
            accounts: data.accounts,
            selectedAccountId: initialAccountId,
            paymentMethod: initialPaymentMethod ?? state.paymentMethod,
          ),
        );

        if (initialAccountId != null) {
          checkActiveShift(initialAccountId);
        }
      },
    );
  }

  void setClient(String id, String name, int saldo) {
    emit(
      state.copyWith(
        selectedClientId: id,
        selectedClientName: name,
        saldoActualCliente: saldo,
        clientMatches: const [],
      ),
    );
  }

  void removeClient() {
    emit(state.copyWith(clearClient: true));
  }

  void setPuntosAUsar(int puntos) {
    emit(state.copyWith(puntosAUsar: puntos));
  }

  void setPaymentMethod(String method) {
    emit(state.copyWith(paymentMethod: method));
  }

  void setWarehouse(String? id) {
    emit(state.copyWith(selectedWarehouseId: id));
  }

  void setSelectedAccountId(String? accountId) {
    emit(state.copyWith(selectedAccountId: accountId));
    if (accountId != null) {
      checkActiveShift(accountId);
    }
  }

  void setBatchOverride(
    String cartKey,
    List<BatchAssignmentModel> assignments,
  ) {
    final overrides = Map<String, List<BatchAssignmentModel>>.from(
      state.batchOverrides,
    );
    overrides[cartKey] = assignments;
    emit(state.copyWith(batchOverrides: overrides));
  }

  void clearBatchOverride(String cartKey) {
    final overrides = Map<String, List<BatchAssignmentModel>>.from(
      state.batchOverrides,
    );
    overrides.remove(cartKey);
    emit(state.copyWith(batchOverrides: overrides));
  }

  void clearAllBatchOverrides() {
    emit(state.copyWith(batchOverrides: {}));
  }

  Future<void> fetchRecentOrders({bool forceRefresh = false}) async {
    if (!forceRefresh && state.recentOrders.isNotEmpty) {
      return;
    }
    emit(state.copyWith(isLoadingRecentOrders: true, recentOrdersError: ''));

    final result = await _posRepository.fetchRecentOrders(limit: 10);
    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isLoadingRecentOrders: false,
            recentOrdersError: failure.message,
          ),
        );
      },
      (orders) {
        emit(
          state.copyWith(isLoadingRecentOrders: false, recentOrders: orders),
        );
      },
    );
  }

  Future<Either<Failure, OrderDetailsResult>> fetchOrderDetailsForTicket(
    String orderId,
  ) async {
    return await _getOrderDetails.call(orderId);
  }

  void resetStatus() {
    emit(state.copyWith(status: PosStatus.initial, errorMessage: ''));
  }

  Future<void> searchClients(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      emit(state.copyWith(clientMatches: []));
      return;
    }

    final requestId = ++_searchRequestId;

    try {
      final response = await _posRepository.searchClients(text);
      if (_searchRequestId != requestId) return; // Race condition abort

      response.fold(
        (failure) {
          developer.log('Error searching clients', error: failure.message);
        },
        (matches) {
          emit(state.copyWith(clientMatches: matches));
        },
      );
    } catch (e, stack) {
      developer.log(
        'Unexpected error searching clients',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> checkActiveShift(String accountId) async {
    final account = state.accounts.firstWhere(
      (a) => a['id'] == accountId,
      orElse: () => {},
    );
    // Remove magic string 'CAJA'. Ideally this maps to an enum.
    final accountType = account['type']?.toString().toUpperCase();
    if (accountType != 'CAJA' && accountType != 'CASH_REGISTER') {
      emit(state.copyWith(activeShift: null)); // Trick to nullify if not caja
      return;
    }

    try {
      final shiftRes = await _checkActiveShiftUc.call(accountId);
      shiftRes.fold(
        (failure) {
          developer.log('Error checking active shift', error: failure.message);
          emit(
            state.copyWith(
              status: PosStatus.error,
              errorMessage: 'Error verificando turno: ${failure.message}',
              activeShift: null, // ensure null when failing
            ),
          );
        },
        (shift) {
          emit(state.copyWith(activeShift: shift)); // Can be null if closed
        },
      );
    } catch (e, stack) {
      developer.log(
        'Unexpected error checking active shift',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> fetchClientCredit(String clientId) async {
    try {
      final response = await _posRepository.fetchClientCredit(clientId);
      response.fold(
        (failure) {
          developer.log('Error fetching client credit', error: failure.message);
        },
        (creditInfo) {
          emit(state.copyWith(creditInfo: creditInfo));
        },
      );
    } catch (e, stack) {
      developer.log(
        'Unexpected error fetching client credit',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<Either<Failure, List<BatchAssignmentModel>>> fetchBatchesForVariant(
    String variantId,
    String warehouseId,
  ) async {
    try {
      return await _posRepository.fetchBatchesForVariant(
        variantId,
        warehouseId,
      );
    } catch (e, stack) {
      developer.log(
        'Unexpected error fetching batches',
        error: e,
        stackTrace: stack,
      );
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  void setDiscountText(String text) {
    emit(state.copyWith(discountText: text));
  }

  void setIsDiscountPercentage(bool isPercentage) {
    emit(state.copyWith(isDiscountPercentage: isPercentage, discountText: ''));
  }

  Future<void> processSale({
    required CartState cartState,
    required double pointsToSolesRatio,
    required double earningRate,
    required String? customClientName,
    required String? accountId,
    required CashShiftEntity? activeShift,
    bool isDraft = false,
  }) async {
    emit(state.copyWith(status: PosStatus.loading));
    try {
      final totalFinal = PosCalculatorUtils.calcularTotalFinal(
        discountText: state.discountText,
        isDiscountPercentage: state.isDiscountPercentage,
        pos: state,
        cart: cartState,
        ratio: pointsToSolesRatio,
      );

      final puntosUsados = PosCalculatorUtils.clampPointsValue(
        state.puntosAUsar,
        state,
        cartState,
        pointsToSolesRatio,
      );

      final totalProfit = PosCalculatorUtils.calcularGananciaTotal(
        discountText: state.discountText,
        isDiscountPercentage: state.isDiscountPercentage,
        pos: state,
        cart: cartState,
        ratio: pointsToSolesRatio,
      );

      final descuentoExtra = PosCalculatorUtils.getCustomDiscountAmount(
        discountText: state.discountText,
        isDiscountPercentage: state.isDiscountPercentage,
        pos: state,
        cart: cartState,
        ratio: pointsToSolesRatio,
      );

      final isCredito = state.paymentMethod == 'CRÉDITO';

      final saleItems =
          cartState.items.values.map((item) {
            return SaleItemEntity(
              productId: item.productId,
              variantId: item.variantId,
              quantity: item.quantity,
              unitCost: item.unitCost,
              appliedPrice: item.unitPrice,
              batchAssignments: state.batchOverrides[item.cartKey] ?? [],
            );
          }).toList();

      final sale = SaleEntity(
        items: saleItems,
        warehouseId: state.selectedWarehouseId!,
        paymentMethod: state.paymentMethod,
        totalAmount: totalFinal,
        totalProfit: totalProfit,
        customerId: state.selectedClientId,
        customerName: state.selectedClientName ?? customClientName,
        accountId: accountId,
        paymentStatus:
            isCredito ? SalePaymentStatus.pending : SalePaymentStatus.paid,
        discountAmount: descuentoExtra,
        amountPaid: isCredito ? 0 : totalFinal,
        pointsUsed: puntosUsados,
        pointsEarned: PosCalculatorUtils.calcularPuntosGanados(
          total: totalFinal,
          rate: earningRate,
        ),
        isDraft: isDraft,
        isCredit: isCredito,
        activeShift: activeShift,
      );

      final result = await _posRepository.processSale(sale);
      result.fold(
        (failure) {
          developer.log('Error processing sale', error: failure.message);
          emit(
            state.copyWith(
              status: PosStatus.error,
              errorMessage: failure.message,
            ),
          );
        },
        (orderId) {
          emit(state.copyWith(status: PosStatus.success, lastOrderId: orderId));
          // Refrescar caché de ventas recientes sin bloquear la UI
          fetchRecentOrders(forceRefresh: true);
        },
      );
    } catch (e, stack) {
      developer.log(
        'Unexpected error processing sale',
        error: e,
        stackTrace: stack,
      );
      emit(
        state.copyWith(
          status: PosStatus.error,
          errorMessage: 'Error inesperado procesando la venta',
        ),
      );
    }
  }
}
