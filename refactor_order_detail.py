# -*- coding: utf-8 -*-
import os
import re

path = "lib/features/orders/presentation/screens/widgets/admin/orders/order_detail_sheet.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Imports
text = text.replace("import 'package:provider/provider.dart';", "import 'package:flutter_bloc/flutter_bloc.dart';")
text = text.replace("import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';", "import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';")
text = text.replace("import 'package:inventory_store_app/features/orders/data/models/order_model.dart';", "import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';")
text = text.replace("import 'package:inventory_store_app/features/orders/presentation/providers/order_detail_provider.dart';", "import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail_cubit.dart';\nimport 'package:inventory_store_app/features/orders/presentation/bloc/order_detail_state.dart';")

# Class definition
text = text.replace("final OrderModel order;", "final OrderEntity order;")

# _OrderDetailSheetState variables
old_vars = """  bool _isEditing = false;
  late OrderDetailProvider _provider;"""
new_vars = """  bool _isEditing = false;"""
text = text.replace(old_vars, new_vars)

# initState
old_init = """  @override
  void initState() {
    super.initState();
    _provider = OrderDetailProvider(widget.order);
    _pointsUsedCtrl.text = _provider.pointsUsed.toString();
    _manualNameCtrl.text = widget.order.displayCustomerName.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.fetchData(_manualNameCtrl.text).then((_) {
        if (mounted) {
          setState(() {
            _quantityControllers =
                _provider.items
                    .map(
                      (item) =>
                          TextEditingController(text: item.quantity.toString()),
                    )
                    .toList();
          });
        }
      });
    });
  }"""
new_init = """  @override
  void initState() {
    super.initState();
    context.read<OrderDetailCubit>().setInitialOrder(widget.order);
    _pointsUsedCtrl.text = context.read<OrderDetailCubit>().state.pointsUsed.toString();
    _manualNameCtrl.text = widget.order.customerName?.trim() ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderDetailCubit>().fetchData(_manualNameCtrl.text).then((_) {
        if (mounted) {
          final state = context.read<OrderDetailCubit>().state;
          setState(() {
            _quantityControllers =
                state.items
                    .map(
                      (item) =>
                          TextEditingController(text: item.quantity.toString()),
                    )
                    .toList();
          });
        }
      });
    });
  }"""
text = text.replace(old_init, new_init)

# dispose
old_dispose = """  @override
  void dispose() {
    _pointsUsedCtrl.dispose();
    _manualNameCtrl.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    _provider.dispose();
    super.dispose();
  }"""
new_dispose = """  @override
  void dispose() {
    _pointsUsedCtrl.dispose();
    _manualNameCtrl.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }"""
text = text.replace(old_dispose, new_dispose)

# _showBatchEditSheet
old_batch = """  Future<void> _showBatchEditSheet(OrderItemModel item) async {
    final warehouseId = _provider.order.warehouseId;
    if (warehouseId == null) return;

    List<BatchAssignmentModel> batches;
    try {
      batches = await _provider.fetchAvailableBatches(
        item.variantId ?? '',
        warehouseId,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Error cargando lotes: $e',
        type: SnackbarType.error,
      );
      return;
    }

    if (batches.isEmpty) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No hay lotes con stock para este producto.',
        type: SnackbarType.warning,
      );
      return;
    }

    final saved = _provider.batchOverrides[item.id];
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

    if (!mounted) return;
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

    if (result != null && mounted) {
      _provider.updateBatchOverrides(item.id, result);
    }
  }"""
new_batch = """  Future<void> _showBatchEditSheet(OrderItemEntity item) async {
    final state = context.read<OrderDetailCubit>().state;
    final warehouseId = state.order?.warehouseId;
    if (warehouseId == null) return;

    List<BatchAssignmentModel> batches;
    try {
      batches = await context.read<OrderDetailCubit>().fetchAvailableBatches(
        item.variantId ?? '',
        warehouseId,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Error cargando lotes: $e',
        type: SnackbarType.error,
      );
      return;
    }

    if (batches.isEmpty) {
      if (!mounted) return;
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

    if (!mounted) return;
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

    if (result != null && mounted) {
      context.read<OrderDetailCubit>().updateBatchOverrides(item.id, result);
    }
  }"""
text = text.replace(old_batch, new_batch)

