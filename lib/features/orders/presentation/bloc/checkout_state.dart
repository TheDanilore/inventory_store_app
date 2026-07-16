import 'package:equatable/equatable.dart';

class CheckoutState extends Equatable {
  final bool isSending;
  final bool isVerifyingStock;
  final bool isLoadingAddress;
  final bool usePoints;
  final Map<String, dynamic>? defaultAddress;
  final String? errorMessage;
  final Map<String, dynamic>? successData;

  const CheckoutState({
    this.isSending = false,
    this.isVerifyingStock = false,
    this.isLoadingAddress = false,
    this.usePoints = false,
    this.defaultAddress,
    this.errorMessage,
    this.successData,
  });

  CheckoutState copyWith({
    bool? isSending,
    bool? isVerifyingStock,
    bool? isLoadingAddress,
    bool? usePoints,
    Map<String, dynamic>? defaultAddress,
    String? errorMessage,
    Map<String, dynamic>? successData,
  }) {
    return CheckoutState(
      isSending: isSending ?? this.isSending,
      isVerifyingStock: isVerifyingStock ?? this.isVerifyingStock,
      isLoadingAddress: isLoadingAddress ?? this.isLoadingAddress,
      usePoints: usePoints ?? this.usePoints,
      defaultAddress: defaultAddress ?? this.defaultAddress,
      errorMessage: errorMessage, // Notice we don't persist error message unless explicitly passed
      successData: successData,
    );
  }

  @override
  List<Object?> get props => [
        isSending,
        isVerifyingStock,
        isLoadingAddress,
        usePoints,
        defaultAddress,
        errorMessage,
        successData,
      ];
}
