import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';

abstract class CustomerCreditMovementsState extends Equatable {
  const CustomerCreditMovementsState();

  @override
  List<Object?> get props => [];
}

class CustomerCreditMovementsInitial extends CustomerCreditMovementsState {}

class CustomerCreditMovementsLoading extends CustomerCreditMovementsState {}

/// Estado base cuando los movimientos están cargados.
/// Expone getters computados para evitar lógica de negocio en la UI.
class CustomerCreditMovementsLoaded extends CustomerCreditMovementsState {
  final List<CreditMovementEntity> movements;
  final bool hasReachedMax;

  const CustomerCreditMovementsLoaded({
    required this.movements,
    this.hasReachedMax = false,
  });

  /// Suma de todos los cargos (tipo 'CHARGE'). Calculado automáticamente.
  double get totalCharged => movements
      .where((m) => m.movementType == 'CHARGE')
      .fold(0.0, (sum, m) => sum + m.amount);

  /// Suma de todos los pagos (tipo 'PAYMENT'). Calculado automáticamente.
  double get totalPaid => movements
      .where((m) => m.movementType == 'PAYMENT')
      .fold(0.0, (sum, m) => sum + m.amount);

  CustomerCreditMovementsLoaded copyWith({
    List<CreditMovementEntity>? movements,
    bool? hasReachedMax,
  }) {
    return CustomerCreditMovementsLoaded(
      movements: movements ?? this.movements,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [movements, hasReachedMax];
}

/// El Cubit está cargando el detalle de una orden específica.
/// Extiende Loaded para que el ListView no se destruya durante la espera.
class CustomerCreditMovementsOrderLoading
    extends CustomerCreditMovementsLoaded {
  const CustomerCreditMovementsOrderLoading({
    required super.movements,
    required super.hasReachedMax,
  });

  @override
  List<Object?> get props => [...super.props, 'order_loading'];
}

/// El detalle de la orden fue cargado y está listo para mostrarse en un sheet.
/// La UI debe consumir este estado (mostrar el sheet) y luego llamar a
/// [CustomerCreditMovementsCubit.clearOrderPreview] para regresar a Loaded.
class CustomerCreditMovementsOrderReady extends CustomerCreditMovementsLoaded {
  final OrderEntity order;

  const CustomerCreditMovementsOrderReady({
    required super.movements,
    required super.hasReachedMax,
    required this.order,
  });

  @override
  List<Object?> get props => [...super.props, order];
}

/// Error al cargar el detalle de la orden. Preserva los movimientos para no
/// destruir la lista visible.
class CustomerCreditMovementsOrderError extends CustomerCreditMovementsLoaded {
  final String orderErrorMessage;

  const CustomerCreditMovementsOrderError({
    required super.movements,
    required super.hasReachedMax,
    required this.orderErrorMessage,
  });

  @override
  List<Object?> get props => [...super.props, orderErrorMessage];
}

class CustomerCreditMovementsError extends CustomerCreditMovementsState {
  final String message;

  const CustomerCreditMovementsError(this.message);

  @override
  List<Object?> get props => [message];
}
