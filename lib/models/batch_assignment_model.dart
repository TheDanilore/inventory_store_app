class BatchAssignmentModel {
  final String batchId;
  final String batchNumber;
  final DateTime? expiryDate;
  final int available; // stock real disponible
  int assigned; // cantidad a descontar de este lote (editable)

  BatchAssignmentModel({
    required this.batchId,
    required this.batchNumber,
    this.expiryDate,
    required this.available,
    required this.assigned,
  });

  BatchAssignmentModel copyWith({int? assigned}) => BatchAssignmentModel(
    batchId: batchId,
    batchNumber: batchNumber,
    expiryDate: expiryDate,
    available: available,
    assigned: assigned ?? this.assigned,
  );

  String get expiryLabel {
    if (expiryDate == null) return 'Sin vto.';
    final d = expiryDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
  }
}
