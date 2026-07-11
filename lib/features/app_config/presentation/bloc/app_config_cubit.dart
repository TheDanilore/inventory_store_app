import 'package:injectable/injectable.dart';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/app_config/domain/usecases/get_app_settings_uc.dart';
import 'package:inventory_store_app/features/app_config/domain/usecases/get_business_info_uc.dart';
import 'package:inventory_store_app/features/app_config/domain/usecases/save_business_info_uc.dart';
import 'package:inventory_store_app/features/app_config/domain/usecases/upload_logo_uc.dart';
import 'package:inventory_store_app/features/app_config/domain/usecases/change_connection_uc.dart';
import 'package:inventory_store_app/features/app_config/domain/usecases/restore_default_connection_uc.dart';
import 'package:inventory_store_app/features/app_config/domain/usecases/get_connection_url_uc.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';

@injectable
class AppConfigCubit extends Cubit<AppConfigState> {
  final GetAppSettingsUseCase getAppSettingsUseCase;
  final GetBusinessInfoUseCase getBusinessInfoUseCase;
  final SaveBusinessInfoUseCase saveBusinessInfoUseCase;
  final UploadLogoUseCase uploadLogoUseCase;
  final ChangeConnectionUseCase changeConnectionUseCase;
  final RestoreDefaultConnectionUseCase restoreDefaultConnectionUseCase;
  final GetConnectionUrlUseCase getConnectionUrlUseCase;

  AppConfigCubit({
    required this.getAppSettingsUseCase,
    required this.getBusinessInfoUseCase,
    required this.saveBusinessInfoUseCase,
    required this.uploadLogoUseCase,
    required this.changeConnectionUseCase,
    required this.restoreDefaultConnectionUseCase,
    required this.getConnectionUrlUseCase,
  }) : super(const AppConfigState());

  // --- Helpers para compatibilidad ---
  BusinessInfoEntity? get businessInfo => state.businessInfo;
  
  double getDouble(String key, [double defaultValue = 0.0]) {
    return state.values[key] ?? defaultValue;
  }

  bool get loyaltyGlobalEnabled => state.businessInfo?.loyaltyGlobalEnabled ?? true;
  bool get loyaltyCustomerVisible => state.businessInfo?.loyaltyCustomerVisible ?? true;

  String get businessName => state.businessInfo?.businessName ?? '';
  String get businessTaxId => state.businessInfo?.taxId ?? '';
  String get businessAddress => state.businessInfo?.address ?? '';
  String get businessPhone => state.businessInfo?.phone ?? '';
  String get businessLogoUrl => state.businessInfo?.logoUrl ?? '';


  ViewState get settingsState => state.status;
  ViewState get businessInfoState => state.status;
  ViewState get saveState => state.saveStatus;

  void addListener(Function() listener) {}
  void removeListener(Function() listener) {}

  Future<bool> saveValue(String key, dynamic value, {String? description}) async { return true; }
  
  Future<bool> saveMultipleValues(Map<String, dynamic> newValues, {Map<String, String>? descriptions}) async { return true; }

  Future<String?> uploadBusinessLogo(Uint8List bytes) async { return null; }

  Future<void> loadConfig() async {
    await fetchSettings();
    await loadBusinessInfo();
  }

  Future<void> fetchSettings() async {
    emit(state.copyWith(status: ViewState.loading, clearErrorMessage: true));

    final result = await getAppSettingsUseCase(const NoParams());

    result.fold(
      (failure) => emit(state.copyWith(
        status: ViewState.error,
        errorMessage: failure.message,
      )),
      (settings) => emit(state.copyWith(
        status: ViewState.success,
        values: settings,
      )),
    );
  }

