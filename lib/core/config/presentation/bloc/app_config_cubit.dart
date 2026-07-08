import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/config/domain/usecases/get_app_settings_uc.dart';
import 'package:inventory_store_app/core/config/domain/usecases/get_business_info_uc.dart';
import 'package:inventory_store_app/core/config/domain/usecases/save_business_info_uc.dart';
import 'package:inventory_store_app/core/config/domain/usecases/upload_logo_uc.dart';
import 'package:inventory_store_app/core/config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/core/models/business_info_model.dart';

class AppConfigCubit extends Cubit<AppConfigState> {
  final GetAppSettingsUseCase getAppSettingsUseCase;
  final GetBusinessInfoUseCase getBusinessInfoUseCase;
  final SaveBusinessInfoUseCase saveBusinessInfoUseCase;
  final UploadLogoUseCase uploadLogoUseCase;

  AppConfigCubit({
    required this.getAppSettingsUseCase,
    required this.getBusinessInfoUseCase,
    required this.saveBusinessInfoUseCase,
    required this.uploadLogoUseCase,
  }) : super(const AppConfigState());

  // --- Helpers para compatibilidad con código existente ---
  BusinessInfoModel? get businessInfo => state.businessInfo;
  
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

  ViewState get settingsState => state.isLoadingSettings ? ViewState.loading : ViewState.success; // 1 = loading, 2 = success for ViewState
  ViewState get businessInfoState => state.isLoadingBusinessInfo ? ViewState.loading : ViewState.success;
  ViewState get saveState => state.isSaving ? ViewState.loading : ViewState.success;

  void addListener(Function() listener) {}
  void removeListener(Function() listener) {}

  Future<bool> saveValue(String key, dynamic value, {String? description}) async { return true;
    // Stub for now, to fix compilation. 
  }
  
  Future<bool> saveMultipleValues(Map<String, dynamic> newValues, {Map<String, String>? descriptions}) async {
    // Stub for now
    return true;
  }

  Future<String?> uploadBusinessLogo(Uint8List bytes) async { return null; }

  // --------------------------------------------------------

  
  Future<void> loadConfig() async {
    await fetchSettings();
    await loadBusinessInfo();
  }

  Future<void> fetchSettings() async {
    emit(state.copyWith(isLoadingSettings: true, clearErrorMessage: true));

    final result = await getAppSettingsUseCase.execute(const NoParams());

    result.fold(
      (failure) => emit(state.copyWith(
        isLoadingSettings: false,
        errorMessage: failure.message,
      )),
      (settings) => emit(state.copyWith(
        isLoadingSettings: false,
        values: settings,
      )),
    );
  }

  Future<void> loadBusinessInfo({bool force = false}) async {
    if (state.isLoadingBusinessInfo) return;
    if (state.businessInfo != null && !force) return;

    emit(state.copyWith(isLoadingBusinessInfo: true, clearErrorMessage: true));

    final result = await getBusinessInfoUseCase.execute(const NoParams());

    result.fold(
      (failure) {
        emit(state.copyWith(
          isLoadingBusinessInfo: false,
          errorMessage: failure.message,
          // Si no hay nada, generamos uno por defecto
          businessInfo: state.businessInfo ?? const BusinessInfoModel(
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
          isLoadingBusinessInfo: false,
          businessInfo: info ?? const BusinessInfoModel(
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
    emit(state.copyWith(isSaving: true, clearErrorMessage: true, saveSuccess: false));

    final currentInfo = state.businessInfo ??
        const BusinessInfoModel(
          businessName: '',
          taxId: '',
          address: '',
          phone: '',
          logoUrl: '',
          loyaltyGlobalEnabled: true,
          loyaltyCustomerVisible: true,
        );

    final updatedInfo = currentInfo.copyWith(
      businessName: businessName,
      taxId: taxId,
      address: address,
      phone: phone,
      loyaltyGlobalEnabled: loyaltyGlobalEnabled,
      loyaltyCustomerVisible: loyaltyCustomerVisible,
    );

    final result = await saveBusinessInfoUseCase.execute(updatedInfo);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (savedInfo) {
        emit(state.copyWith(
          isSaving: false,
          saveSuccess: true,
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
    emit(state.copyWith(isSaving: true, clearErrorMessage: true, saveSuccess: false));

    final logoResult = await uploadLogoUseCase.execute(logoBytes);

    return logoResult.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (logoUrl) async {
        final currentInfo = state.businessInfo ??
            const BusinessInfoModel(
              businessName: '',
              taxId: '',
              address: '',
              phone: '',
              logoUrl: '',
              loyaltyGlobalEnabled: true,
              loyaltyCustomerVisible: true,
            );

        final updatedInfo = currentInfo.copyWith(
          businessName: businessName,
          taxId: taxId,
          address: address,
          phone: phone,
          logoUrl: logoUrl,
          loyaltyGlobalEnabled: loyaltyGlobalEnabled,
          loyaltyCustomerVisible: loyaltyCustomerVisible,
        );

        final result = await saveBusinessInfoUseCase.execute(updatedInfo);

        return result.fold(
          (failure) {
            emit(state.copyWith(isSaving: false, errorMessage: failure.message));
            return false;
          },
          (savedInfo) {
            emit(state.copyWith(
              isSaving: false,
              saveSuccess: true,
              businessInfo: savedInfo,
            ));
            return true;
          },
        );
      },
    );
  }
}
