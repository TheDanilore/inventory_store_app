import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';

enum CheckoutStatus {
  idle,
  verifyingStock,
  sending,
  stockError,
  failure,
  success,
}

/// Payload tipado para el estado de éxit
class CheckoutSuccessPayload extends Equatable {
  final String orderId;
  final double totalAPagar;
  final int puntosUsados;
  final List<CartItemEntity> itemsBought;

  const CheckoutSuccessPayload({
    required this.orderId,
    required this.totalAPagar,
    required this.puntosUsados,
    required this.itemsBought,
  });

  @override
  List<Object?> get props => [orderId, totalAPagar, puntosUsados, itemsBought];
}

class CheckoutState extends Equatable {
  final CheckoutStatus status;
  final bool isLoadingAddress;
  final bool usePoints;
  final Map<String, dynamic>? defaultAddress;

  /// Mensajes de stock insuficiente para mostrar en el diálogo.
  final List<String> stockMessages;

  /// Mensaje de error genérico.
  final String? errorMessage;

  /// Payload del pedido exitoso (para disparar WhatsApp y snackbar).
  final CheckoutSuccessPayload? successPayload;

  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.isLoadingAddress = false,
    this.usePoints = false,
    this.defaultAddress,
    this.stockMessages = const [],
    this.errorMessage,
    this.successPayload,
  });

  // Getters de conveniencia para la UI
  bool get isSending => status == CheckoutStatus.sending;
  bool get isVerifyingStock => status == CheckoutStatus.verifyingStock;
  bool get hasStockError => status == CheckoutStatus.stockError;
  bool get isSuccess => status == CheckoutStatus.success;
  bool get hasError => status == CheckoutStatus.failure;

  CheckoutState copyWith({
    CheckoutStatus? status,
    bool? isLoadingAddress,
    bool? usePoints,
    Map<String, dynamic>? defaultAddress,
    bool clearAddress = false,
    List<String>? stockMessages,
    String? errorMessage,
    CheckoutSuccessPayload? successPayload,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      isLoadingAddress: isLoadingAddress ?? this.isLoadingAddress,
      usePoints: usePoints ?? this.usePoints,
      defaultAddress:
          clearAddress ? null : (defaultAddress ?? this.defaultAddress),
      stockMessages: stockMessages ?? this.stockMessages,
      errorMessage: errorMessage,
      successPayload: successPayload,
    );
  }

  @override
  List<Object?> get props => [
    status,
    isLoadingAddress,
    usePoints,
    defaultAddress,
    stockMessages,
    errorMessage,
    successPayload,
  ];
}