  Future<void> loadConnectionUrl() async {
    final result = await getConnectionUrlUseCase(const NoParams());
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (url) => emit(state.copyWith(connectionUrl: url)),
    );
  }

  Future<void> loadBusinessInfo({bool force = false}) async {
    if (state.status == ViewState.loading) return;
    if (state.businessInfo != null && !force) return;

    emit(state.copyWith(status: ViewState.loading, clearErrorMessage: true));

    final result = await getBusinessInfoUseCase(const NoParams());

    result.fold(
      (failure) {
        emit(state.copyWith(
          status: ViewState.error,
          errorMessage: failure.message,
          businessInfo: state.businessInfo ?? const BusinessInfoEntity(
            businessName: 'Sin configurar',
            taxId: '',
            address: '',
            phone: '',
            logoUrl: '',
            loyaltyGlobalEnabled: true,
            loyaltyCustomerVisible: true,
          ),
        ));
      },
      (info) {
        emit(state.copyWith(
          status: ViewState.success,
          businessInfo: info ?? const BusinessInfoEntity(
            businessName: 'Sin configurar',
            taxId: '',
            address: '',
            phone: '',
            logoUrl: '',
            loyaltyGlobalEnabled: true,
            loyaltyCustomerVisible: true,
          ),
        ));
      },
    );
  }

  Future<bool> saveBusinessInfo({
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
    required bool loyaltyGlobalEnabled,
    required bool loyaltyCustomerVisible,
  }) async {
    emit(state.copyWith(saveStatus: ViewState.loading, clearErrorMessage: true));

    final currentInfo = state.businessInfo ??
        const BusinessInfoEntity(
          businessName: '',
          taxId: '',
          address: '',
          phone: '',
          logoUrl: '',
          loyaltyGlobalEnabled: true,
          loyaltyCustomerVisible: true,
        );

    final updatedInfo = BusinessInfoEntity(
      id: currentInfo.id,
      businessName: businessName,
      taxId: taxId,
      address: address,
      phone: phone,
      logoUrl: currentInfo.logoUrl,
      loyaltyGlobalEnabled: loyaltyGlobalEnabled,
      loyaltyCustomerVisible: loyaltyCustomerVisible,
    );

    final result = await saveBusinessInfoUseCase(updatedInfo);

    return result.fold(
      (failure) {
        emit(state.copyWith(saveStatus: ViewState.error, errorMessage: failure.message));
        return false;
      },
      (savedInfo) {
        emit(state.copyWith(
          saveStatus: ViewState.success,
          businessInfo: savedInfo,
        ));
        return true;
      },
    );
  }

  Future<bool> saveLogoAndInfo({
    required Uint8List logoBytes,
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
    required bool loyaltyGlobalEnabled,
    required bool loyaltyCustomerVisible,
  }) async {
    emit(state.copyWith(saveStatus: ViewState.loading, clearErrorMessage: true));

    final logoResult = await uploadLogoUseCase(logoBytes);

    return logoResult.fold(
      (failure) {
        emit(state.copyWith(saveStatus: ViewState.error, errorMessage: failure.message));
        return false;
      },
      (logoUrl) async {
        final currentInfo = state.businessInfo ??
            const BusinessInfoEntity(
              businessName: '',
              taxId: '',
              address: '',
              phone: '',
              logoUrl: '',
              loyaltyGlobalEnabled: true,
              loyaltyCustomerVisible: true,
            );

        final updatedInfo = BusinessInfoEntity(
          id: currentInfo.id,
          businessName: businessName,
          taxId: taxId,
          address: address,
          phone: phone,
          logoUrl: logoUrl,
          loyaltyGlobalEnabled: loyaltyGlobalEnabled,
          loyaltyCustomerVisible: loyaltyCustomerVisible,
        );

        final result = await saveBusinessInfoUseCase(updatedInfo);

        return result.fold(
          (failure) {
            emit(state.copyWith(saveStatus: ViewState.error, errorMessage: failure.message));
            return false;
          },
          (savedInfo) {
            emit(state.copyWith(
              saveStatus: ViewState.success,
              businessInfo: savedInfo,
            ));
            return true;
          },
        );
      },
    );
  }

  Future<void> changeConnection(String url, String key) async {
    emit(state.copyWith(
      connectionStatus: ViewState.loading,
      clearErrorMessage: true,
    ));

    final result = await changeConnectionUseCase(ChangeConnectionParams(url: url, key: key));

    result.fold(
      (failure) => emit(state.copyWith(
        connectionStatus: ViewState.error,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(connectionStatus: ViewState.success)),
    );
  }

  Future<void> restoreDefaultConnection() async {
    emit(state.copyWith(
      connectionStatus: ViewState.loading,
      clearErrorMessage: true,
    ));

    final result = await restoreDefaultConnectionUseCase(const NoParams());

    result.fold(
      (failure) => emit(state.copyWith(
        connectionStatus: ViewState.error,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(connectionStatus: ViewState.success)),
    );
  }
}
