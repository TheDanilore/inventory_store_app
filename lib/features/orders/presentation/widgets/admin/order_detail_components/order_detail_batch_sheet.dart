import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/batch_edit_sheet.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail_cubit.dart';

class OrderDetailBatchSheet {
  static Future<void> show(BuildContext context, OrderItemEntity item) async {
    final cubit = context.read<OrderDetailCubit>();
    final state = cubit.state;
    final warehouseId = state.order?.warehouseId;

    if (warehouseId == null) return;

    List<BatchAssignmentModel> batches;
    try {
      batches = await cubit.fetchAvailableBatches(
        item.variantId ?? '',
        warehouseId,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'Error cargando lotes: $e',
        type: SnackbarType.error,
      );
      return;
    }

    if (batches.isEmpty) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'No hay lotes con stock para este producto.',
        type: SnackbarType.warning,
      );
      return;
    }

    final saved = state.batchOverrides[item.id];
    if (saved != null) {
      for (final s in saved) {
        final idx = batches.indexWhere((b) => b.batchId == s.batchId);
        if (idx >= 0) batches[idx].assigned = s.assigned;
      }
    } else {
      int remaining = item.quantity;
      for (final b in batches) {
        if (remaining <= 0) break;
        b.assigned = (remaining > b.available) ? b.available : remaining;
        remaining -= b.assigned;
      }
    }

    if (!context.mounted) return;
    final result = await showModalBottomSheet<List<BatchAssignmentModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BatchEditSheet(
            productName: item.productName ?? 'Producto',
            variantLabel: item.variantLabel,
            totalRequired: item.quantity,
            batches: batches,
          ),
    );

    if (result != null && context.mounted) {
      cubit.updateBatchOverrides(item.id, result);
    }
  }
}
