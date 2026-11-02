import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_form/customer_form_state.dart';

@injectable
class CustomerFormCubit extends Cubit<CustomerFormState> {
  final SaveCustomerFullProfileUseCase _saveCustomerFullProfileUseCase;
  final GetCreditAccountByCustomerUseCase _getCreditAccountByCustomerUseCase;

  /// L1 Cache en memoria para cuenta de crédito de clientes (Zero-Shimmer garantizado)
  static final Map<String, CustomerCreditEntity> _creditCache = {};

  CustomerFormCubit(
    this._saveCustomerFullProfileUseCase,
    this._getCreditAccountByCustomerUseCase,
  ) : super(CustomerFormInitial());

  /// Carga el crédito del cliente. Si [initialData] o caché L1 están disponibles,
  /// emite [CustomerFormCreditLoaded] de inmediato en Frame 0 sin mostrar estados de carga.
  Future<void> loadCredit(
    String customerId, {
    CustomerCreditEntity? initialData,
  }) async {
    if (initialData != null && !_creditCache.containsKey(customerId)) {
      _creditCache[customerId] = initialData;
    }

    if (_creditCache.containsKey(customerId)) {
      emit(CustomerFormCreditLoaded(_creditCache[customerId]));
      // Revalidación silenciosa en background sin interrumpir UI ni mostrar spinner
      _fetchCreditInBackground(customerId);
      return;
    }

    emit(CustomerFormCreditLoading());
    try {
      final account = await _getCreditAccountByCustomerUseCase(customerId);
      if (account != null) {
        _creditCache[customerId] = account;
      }
      emit(CustomerFormCreditLoaded(account));
    } catch (e) {
      if (e is AppException) {
        emit(CustomerFormError(e.message));
      } else {
        emit(CustomerFormError(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }

  Future<void> _fetchCreditInBackground(String customerId) async {
    try {
      final account = await _getCreditAccountByCustomerUseCase(customerId);
      if (account != null && !isClosed) {
        _creditCache[customerId] = account;
        emit(CustomerFormCreditLoaded(account));
      }
    } catch (_) {
      // Ignorar fallo de red silencioso si ya se cuenta con datos en caché
    }
  }

  /// Invalida manualmente la caché de crédito de un cliente específico
  void invalidateCreditCache(String customerId) {
    _creditCache.remove(customerId);
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
    emit(CustomerFormSaving());
    try {
      await _saveCustomerFullProfileUseCase(
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

      // Invalidar caché tras guardado exitoso para forzar sincronía
      if (customerId != null) {
        _creditCache.remove(customerId);
      }

      emit(CustomerFormSuccess());
    } catch (e) {
      if (e is AppException) {
        emit(CustomerFormError(e.message));
      } else {
        emit(CustomerFormError(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }
}
