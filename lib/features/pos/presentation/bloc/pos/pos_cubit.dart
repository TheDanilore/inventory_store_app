import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
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

  /// Refresca únicamente las cuentas y el turno activo sin descargar almacenes (Data Egress óptimo).
  Future<void> refreshAccountsAndShift() async {
    final res = await _posRepository.fetchFinancialAccounts();
    res.fold(
      (failure) {
        LoggerService.e(
          'Error al refrescar cuentas',
          tag: 'PosCubit',
          error: failure.message,
        );
      },
      (accounts) {
        emit(state.copyWith(accounts: accounts));
        final activeAccId = state.selectedAccountId;
        if (activeAccId != null) {
          checkActiveShift(activeAccId);
        }
      },
    );
  }

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
        LoggerService.e('Error loading initial POS data', tag: 'PosCubit', error: failure.message);
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
        String? initialWarehouseId;

        if (data.warehouses.isNotEmpty) {
          initialWarehouseId = data.warehouses.first.id;
        }

        if (data.accounts.isNotEmpty) {
          final firstAcc = data.accounts.firstWhere(
            (a) => PosCalculatorUtils.accountRequiresShift(a),
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
            selectedWarehouseId:
                initialWarehouseId ?? state.selectedWarehouseId,
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

  void updateAccountBalanceLocal({
    required String accountId,
    required double deltaAmount,
  }) {
    final updated = state.accounts.map((acc) {
      if (acc['id'] == accountId) {
        final currentBal = (acc['balance'] as num?)?.toDouble() ?? 0.0;
        final newMap = Map<String, dynamic>.from(acc);
        newMap['balance'] = currentBal + deltaAmount;
        return newMap;
      }
      return acc;
    }).toList();
    emit(state.copyWith(accounts: updated));
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

  Future<void> fetchRecentOrders({
    bool forceRefresh = false,
    String? query,
  }) async {
    final effectiveQuery = query ?? state.salesSearchQuery;
    if (!forceRefresh &&
        query == null &&
        state.recentOrders.isNotEmpty &&
        state.salesSearchQuery.isEmpty) {
      return;
    }

    emit(
      state.copyWith(
        isLoadingRecentOrders: true,
        recentOrdersError: '',
        salesSearchQuery: effectiveQuery,
      ),
    );

    // En paralelo, traer las órdenes paginadas y el resumen agregado del día
    final ordersFuture = _posRepository.fetchRecentOrders(
      limit: 20,
      offset: 0,
      searchQuery: effectiveQuery,
    );
    final summaryFuture = fetchDailySalesSummary();

    final result = await ordersFuture;
    await summaryFuture;

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
          state.copyWith(
            isLoadingRecentOrders: false,
            recentOrders: orders,
            hasMoreOrders: orders.length == 20,
          ),
        );
      },
    );
  }

  Future<void> loadMoreRecentOrders() async {
    if (state.isLoadingRecentOrders ||
        state.isLoadingMoreOrders ||
        !state.hasMoreOrders) {
      return;
    }

    emit(state.copyWith(isLoadingMoreOrders: true));

    final currentOffset = state.recentOrders.length;
    final result = await _posRepository.fetchRecentOrders(
      limit: 20,
      offset: currentOffset,
      searchQuery: state.salesSearchQuery,
    );

    result.fold(
      (failure) {
        LoggerService.w(
          'Error cargando más órdenes',
          tag: 'PosCubit',
          error: failure.message,
        );
        emit(state.copyWith(isLoadingMoreOrders: false));
      },
      (newOrders) {
        emit(
          state.copyWith(
            isLoadingMoreOrders: false,
            recentOrders: [...state.recentOrders, ...newOrders],
            hasMoreOrders: newOrders.length == 20,
          ),
        );
      },
    );
  }

  Future<void> fetchDailySalesSummary() async {
    final summaryRes = await _posRepository.fetchDailySalesSummary();
    summaryRes.fold(
      (failure) {
        LoggerService.w(
          'Error al obtener resumen de ventas del día',
          tag: 'PosCubit',
          error: failure.message,
        );
      },
      (summary) {
        emit(
          state.copyWith(
            dailyTotalAmount: summary.totalAmount,
            dailyTotalCount: summary.totalCount,
          ),
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
          LoggerService.e('Error searching clients', tag: 'PosCubit', error: failure.message);
        },
        (matches) {
          emit(state.copyWith(clientMatches: matches));
        },
      );
    } catch (e, stack) {
      LoggerService.e(
        'Unexpected error searching clients',
        tag: 'PosCubit',
        error: e,
        stackTrace: stack,
      );
    }
  }

  void clearActiveShift() {
    emit(state.copyWith(clearActiveShift: true));
  }

  Future<void> checkActiveShift(String accountId) async {
    final account = state.accounts.firstWhere(
      (a) => a['id'] == accountId,
      orElse: () => <String, dynamic>{},
    );
    if (!PosCalculatorUtils.accountRequiresShift(account)) {
      emit(state.copyWith(clearActiveShift: true));
      return;
    }

    try {
      final shiftRes = await _checkActiveShiftUc.call(accountId);
      shiftRes.fold(
        (failure) {
          LoggerService.e('Error checking active shift', tag: 'PosCubit', error: failure.message);
          emit(
            state.copyWith(
              status: PosStatus.error,
              errorMessage: 'Error verificando turno: ${failure.message}',
              clearActiveShift: true, // ensure null when failing
            ),
          );
        },
        (shift) {
          if (shift == null) {
            emit(state.copyWith(clearActiveShift: true));
          } else {
            emit(state.copyWith(activeShift: shift));
          }
        },
      );
    } catch (e, stack) {
      LoggerService.e(
        'Unexpected error checking active shift',
        tag: 'PosCubit',
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
          LoggerService.e('Error fetching client credit', tag: 'PosCubit', error: failure.message);
        },
        (creditInfo) {
          emit(state.copyWith(creditInfo: creditInfo));
        },
      );
    } catch (e, stack) {
      LoggerService.e(
        'Unexpected error fetching client credit',
        tag: 'PosCubit',
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
      LoggerService.e(
        'Unexpected error fetching batches',
        tag: 'PosCubit',
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
          LoggerService.e('Error processing sale', tag: 'PosCubit', error: failure.message);
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
      LoggerService.e(
        'Unexpected error processing sale',
        tag: 'PosCubit',
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
