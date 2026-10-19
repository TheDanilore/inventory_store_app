import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_quantity_stepper.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/inventory_exit_items_table.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

class InventoryExitFormScreen extends StatefulWidget {
  const InventoryExitFormScreen({super.key});

  @override
  State<InventoryExitFormScreen> createState() =>
      _InventoryExitFormScreenState();
}

class _InventoryExitFormScreenState extends State<InventoryExitFormScreen> {
  final _notesCtrl = TextEditingController();

  static const Map<String, IconData> _reasons = {
    'AJUSTE': Icons.tune_rounded,
    'MERMA': Icons.trending_down_rounded,
    'DAÑO': Icons.broken_image_outlined,
    'VENCIMIENTO': Icons.event_busy_rounded,
    'ROBO/PÉRDIDA': Icons.report_problem_outlined,
    'CONSUMO INTERNO': Icons.home_work_outlined,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InventoryExitFormCubit>().loadInitialData();
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _showAddProductSheet() async {
    final cubit = context.read<InventoryExitFormCubit>();
    final warehouseId = cubit.state.selectedWarehouseId;
    if (warehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione el almacén de origen primero',
        type: SnackbarType.warning,
      );
      return;
    }

    // Lo que ya está en la lista, por lote: el panel descuenta esa cantidad
    // del stock para no permitir retirar más de lo que hay.
    final reserved = <String, double>{};
    for (final i in cubit.state.items) {
      final key = exitBatchKey(i.selectedBatch);
      if (key.isEmpty) continue;
      reserved[key] = (reserved[key] ?? 0.0) + i.quantity;
    }

    final newItem = await AddExitProductSheet.show(
      context,
      warehouseId: warehouseId,
      reservedByBatchId: reserved,
      // Permite cargar varios productos sin cerrar y reabrir el panel.
      onAddAndContinue: (item) => cubit.addItem(item),
    );

    if (newItem != null && mounted) {
      cubit.addItem(newItem);
    }
  }

  Future<void> _scanAndAddProduct() async {
    final cubit = context.read<InventoryExitFormCubit>();
    final warehouseId = cubit.state.selectedWarehouseId;
    if (warehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione el almacén de origen primero',
        type: SnackbarType.warning,
      );
      return;
    }

    final res = await PosCameraScannerDialog.show(
      context,
      warehouseId: warehouseId,
    );
    if (res == null || !mounted) return;

    final reserved = <String, double>{};
    for (final i in cubit.state.items) {
      final key = exitBatchKey(i.selectedBatch);
      if (key.isEmpty) continue;
      reserved[key] = (reserved[key] ?? 0.0) + i.quantity;
    }

    final productModel = ProductModel.fromEntity(res.product);
    final variantModel =
        res.variant != null ? ProductVariantModel.fromEntity(res.variant!) : null;

    final newItem = await AddExitProductSheet.show(
      context,
      warehouseId: warehouseId,
      reservedByBatchId: reserved,
      initialProduct: productModel,
      initialVariant: variantModel,
      onAddAndContinue: (item) => cubit.addItem(item),
    );

