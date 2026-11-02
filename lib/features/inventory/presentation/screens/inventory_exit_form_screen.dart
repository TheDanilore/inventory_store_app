import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';
import 'package:inventory_store_app/core/utils/hardware_barcode_gun_detector.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/confirm_exit_dialog.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_form_header_section.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_form_products_section.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_form_summary_bar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

class InventoryExitFormScreen extends StatefulWidget {
  final String? prefillWarehouseId;
  final String? prefillReason;
  final String? prefillNotes;
  final String? prefillVariantId;
  final String? prefillBatchId;

  const InventoryExitFormScreen({
    super.key,
    this.prefillWarehouseId,
    this.prefillReason,
    this.prefillNotes,
    this.prefillVariantId,
    this.prefillBatchId,
  });

  @override
  State<InventoryExitFormScreen> createState() =>
      _InventoryExitFormScreenState();
}

class _InventoryExitFormScreenState extends State<InventoryExitFormScreen> {
  final _notesCtrl = TextEditingController();
  final _gunDetector = HardwareBarcodeGunDetector();

  @override
  void initState() {
    super.initState();
    if (widget.prefillNotes != null && widget.prefillNotes!.isNotEmpty) {
      _notesCtrl.text = widget.prefillNotes!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cubit = context.read<InventoryExitFormCubit>();
      await cubit.loadInitialData();
      if (!mounted) return;
      if (widget.prefillWarehouseId != null &&
          widget.prefillWarehouseId!.isNotEmpty) {
        cubit.selectWarehouse(widget.prefillWarehouseId);
      }
      if (widget.prefillReason != null && widget.prefillReason!.isNotEmpty) {
        cubit.selectReason(widget.prefillReason!);
      }
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ACCIONES Y MODALES
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

    await PosCameraScannerDialog.show(
      context,
      warehouseId: warehouseId,
      title: 'Escanear Salidas de Almacén',
      continuousMode: true,
      onContinuousScan: (res) async {
        final product = res.product;
        final variant = res.variant;

        final productModel = ProductModel.fromEntity(product);
        final variantModel =
            variant != null
                ? ProductVariantModel.fromEntity(variant)
                : (product.defaultVariant != null
                    ? ProductVariantModel.fromEntity(product.defaultVariant!)
                    : null);

        if (variantModel != null) {
          final exitItem = ExitItemUI(
            product: productModel,
            variant: variantModel,
            selectedBatch: null,
            quantity: 1.0,
            unitCost: variantModel.unitCost ?? 0.0,
          );
          cubit.addItem(exitItem);
        }
      },
    );
  }

  Future<void> _handleGunBarcode(String rawBarcode) async {
    final cubit = context.read<InventoryExitFormCubit>();
    final warehouseId = cubit.state.selectedWarehouseId;
    if (warehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione el almacén de origen primero para escanear',
        type: SnackbarType.warning,
      );
      return;
    }

    final res = await PosBarcodeScannerService.resolveCode(
      rawBarcode,
      warehouseId: warehouseId,
    );
    if (!mounted) return;
    if (res == null) {
      AppSnackbar.show(
        context,
        message: 'Código "$rawBarcode" no encontrado en catálogo',
        type: SnackbarType.error,
      );
      return;
    }

    final product = res.product;
    final variant = res.variant;

    final productModel = ProductModel.fromEntity(product);
    final variantModel =
        variant != null
            ? ProductVariantModel.fromEntity(variant)
            : (product.defaultVariant != null
                ? ProductVariantModel.fromEntity(product.defaultVariant!)
                : null);

    if (variantModel != null) {
      final exitItem = ExitItemUI(
        product: productModel,
        variant: variantModel,
        selectedBatch: null,
        quantity: 1.0,
        unitCost: variantModel.unitCost ?? 0.0,
      );
      cubit.addItem(exitItem);
      AppFeedbackService.mediumImpact();
      AppSnackbar.show(
        context,
        message: 'Agregado a salida: "${product.name}"',
        type: SnackbarType.success,
      );
    }
  }

  void _removeItemWithUndo(int index) {
    final cubit = context.read<InventoryExitFormCubit>();
    final items = cubit.state.items;
    if (index < 0 || index >= items.length) return;
    final removed = items[index];

    AppFeedbackService.lightImpact();
    cubit.removeItem(index);

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Quitaste "${removed.product.name}"'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
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
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      AppBackHandler.handleBack(context);
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
          (_) => ConfirmExitDialog(
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
  // BUILD PRINCIPAL (Zero-Shimmer & Tree Isolation)
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        final barcode = _gunDetector.onKeyEvent(event);
        if (barcode != null) {
          _handleGunBarcode(barcode);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _handleBackButton();
        },
        child: BlocSelector<
          InventoryExitFormCubit,
          InventoryExitFormState,
          bool
        >(
          selector: (state) => state.isLoading,
          builder: (context, isLoading) {
            if (isLoading) {
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
              body: BlocSelector<
                InventoryExitFormCubit,
                InventoryExitFormState,
                bool
              >(
                selector: (state) => state.isSaving,
                builder: (context, isSaving) {
                  return Stack(
                    children: [
                      AbsorbPointer(
                        absorbing: isSaving,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 900;

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Panel izquierdo: Formulario de datos y notas (flex 4)
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
                                            const ExitFormHeaderSection(),
                                            const SizedBox(height: 16),
                                            _buildNotesSection(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Panel derecho: Tabla de productos y barra de confirmación (flex 6)
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: SingleChildScrollView(
                                            padding: const EdgeInsets.all(24.0),
                                            child: ExitFormProductsSection(
                                              isDesktop: true,
                                              onAddProduct: _showAddProductSheet,
                                              onScanBarcode: _scanAndAddProduct,
                                              onClearDraft: _handleClearDraft,
                                              onRemoveItem: _removeItemWithUndo,
                                            ),
                                          ),
                                        ),
                                        ExitFormSummaryBar(onSave: _saveExit),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            // Vista Móvil / Tablet estrecha
                            return Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const ExitFormHeaderSection(),
                                        const SizedBox(height: 16),
                                        ExitFormProductsSection(
                                          isDesktop: false,
                                          onAddProduct: _showAddProductSheet,
                                          onScanBarcode: _scanAndAddProduct,
                                          onClearDraft: _handleClearDraft,
                                          onRemoveItem: _removeItemWithUndo,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildNotesSection(),
                                        const SizedBox(height: 24),
                                      ],
                                    ),
                                  ),
                                ),
                                ExitFormSummaryBar(onSave: _saveExit),
                              ],
                            );
                          },
                        ),
                      ),
                      if (isSaving)
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
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SECCIÓN DE NOTAS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildNotesSection() {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Notas y justificación',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: 'Notas / justificación (opcional)',
              labelStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppColors.surface,
              hintText: 'Ej: Botellas rotas durante el traslado',
              counterText: '',
              alignLabelWithHint: true,
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
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