# _showStockErrorDialog
old_stock = """  void _showStockErrorDialog(List<String> messages) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'Stock Insuficiente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'El stock varió y ya no hay disponibilidad para completar este pedido:\\n\\n${messages.join('\\n')}',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }"""
new_stock = "" # Removed, no longer needed

# _saveChanges
old_save = """  Future<void> _saveChanges(double pointsToSolesRatio) async {
    final isNowCancelled = _provider.currentStatus.toUpperCase() == 'CANCELLED';
    String? notesOverride;

    if (isNowCancelled) {
      notesOverride = await _showReasonDialog(
        'Cancelar Pedido',
        'Ingresa el motivo de la cancelación:',
      );
      if (notesOverride == null) return;
    }

    final result = await _provider.saveChanges(
      notesOverride: notesOverride,
      manualCustomerName: _manualNameCtrl.text,
      pointsToSolesRatio: pointsToSolesRatio,
    );

    if (!mounted) return;

    if (result.success) {
      AppSnackbar.show(
        context,
        message: 'Cambios guardados',
        type: SnackbarType.success,
      );
      setState(() {
        _isEditing = false;
      });
    } else if (result.stockError) {
      _showStockErrorDialog(result.stockMessages);
    } else {
      AppSnackbar.show(
        context,
        message: result.errorMessage ?? 'Error al guardar cambios',
        type: SnackbarType.error,
      );
    }
  }"""
new_save = """  Future<void> _saveChanges(double pointsToSolesRatio) async {
    final state = context.read<OrderDetailCubit>().state;
    final isNowCancelled = state.currentStatus.toUpperCase() == 'CANCELLED';
    String? notesOverride;

    if (isNowCancelled) {
      notesOverride = await _showReasonDialog(
        'Cancelar Pedido',
        'Ingresa el motivo de la cancelación:',
      );
      if (notesOverride == null) return;
    }

    final result = await context.read<OrderDetailCubit>().saveChanges(
      notesOverride: notesOverride,
      manualCustomerName: _manualNameCtrl.text,
      pointsToSolesRatio: pointsToSolesRatio,
    );

    if (!mounted) return;

    if (result) {
      AppSnackbar.show(
        context,
        message: 'Cambios guardados',
        type: SnackbarType.success,
      );
      setState(() {
        _isEditing = false;
      });
    } else {
      AppSnackbar.show(
        context,
        message: context.read<OrderDetailCubit>().state.errorMessage ?? 'Error al guardar cambios',
        type: SnackbarType.error,
      );
    }
  }"""
text = text.replace(old_save, new_save)
text = text.replace(old_stock, new_stock)

# _confirmReturn
old_return = """  Future<void> _confirmReturn() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'Devolución Parcial',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Se procesará la devolución de los ítems con cantidad cero y se reingresará el stock.\\n¿Continuar?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Devolver'),
              ),
            ],
          ),
    );

    if (proceed != true) return;
    if (!mounted) return;

    final result = await _provider.processReturn();
    if (!mounted) return;

    if (result.success) {
      AppSnackbar.show(
        context,
        message: 'Devolución procesada con éxito',
        type: SnackbarType.success,
      );
      setState(() {
        _isEditing = false;
      });
    } else {
      AppSnackbar.show(
        context,
        message: result.errorMessage ?? 'Error al procesar devolución',
        type: SnackbarType.error,
      );
    }
  }"""
new_return = """  Future<void> _confirmReturn() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'Devolución Parcial',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Se procesará la devolución de los ítems con cantidad cero y se reingresará el stock.\\n¿Continuar?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Devolver'),
              ),
            ],
          ),
    );

    if (proceed != true) return;
    if (!mounted) return;

    final result = await context.read<OrderDetailCubit>().processReturn();
    if (!mounted) return;

    if (result) {
      AppSnackbar.show(
        context,
        message: 'Devolución procesada con éxito',
        type: SnackbarType.success,
      );
      setState(() {
        _isEditing = false;
      });
    } else {
      AppSnackbar.show(
        context,
        message: context.read<OrderDetailCubit>().state.errorMessage ?? 'Error al procesar devolución',
        type: SnackbarType.error,
      );
    }
  }"""
text = text.replace(old_return, new_return)

