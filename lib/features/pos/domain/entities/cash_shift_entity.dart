/// Entidad de un turno de caja (Cash Shift).
///
/// Representa el ciclo apertura → cierre de una cuenta de tipo CAJA.
class CashShiftEntity {
  final String id;
  final CashShiftStatus status;
  final double openingAmount;
  final double? expectedAmount;
  final double? actualAmount;
  final double? differenceAmount;
  final String? notes;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? accountId;
  final String? accountName;
  final String? accountType;
  final String? openedByName;
  final String? closedByName;

  const CashShiftEntity({
    required this.id,
    required this.status,
    required this.openingAmount,
    required this.openedAt,
    this.expectedAmount,
    this.actualAmount,
    this.differenceAmount,
    this.notes,
    this.closedAt,
    this.accountId,
    this.accountName,
    this.accountType,
    this.openedByName,
    this.closedByName,
  });

  // ── Lógica de negocio ─────────────────────────────────────────────────────

  bool get isOpen => status == CashShiftStatus.open;
  bool get isClosed => status == CashShiftStatus.closed;

  /// Diferencia entre el monto esperado y el real al cierre.
  double? get cashDifference =>
      (expectedAmount != null && actualAmount != null)
          ? actualAmount! - expectedAmount!
          : null;

  /// Indica si hubo un faltante de caja al cierre.
  bool get hasCashShortage => cashDifference != null && cashDifference! < 0;

  Duration get shiftDuration =>
      (closedAt ?? DateTime.now()).difference(openedAt);

  @override
  String toString() =>
      'CashShiftEntity(id: $id, status: ${status.name}, account: $accountName)';
}

enum CashShiftStatus {
  open,
  closed;

  static CashShiftStatus fromString(String value) {
    return switch (value.toUpperCase()) {
      'OPEN' => CashShiftStatus.open,
      'CLOSED' => CashShiftStatus.closed,
      _ => CashShiftStatus.closed,
    };
  }
}
