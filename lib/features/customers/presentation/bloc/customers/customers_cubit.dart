import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/export_customers_pdf_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';

@lazySingleton
class CustomersCubit extends Cubit<CustomersState> {
  final GetCustomersUseCase _getCustomersUseCase;
  final ExportCustomersPdfUseCase _exportPdfUseCase;

  static const int _limit = 20;
  static const Duration _freshWindow = Duration(minutes: 3);
  static const String _tag = 'CUSTOMERS_CUBIT';

  Timer? _searchTimer;
  int _requestSeq = 0;
  bool _isFetchingMore = false;
  DateTime? _lastLoadedAt;
  int _activeTabIndex = 0;

  CustomersCubit(this._getCustomersUseCase, this._exportPdfUseCase)
    : super(CustomersInitial());

  /// Garantiza carga Zero-Shimmer al entrar o regresar a la pantalla de clientes.
  Future<void> ensureLoaded() async {
    final currentState = state;
    if (currentState is CustomersLoaded) {
      final isFresh =
          _lastLoadedAt != null &&
          DateTime.now().difference(_lastLoadedAt!) < _freshWindow;
      if (isFresh) {
        return;
      }
      await fetchCustomers(
        reset: true,
        query: currentState.query,
        showOnlyWithDebt: currentState.showOnlyWithDebt,
        silent: true,
        forceRefresh: true,
      );
      return;
    }

    final cached = _getCustomersUseCase.getCached(
      limit: _limit,
      offset: 0,
      query: '',
      showOnlyWithDebt: false,
    );
    if (cached != null) {
      _lastLoadedAt = DateTime.now();
      if (!isClosed) {
        emit(
          CustomersLoaded(
            customers: cached.data.customers,
            hasReachedMax: !cached.data.hasMore,
            totalCount: cached.data.totalCount,
            activeTabIndex: _activeTabIndex,
            isFromCache: true,
            isRefreshing: cached.isStale,
          ),
        );
      }
      if (cached.isStale) {
        await fetchCustomers(reset: true, silent: true, forceRefresh: true);
      }
      return;
    }

    await fetchCustomers(reset: true);
  }

  void setActiveTab(int index) {
    _activeTabIndex = index;
    final current = state;
    if (current is CustomersLoaded && current.activeTabIndex != index) {
      if (!isClosed) emit(current.copyWith(activeTabIndex: index));
    }
  }

