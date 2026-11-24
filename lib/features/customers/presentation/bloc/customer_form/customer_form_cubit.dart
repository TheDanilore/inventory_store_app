import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/data/cache/customers_lru_cache.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_form/customer_form_state.dart';

@injectable
class CustomerFormCubit extends Cubit<CustomerFormState> {
  final SaveCustomerFullProfileUseCase _saveCustomerFullProfileUseCase;
  final GetCreditAccountByCustomerUseCase _getCreditAccountByCustomerUseCase;
  final CustomersLruCache _cache;

  static const String _tag = 'CUSTOMER_FORM_CUBIT';

  CustomerFormCubit(
    this._saveCustomerFullProfileUseCase,
    this._getCreditAccountByCustomerUseCase,
    this._cache,
  ) : super(CustomerFormInitial());

  /// Carga el crédito del cliente. Si [initialData] o caché L1 LRU están disponibles,
  /// emite [CustomerFormCreditLoaded] de inmediato en Frame 0 (Zero-Shimmer).
  Future<void> loadCredit(
    String customerId, {
    CustomerCreditEntity? initialData,
  }) async {
    final cached = _cache.getCredit(customerId);
    if (cached != null) {
      if (!isClosed) emit(CustomerFormCreditLoaded(cached));
      _fetchCreditInBackground(customerId);
      return;
    }

    if (initialData != null) {
      _cache.putCredit(customerId, initialData);
      if (!isClosed) emit(CustomerFormCreditLoaded(initialData));
      _fetchCreditInBackground(customerId);
      return;
    }

    if (!isClosed) emit(CustomerFormCreditLoading());
    final result = await _getCreditAccountByCustomerUseCase(customerId);
    if (isClosed) return;

    result.fold(
      (failure) {
        LoggerService.e(
          'Error cargando cuenta de crédito en CustomerFormCubit: ${failure.message}',
          tag: _tag,
        );
        emit(CustomerFormError(failure.message));
      },
      (account) {
        if (account != null) {
          _cache.putCredit(customerId, account);
        }
        emit(CustomerFormCreditLoaded(account));
      },
    );
  }

  Future<void> _fetchCreditInBackground(String customerId) async {
    final result = await _getCreditAccountByCustomerUseCase(customerId);
    if (isClosed) return;

    result.fold(
      (failure) => LoggerService.w(
        'Fallo de revalidación de crédito en segundo plano para $customerId: ${failure.message}',
        tag: _tag,
      ),
      (account) {
        if (account != null) {
          _cache.putCredit(customerId, account);
          emit(CustomerFormCreditLoaded(account));
        }
      },
    );
  }

  /// Invalida manualmente la caché de crédito de un cliente específico.
  void invalidateCreditCache(String customerId) {
    _cache.invalidateCredit(customerId);
  }

  Future<void> save({
    String? customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    required bool isActive,
    required int walletAdjustDelta,
    required double currentWalletBalance,
    required bool hasCredit,
    required bool creditExistsInDb,
    String? creditId,
    required bool creditIsActive,
    required double newCreditLimit,
  }) async {
    if (!isClosed) emit(CustomerFormSaving());

    final result = await _saveCustomerFullProfileUseCase(
      customerId: customerId,
      fullName: fullName,
      phone: phone,
      documentNumber: documentNumber,
      documentType: documentType,
      isActive: isActive,
      walletAdjustDelta: walletAdjustDelta,
      currentWalletBalance: currentWalletBalance,
      hasCredit: hasCredit,
      creditExistsInDb: creditExistsInDb,
      creditId: creditId,
      creditIsActive: creditIsActive,
      newCreditLimit: newCreditLimit,
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        LoggerService.e(
          'Error al guardar perfil de cliente: ${failure.message}',
          tag: _tag,
        );
        emit(CustomerFormError(failure.message));
      },
      (_) {
        if (customerId != null) {
          _cache.invalidateCredit(customerId);
        }
        emit(CustomerFormSuccess());
      },
    );
  }
}