# build method - wrap in BlocBuilder
old_build_start = """  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('loyalty_earning_rate', 1.0).toInt();

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<OrderDetailProvider>(
        builder: (context, provider, child) {
          final isCompleted =
              provider.order.status == 'COMPLETED' ||
              provider.order.status == 'CANCELLED';
          final subtotal = provider.items.fold(
            0.0,
            (sum, item) => sum + (item.price * item.quantity),
          );

          String getCustomerLabel() {
            return provider.selectedCustomerId != null
                ? provider.profiles.firstWhere(
                  (p) => p['id'] == provider.selectedCustomerId,
                  orElse: () => {'full_name': 'Cliente mostrador'},
                )['full_name']
                : provider.order.displayCustomerName.isNotEmpty
                ? provider.order.displayCustomerName
                : 'Cliente mostrador';
          }

          final child = Container("""
new_build_start = """  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final pointsToSolesRatio = config.state.values['points_to_soles_ratio'] ?? 0.01;
    final earningRate = (config.state.values['loyalty_earning_rate'] ?? 1.0).toInt();

    return BlocBuilder<OrderDetailCubit, OrderDetailState>(
        builder: (context, state) {
          final cubit = context.read<OrderDetailCubit>();
          final isCompleted =
              state.order?.status == 'COMPLETED' ||
              state.order?.status == 'CANCELLED';
          final subtotal = state.items.fold(
            0.0,
            (sum, item) => sum + ((item.price ?? 0) * (item.quantity ?? 1)),
          );

          String getCustomerLabel() {
            return (state.selectedCustomerId != null ? state.profiles.firstWhere((p) => p['id'] == state.selectedCustomerId, orElse: () => {'full_name': 'Cliente mostrador'})['full_name'] as String? ?? 'Cliente mostrador' : (state.order?.customerName?.isNotEmpty == true ? state.order!.customerName! : 'Cliente mostrador'));
          }

          final child = Container("""
text = text.replace(old_build_start, new_build_start)

# Replace all occurrences of `provider.` with `state.` or `cubit.` in the build body
body_start = text.find("final child = Container(")
body_end = text.find("if (widget.isEmbedded) {")

if body_start != -1 and body_end != -1:
    body = text[body_start:body_end]
    
    # We replace provider.updateItemQuantity with cubit.updateItemQuantity
    body = body.replace("provider.updateItemQuantity", "cubit.updateItemQuantity")
    body = body.replace("provider.updatePointsUsed", "cubit.updatePointsUsed")
    body = body.replace("provider.updateStatus", "cubit.updateStatus")
    body = body.replace("provider.togglePaymentStatus", "cubit.togglePaymentStatus")
    body = body.replace("provider.updatePaymentMethod", "cubit.updatePaymentMethod")
    body = body.replace("provider.fetchData(", "cubit.fetchData(")
    
    # Replace provider.order properties with safe access
    body = body.replace("provider.order.status", "state.order?.status ?? 'PENDING'")
    body = body.replace("provider.order.paymentStatus", "state.order?.paymentStatus ?? 'PENDING'")
    body = body.replace("provider.order.paymentMethod", "state.order?.paymentMethod ?? ''")
    body = body.replace("provider.order.discountAmount", "state.order?.discountAmount ?? 0.0")
    body = body.replace("provider.order.amountPaid", "state.order?.amountPaid ?? 0.0")
    body = body.replace("provider.order.totalAmount", "state.order?.totalAmount ?? 0.0")
    body = body.replace("provider.order.displayCustomerName", "state.order?.customerName ?? ''")
    body = body.replace("provider.order.id", "state.order?.id ?? ''")
    
    body = body.replace("provider.order", "(state.order ?? const OrderEntity(id: '', customerName: '', customerPhone: '', totalAmount: 0, amountPaid: 0, totalProfit: 0, paymentStatus: '', paymentMethod: '', status: '', items: [], createdAt: '', warehouseId: '', warehouseName: '', userId: ''))")
    
    # The rest of provider is state
    body = body.replace("provider.", "state.")
    
    text = text[:body_start] + body + text[body_end:]

# Replace the PopScope at the end
old_pop = """          if (widget.isEmbedded) {
            return child;
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, dynamic result) {
              if (didPop) return;
              _handlePop(_provider.wasModified);
            },
            child: child,
          );
        },
      ),
    );
  }
}"""
new_pop = """          if (widget.isEmbedded) {
            return child;
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, dynamic result) {
              if (didPop) return;
              final state = context.read<OrderDetailCubit>().state;
              _handlePop(state.wasModified);
            },
            child: child,
          );
        },
    );
  }
}"""
text = text.replace(old_pop, new_pop)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("success")
