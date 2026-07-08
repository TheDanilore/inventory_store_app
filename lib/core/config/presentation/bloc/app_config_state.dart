import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/models/business_info_model.dart';

class AppConfigState extends Equatable {
  final Map<String, double> values;
  final BusinessInfoModel? businessInfo;
  final bool isLoadingSettings;
  final bool isLoadingBusinessInfo;
  final String? errorMessage;
  final bool isSaving;
  final bool saveSuccess;

  const AppConfigState({
    this.values = const {},
    this.businessInfo,
    this.isLoadingSettings = false,
    this.isLoadingBusinessInfo = false,
    this.errorMessage,
    this.isSaving = false,
    this.saveSuccess = false,
  });

  AppConfigState copyWith({
    Map<String, double>? values,
    BusinessInfoModel? businessInfo,
    bool? isLoadingSettings,
    bool? isLoadingBusinessInfo,
    String? errorMessage,
    bool? isSaving,
    bool? saveSuccess,
    bool clearErrorMessage = false,
  }) {
    return AppConfigState(
      values: values ?? this.values,
      businessInfo: businessInfo ?? this.businessInfo,
      isLoadingSettings: isLoadingSettings ?? this.isLoadingSettings,
      isLoadingBusinessInfo: isLoadingBusinessInfo ?? this.isLoadingBusinessInfo,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
      saveSuccess: saveSuccess ?? this.saveSuccess,
    );
  }

  @override
  List<Object?> get props => [
        values,
        businessInfo,
        isLoadingSettings,
        isLoadingBusinessInfo,
        errorMessage,
        isSaving,
        saveSuccess,
      ];
}