    if (newItem != null && mounted) {
      cubit.addItem(newItem);
    }
  }

  /// Quita la línea al instante y ofrece "Deshacer" (sin diálogo de
  /// confirmación que interrumpa cada vez).
  void _removeItemWithUndo(InventoryExitFormCubit cubit, int index) {
    final items = cubit.state.items;
    if (index < 0 || index >= items.length) return;
    final removed = items[index];

    HapticFeedback.lightImpact();
    cubit.removeItem(index);

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Quitaste "${removed.product.name}"'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        // Deja libre la barra inferior con el botón de confirmar.
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            if (mounted) cubit.addItem(removed);
          },
        ),
      ),
    );
  }

  Future<void> _handleClearDraft() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Descartar borrador'),
            content: const Text(
              '¿Estás seguro de que quieres limpiar los productos de la salida actual?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Descartar',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      context.read<InventoryExitFormCubit>().clearDraft();
      _notesCtrl.clear();
      AppSnackbar.show(
        context,
        message: 'Borrador descartado',
        type: SnackbarType.info,
      );
    }
  }

  void _leave() {
    _exitForm();
  }

  // Sale del formulario hacia donde se vino (pop real o historial de AppBackHandler).
  void _exitForm([Object? result]) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else {
      AppBackHandler.handleBack(context); // sin onCustomBack → usa el historial
    }
  }

  Future<void> _handleBackButton() async {
    final cubit = context.read<InventoryExitFormCubit>();
    if (cubit.state.isSaving) return;

    if (cubit.state.items.isEmpty) {
      cubit.clearDraft();
      _leave();
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cambios sin guardar'),
            content: const Text(
              'Tienes una salida en curso. ¿Qué deseas hacer al salir?',
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    child: const Text('Seguir editando'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'discard'),
                    child: const Text(
                      'Descartar',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, 'draft'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Guardar borrador'),
                  ),
                ],
              ),
            ],
          ),
    );

    if (!mounted) return;

    if (action == 'discard') {
      cubit.clearDraft();
      _leave();
    } else if (action == 'draft') {
      _leave();
    }
  }

  Future<void> _saveExit() async {
    final cubit = context.read<InventoryExitFormCubit>();

    if (cubit.state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén de origen',
        type: SnackbarType.warning,
      );
      return;
    }
    if (cubit.state.items.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Agregue al menos un producto a retirar',
        type: SnackbarType.warning,
      );
      return;
    }

    // Validación estricta de lotes requeridos antes de confirmar.
    for (final item in cubit.state.items) {
      final batchNumber = item.selectedBatch?['batch_number'] as String?;
      final batchId = item.selectedBatch?['id'] as String?;
      if (item.product.usesBatches &&
          (batchId == null ||
              batchNumber == null ||
              batchNumber == 'DEFAULT' ||
              batchNumber.trim().isEmpty)) {
        AppSnackbar.show(
          context,
          message:
              'El producto "${item.product.name}" requiere un lote válido seleccionado.',
          type: SnackbarType.warning,
        );
        return;
      }
    }

    final items = cubit.state.items;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _ConfirmExitDialog(
            reason: cubit.state.selectedReason,
            lines: items.length,
            units: items.fold<double>(0.0, (s, i) => s + i.quantity),
            totalLoss: items.fold<double>(0.0, (s, i) => s + i.totalCost),
          ),
    );

    if (confirmed != true || !mounted) return;

    await cubit.saveExit(_notesCtrl.text.trim());
    if (!mounted) return;

    if (cubit.state.isSuccess) {
      AppSnackbar.show(
        context,
        message: 'Salida de inventario registrada con éxito.',
        type: SnackbarType.success,
      );
      context.go('/inventory-exits');
    } else {
      AppSnackbar.show(
        context,
        message: cubit.state.errorMessage,
        type: SnackbarType.error,
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackButton();
      },
      child: BlocBuilder<InventoryExitFormCubit, InventoryExitFormState>(
        buildWhen:
            (prev, curr) =>
                prev.isLoading != curr.isLoading ||
                prev.isSaving != curr.isSaving ||
                prev.selectedWarehouseId != curr.selectedWarehouseId ||
                prev.selectedReason != curr.selectedReason ||
                prev.items != curr.items ||
                prev.warehouses != curr.warehouses,
        builder: (context, state) {
          if (state.isLoading) {
            return AdminLayout(
              title: 'Registrar Salida',
              showBackButton: true,
              onBack: _handleBackButton,
              showProfileButton: false,
              showDrawerButton: false,
              body: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          return AdminLayout(
            title: 'Registrar Salida',
            showBackButton: true,
            onBack: _handleBackButton,
            showProfileButton: false,
            showDrawerButton: false,
            body: Stack(
              children: [
                AbsorbPointer(
                  absorbing: state.isSaving,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Izquierda: Datos y notas (40%)
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildMainDataSection(context, state),
                                      const SizedBox(height: 16),
                                      _buildNotesSection(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Derecha: Productos y barra de confirmación (60%)
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(24.0),
                                      child: _buildProductsSection(
                                        context,
                                        state,
                                        isDesktop: true,
                                      ),
                                    ),
                                  ),
                                  _buildStickySaveButton(),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      // Móvil
                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMainDataSection(context, state),
                                  const SizedBox(height: 16),
                                  _buildProductsSection(context, state),
                                  const SizedBox(height: 16),
                                  _buildNotesSection(),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                          _buildStickySaveButton(),
                        ],
                      );
                    },
                  ),
                ),
                if (state.isSaving)
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.surface.withValues(alpha: 0.7),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SECCIONES
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildMainDataSection(
    BuildContext context,
    InventoryExitFormState state,
  ) {
    final cubit = context.read<InventoryExitFormCubit>();
    final validWarehouseId =
        state.warehouses.any((w) => w.id == state.selectedWarehouseId)
            ? state.selectedWarehouseId
            : null;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.storefront_rounded,
            title: 'Datos principales',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('wh_${validWarehouseId}_${state.warehouses.length}'),
            initialValue: validWarehouseId,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Almacén de origen',
              icon: Icons.warehouse_rounded,
            ),
            hint: const Text(
              'Seleccione almacén de origen',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            items:
                state.warehouses
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          w.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: cubit.selectWarehouse,
          ),
          const SizedBox(height: 20),
          const Text(
            'Motivo de salida',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _reasons.entries.map((e) {
                  final selected = state.selectedReason == e.key;
                  return ChoiceChip(
                    avatar: Icon(
                      e.value,
                      size: 18,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                    label: Text(e.key),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      cubit.selectReason(e.key);
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.background,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.receipt_long_rounded,
            title: 'Notas y justificación',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            maxLength: 300,
            decoration: _dropdownDecoration(
              'Notas / justificación (opcional)',
            ).copyWith(
              hintText: 'Ej: Botellas rotas durante el traslado',
              counterText: '',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(
    BuildContext context,
    InventoryExitFormState state, {
    bool isDesktop = false,
  }) {
    final cubit = context.read<InventoryExitFormCubit>();

    if (isDesktop) {
      return InventoryExitItemsTable(
        items: state.items,
        onRemoveItem: (index) => _removeItemWithUndo(cubit, index),
        onUpdateQuantity: (index, qty) => cubit.updateQuantity(index, qty),
        onAddNewRow: _showAddProductSheet,
        onScanBarcode: _scanAndAddProduct,
      );
    }

    final items = state.items;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle(
                  icon: Icons.inventory_2_rounded,
                  title:
                      items.isEmpty
                          ? 'Productos a retirar'
                          : 'Productos a retirar (${items.length})',
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Escanear código',
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  onPressed: _scanAndAddProduct,
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: _showAddProductSheet,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Agregar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'clear') _handleClearDraft();
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_sweep_rounded,
                                color: AppColors.danger,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Descartar todo',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child:
                items.isEmpty
                    ? _buildEmptyProducts()
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        return InventoryExitItemCard(
                          key: ValueKey(
                            'exit_item_${item.product.id}_${item.variant.id}_${exitRowBatchKey(item)}_$index',
                          ),
                          item: item,
                          onUpdateQuantity:
                              (qty) => cubit.updateQuantity(index, qty),
                          onRemove: () => _removeItemWithUndo(cubit, index),
                        );
                      }),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProducts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.outbox_rounded,
              size: 26,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aún no hay productos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Agrega los productos que vas a dar de baja de tu inventario.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _scanAndAddProduct,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Escanear código'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _showAddProductSheet,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar producto'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BARRA INFERIOR FIJA
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildStickySaveButton() {
    return BlocBuilder<InventoryExitFormCubit, InventoryExitFormState>(
      buildWhen:
          (prev, curr) =>
              prev.items != curr.items || prev.isSaving != curr.isSaving,
      builder: (context, s) {
        final items = s.items;
        final hasItems = items.isNotEmpty;
        final isSaving = s.isSaving;
        final totalLoss = items.fold<double>(
          0.0,
          (sum, i) => sum + i.totalCost,
        );
        final totalUnits = items.fold<double>(
          0.0,
          (sum, i) => sum + i.quantity,
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Total siempre a la vista, sin bajar hasta el final.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Pérdida estimada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'S/ ${totalLoss.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color:
                                hasItems
                                    ? AppColors.danger
                                    : AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (hasItems)
                        Text(
                          '${items.length} ${items.length == 1 ? 'línea' : 'líneas'} · ${formatExitQty(totalUnits)} ${totalUnits == 1 ? 'unidad' : 'unidades'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: (!hasItems || isSaving) ? null : _saveExit,
                  icon:
                      isSaving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textMuted,
                            ),
                          )
                          : const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 20,
                          ),
                  label: Text(isSaving ? 'Guardando...' : 'Confirmar salida'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textMuted,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // UTILS
  // ════════════════════════════════════════════════════════════════════════════

  InputDecoration _dropdownDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon:
          icon != null ? Icon(icon, color: AppColors.primary, size: 20) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGO DE CONFIRMACIÓN
// ═════════════════════════════════════════════════════════════════════════════

/// Confirmación estricta (hay que escribir CONFIRMAR). Es un StatefulWidget
/// con su propio controlador: así no se destruye antes de que el diálogo
/// termine de cerrarse (eso provocaba "TextEditingController used after
/// being disposed").
class _ConfirmExitDialog extends StatefulWidget {
  final String? reason;
  final int lines;
  final double units;
  final double totalLoss;

  const _ConfirmExitDialog({
    required this.reason,
    required this.lines,
    required this.units,
    required this.totalLoss,
  });

  @override
  State<_ConfirmExitDialog> createState() => _ConfirmExitDialogState();
}

class _ConfirmExitDialogState extends State<_ConfirmExitDialog> {
  final _ctrl = TextEditingController();
  bool _valid = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Confirmar salida',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (widget.reason != null)
                      _SummaryRow(label: 'Motivo', value: widget.reason!),
                    _SummaryRow(label: 'Líneas', value: '${widget.lines}'),
                    _SummaryRow(
                      label: 'Unidades',
                      value: formatExitQty(widget.units),
                    ),
                    const Divider(height: 20),
                    _SummaryRow(
                      label: 'Pérdida valorizada',
                      value: 'S/ ${widget.totalLoss.toStringAsFixed(2)}',
                      emphasize: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Esto descontará el stock del inventario físico.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text(
                'Para autorizar, escribe CONFIRMAR:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged:
                    (v) => setState(
                      () => _valid = v.trim().toUpperCase() == 'CONFIRMAR',
                    ),
                decoration: InputDecoration(
                  hintText: 'CONFIRMAR',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: _valid ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Autorizar salida',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 18 : 13,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              color: emphasize ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES (idénticos a los de Entradas)
// ═════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
