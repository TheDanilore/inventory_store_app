import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';

class OrderDetailState extends Equatable {
  final bool isLoading;
  final bool hasError;
  final bool isSaving;
  final bool isReturning;
  final bool wasModified;
  final String? errorMessage;
  
  final OrderEntity? order;
  final List<OrderItemEntity> items;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>> accounts;
  
  final Map<String, List<Map<String, dynamic>>> batchesByVariant;
  final Map<String, bool> usesBatchesMap;
  final Map<String, List<BatchAssignmentModel>> batchOverrides;
  
  final String? selectedCustomerId;
  final String currentStatus;
  final int pointsUsed;
  final int pointsEarned;
  final String paymentMethod;
  final Map<String, dynamic>? creditInfo;
  final String? updaterName;

  const OrderDetailState({
    this.isLoading = true,
    this.hasError = false,
    this.isSaving = false,
    this.isReturning = false,
    this.wasModified = false,
    this.errorMessage,
    
    this.order,
    this.items = const [],
    this.profiles = const [],
    this.accounts = const [],
    
    this.batchesByVariant = const {},
    this.usesBatchesMap = const {},
    this.batchOverrides = const {},
    
    this.selectedCustomerId,
    this.currentStatus = 'PENDING',
    this.pointsUsed = 0,
    this.pointsEarned = 0,
    this.paymentMethod = 'EFECTIVO',
    this.creditInfo,
    this.updaterName,
  });

  OrderDetailState copyWith({
    bool? isLoading,
    bool? hasError,
    bool? isSaving,
    bool? isReturning,
    bool? wasModified,
    String? errorMessage,
    OrderEntity? order,
    List<OrderItemEntity>? items,
    List<Map<String, dynamic>>? profiles,
    List<Map<String, dynamic>>? accounts,
    Map<String, List<Map<String, dynamic>>>? batchesByVariant,
    Map<String, bool>? usesBatchesMap,
    Map<String, List<BatchAssignmentModel>>? batchOverrides,
    String? selectedCustomerId,
    String? currentStatus,
    int? pointsUsed,
    int? pointsEarned,
    String? paymentMethod,
    Map<String, dynamic>? creditInfo,
    String? updaterName,
  }) {
    return OrderDetailState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      isSaving: isSaving ?? this.isSaving,
      isReturning: isReturning ?? this.isReturning,
      wasModified: wasModified ?? this.wasModified,
      errorMessage: errorMessage ?? this.errorMessage,
      order: order ?? this.order,
      items: items ?? this.items,
      profiles: profiles ?? this.profiles,
      accounts: accounts ?? this.accounts,
      batchesByVariant: batchesByVariant ?? this.batchesByVariant,
      usesBatchesMap: usesBatchesMap ?? this.usesBatchesMap,
      batchOverrides: batchOverrides ?? this.batchOverrides,
      selectedCustomerId: selectedCustomerId ?? this.selectedCustomerId,
      currentStatus: currentStatus ?? this.currentStatus,
      pointsUsed: pointsUsed ?? this.pointsUsed,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      creditInfo: creditInfo ?? this.creditInfo,
      updaterName: updaterName ?? this.updaterName,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        hasError,
        isSaving,
        isReturning,
        wasModified,
        errorMessage,
        order,
        items,
        profiles,
        accounts,
        batchesByVariant,
        usesBatchesMap,
        batchOverrides,
        selectedCustomerId,
        currentStatus,
        pointsUsed,
        pointsEarned,
        paymentMethod,
        creditInfo,
        updaterName,
      ];
}
