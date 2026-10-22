import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/currency_entity.dart';

class AppConfigState extends Equatable {
  final Map<String, double> values;
  final BusinessInfoEntity? businessInfo;
  final List<CurrencyEntity> currencies;
  final ViewState status;
  final ViewState saveStatus;
  final ViewState connectionStatus;
  final String? connectionUrl;
  final String? errorMessage;

  const AppConfigState({
    this.values = const {},
    this.businessInfo,
    this.currencies = const [],
    this.status = ViewState.initial,
    this.saveStatus = ViewState.initial,
    this.connectionStatus = ViewState.initial,
    this.connectionUrl,
    this.errorMessage,
  });

  /// Moneda base del sistema (generalmente Soles PEN)
  CurrencyEntity get baseCurrency => currencies.firstWhere(
    (c) => c.isBase,
    orElse:
        () => const CurrencyEntity(
          id: '',
          code: 'PEN',
          name: 'Soles',
          symbol: 'S/',
          exchangeRate: 1.0,
          isBase: true,
        ),
  );

  /// Lista de monedas activas disponibles para compras, ventas y cajas
  List<CurrencyEntity> get activeCurrencies {
    final list = currencies.where((c) => c.isActive).toList();
    if (list.isEmpty) {
      return [baseCurrency];
    }
    return list;
  }

  /// Busca una moneda por su código ('PEN', 'USD'...)
  CurrencyEntity? getCurrency(String code) {
    try {
      return currencies.firstWhere(
        (c) => c.code.toUpperCase() == code.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  AppConfigState copyWith({
    Map<String, double>? values,
    BusinessInfoEntity? businessInfo,
    List<CurrencyEntity>? currencies,
    ViewState? status,
    ViewState? saveStatus,
    ViewState? connectionStatus,
    String? connectionUrl,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AppConfigState(
      values: values ?? this.values,
      businessInfo: businessInfo ?? this.businessInfo,
      currencies: currencies ?? this.currencies,
      status: status ?? this.status,
      saveStatus: saveStatus ?? this.saveStatus,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionUrl: connectionUrl ?? this.connectionUrl,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    values,
    businessInfo,
    currencies,
    status,
    saveStatus,
    connectionStatus,
    connectionUrl,
    errorMessage,
  ];
}
