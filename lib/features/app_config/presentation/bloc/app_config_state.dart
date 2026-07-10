import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';

class AppConfigState extends Equatable {
  final Map<String, double> values;
  final BusinessInfoEntity? businessInfo;
  final ViewState status;
  final ViewState saveStatus;
  final ViewState connectionStatus;
  final String? errorMessage;

  const AppConfigState({
    this.values = const {},
    this.businessInfo,
    this.status = ViewState.initial,
    this.saveStatus = ViewState.initial,
    this.connectionStatus = ViewState.initial,
    this.errorMessage,
  });

  AppConfigState copyWith({
    Map<String, double>? values,
    BusinessInfoEntity? businessInfo,
    ViewState? status,
    ViewState? saveStatus,
    ViewState? connectionStatus,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AppConfigState(
      values: values ?? this.values,
      businessInfo: businessInfo ?? this.businessInfo,
      status: status ?? this.status,
      saveStatus: saveStatus ?? this.saveStatus,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        values,
        businessInfo,
        status,
        saveStatus,
        connectionStatus,
        errorMessage,
      ];
}