  Future<void> fetchCustomers({
    bool reset = false,
    String? query,
    bool? showOnlyWithDebt,
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final currentState = state;

    if (!reset) {
      if (currentState is! CustomersLoaded ||
          currentState.hasReachedMax ||
          currentState.isLoadingMore ||
          _isFetchingMore) {
        return;
      }

      _isFetchingMore = true;
      final seq = _requestSeq;
      if (!isClosed) {
        emit(
          currentState.copyWith(
            isLoadingMore: true,
            clearTransientError: true,
          ),
        );
      }

      try {
        final result = await _getCustomersUseCase(
          limit: _limit,
          offset: currentState.customers.length,
          query: currentState.query,
          showOnlyWithDebt: currentState.showOnlyWithDebt,
          forceRefresh: forceRefresh,
        );

        if (isClosed || seq != _requestSeq) return;

        final latest = state;
        if (latest is! CustomersLoaded) return;

        result.fold(
          (failure) {
            emit(
              latest.copyWith(
                isLoadingMore: false,
                transientErrorMessage: failure.message,
              ),
            );
          },
          (page) {
            final seenIds = latest.customers.map((e) => e.id).toSet();
            final merged = <CustomerEntity>[
              ...latest.customers,
              ...page.customers.where((e) => seenIds.add(e.id)),
            ];
            emit(
              latest.copyWith(
                customers: merged,
                hasReachedMax: !page.hasMore,
                totalCount: page.totalCount,
                isLoadingMore: false,
                isFromCache: false,
                clearTransientError: true,
              ),
            );
          },
        );
      } finally {
        _isFetchingMore = false;
      }
      return;
    }

    // Ruta RESET / Búsqueda / Cambio de filtro
    _isFetchingMore = false;
    final seq = ++_requestSeq;
    final targetQuery =
        (query ?? (currentState is CustomersLoaded ? currentState.query : ''))
            .trim();
    final targetDebt =
        showOnlyWithDebt ??
        (currentState is CustomersLoaded
            ? currentState.showOnlyWithDebt
            : false);
    if (showOnlyWithDebt != null && _activeTabIndex != 2) {
      _activeTabIndex = showOnlyWithDebt ? 1 : 0;
    }

    if (!forceRefresh) {
      final cached = _getCustomersUseCase.getCached(
        limit: _limit,
        offset: 0,
        query: targetQuery,
        showOnlyWithDebt: targetDebt,
      );
      if (cached != null) {
        _lastLoadedAt = DateTime.now();
        if (!isClosed) {
          emit(
            CustomersLoaded(
              customers: cached.data.customers,
              hasReachedMax: !cached.data.hasMore,
              totalCount: cached.data.totalCount,
              query: targetQuery,
              showOnlyWithDebt: targetDebt,
              activeTabIndex: _activeTabIndex,
              isRefreshing: cached.isStale && !silent,
              isFromCache: true,
            ),
          );
        }
        if (!cached.isStale) {
          return;
        }
      }
    }

    final hasVisibleAfterCacheCheck = state is CustomersLoaded;
    if (!hasVisibleAfterCacheCheck && !silent) {
      if (!isClosed) emit(CustomersLoading());
    } else if (state is CustomersLoaded) {
      if (!isClosed) {
        emit(
          (state as CustomersLoaded).copyWith(
            query: targetQuery,
            showOnlyWithDebt: targetDebt,
            activeTabIndex: _activeTabIndex,
            isRefreshing: true,
            clearTransientError: true,
          ),
        );
      }
    }

    final result = await _getCustomersUseCase(
      limit: _limit,
      offset: 0,
      query: targetQuery,
      showOnlyWithDebt: targetDebt,
      forceRefresh: forceRefresh,
    );

    if (isClosed || seq != _requestSeq) return;

    result.fold(
      (failure) {
        final latest = state;
        if (latest is CustomersLoaded &&
            (latest.customers.isNotEmpty || silent)) {
          emit(
            latest.copyWith(
              isRefreshing: false,
              transientErrorMessage: failure.message,
            ),
          );
        } else {
          emit(CustomersError(failure));
        }
      },
      (page) {
        _lastLoadedAt = DateTime.now();
        emit(
          CustomersLoaded(
            customers: page.customers,
            hasReachedMax: !page.hasMore,
            totalCount: page.totalCount,
            query: targetQuery,
            showOnlyWithDebt: targetDebt,
            activeTabIndex: _activeTabIndex,
            isRefreshing: false,
            isFromCache: false,
          ),
        );
      },
    );
  }

  Future<void> exportPdf() async {
    final current = state;
    if (current is! CustomersLoaded || current.isExportingPdf) return;

    if (!isClosed) {
      emit(current.copyWith(isExportingPdf: true, clearTransientError: true));
    }

    try {
      await _exportPdfUseCase(current.customers);
      if (isClosed) return;
      final latest = state;
      if (latest is CustomersLoaded) {
        emit(latest.copyWith(isExportingPdf: false));
      }
    } catch (e, stack) {
      LoggerService.e(
        'Error al exportar PDF de clientes',
        tag: _tag,
        error: e,
        stackTrace: stack,
      );
      if (isClosed) return;
      final latest = state;
      if (latest is CustomersLoaded) {
        emit(
          latest.copyWith(
            isExportingPdf: false,
            transientErrorMessage: 'No se pudo generar el PDF de clientes.',
          ),
        );
      }
    }
  }

  void dismissTransientError() {
    final current = state;
    if (current is CustomersLoaded && current.transientErrorMessage != null) {
      if (!isClosed) emit(current.copyWith(clearTransientError: true));
    }
  }

  void search(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      fetchCustomers(reset: true, query: query);
    });
  }

  void toggleDebtFilter(bool showDebt) {
    _searchTimer?.cancel();
    _activeTabIndex = showDebt ? 1 : 0;
    fetchCustomers(reset: true, showOnlyWithDebt: showDebt);
  }

  void invalidateCache() {
    _lastLoadedAt = null;
    _getCustomersUseCase.invalidateCache();
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
