import 'package:equatable/equatable.dart';

enum BulkImportStatus { initial, parsing, validationDone, uploading, success, error }

class BulkImportState extends Equatable {
  final BulkImportStatus status;
  final List<Map<String, dynamic>> parsedRows;
  final List<String> errors;
  final String? errorMessage;
  final String? selectedWarehouseId;

  const BulkImportState({
    this.status = BulkImportStatus.initial,
    this.parsedRows = const [],
    this.errors = const [],
    this.errorMessage,
    this.selectedWarehouseId,
  });

  BulkImportState copyWith({
    BulkImportStatus? status,
    List<Map<String, dynamic>>? parsedRows,
    List<String>? errors,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? selectedWarehouseId,
  }) {
    return BulkImportState(
      status: status ?? this.status,
      parsedRows: parsedRows ?? this.parsedRows,
      errors: errors ?? this.errors,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      selectedWarehouseId: selectedWarehouseId ?? this.selectedWarehouseId,
    );
  }

  @override
  List<Object?> get props => [
        status,
        parsedRows,
        errors,
        errorMessage,
        selectedWarehouseId,
      ];
}
