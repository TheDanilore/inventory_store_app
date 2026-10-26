import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';
import 'package:inventory_store_app/core/utils/hardware_barcode_gun_detector.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/form/inventory_entry_form_components.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

export 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/form/inventory_entry_form_components.dart';

class InventoryEntryFormScreen extends StatefulWidget {
  final String? purchaseOrderId;
  final List<InventoryEntryItemEntity>? prefillItems;
  final String? prefillSupplierId;
  final String? prefillSupplierName;
  final String? prefillWarehouseId;
  final String? prefillDocumentType;
  final String? prefillDocumentNumber;
  final DateTime? prefillDocumentDate;

  const InventoryEntryFormScreen({
    super.key,
    this.purchaseOrderId,
    this.prefillItems,
    this.prefillSupplierId,
    this.prefillSupplierName,
    this.prefillWarehouseId,
    this.prefillDocumentType,
    this.prefillDocumentNumber,
    this.prefillDocumentDate,
  });

  @override
  State<InventoryEntryFormScreen> createState() =>
      _InventoryEntryFormScreenState();
}

class _InventoryEntryFormScreenState extends State<InventoryEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _gunDetector = HardwareBarcodeGunDetector();

  @override
  void initState() {
    super.initState();
    if (widget.prefillDocumentNumber != null) {
      _documentNumberCtrl.text = widget.prefillDocumentNumber!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final cubit = context.read<InventoryEntryFormCubit>();
    cubit.init(
      purchaseOrderId: widget.purchaseOrderId,
      prefillItems: widget.prefillItems,
      prefillSupplierId: widget.prefillSupplierId,
      prefillWarehouseId: widget.prefillWarehouseId,
      prefillDocumentType: widget.prefillDocumentType,
      prefillDocumentNumber: widget.prefillDocumentNumber,
      prefillDocumentDate: widget.prefillDocumentDate,
    );
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _documentNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocumentDate(BuildContext context) async {
    final cubit = context.read<InventoryEntryFormCubit>();
    final picked = await showDatePicker(
      context: context,
      initialDate: cubit.state.documentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha del Documento Físico',
    );
    if (picked != null) {
      cubit.setDocumentDate(picked);
    }
  }

  Future<void> _showAddProductSheet(BuildContext context) async {
    final cubit = context.read<InventoryEntryFormCubit>();
    if (cubit.state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén destino primero',
        type: SnackbarType.warning,
      );
      return;
    }

    final newItem = await AddEntryProductSheet.show(
      context,
      warehouseId: cubit.state.selectedWarehouseId,
      onAddAndContinue: (item) => cubit.addItem(item),
    );

    if (newItem != null && mounted) {
      cubit.addItem(newItem);
    }
  }

  Future<void> _scanAndAddProduct(BuildContext context) async {
    final cubit = context.read<InventoryEntryFormCubit>();
    if (cubit.state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén destino primero',
        type: SnackbarType.warning,
      );
      return;
    }

    await PosCameraScannerDialog.show(
      context,
      warehouseId: cubit.state.selectedWarehouseId,
      title: 'Escanear Entradas a Almacén',
      continuousMode: true,
      onContinuousScan: (res) async {
        cubit.handleScannedProduct(product: res.product, variant: res.variant);
      },
    );
  }

  Future<void> _handleGunBarcode(String rawBarcode) async {
    final cubit = context.read<InventoryEntryFormCubit>();
    if (cubit.state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén destino primero para escanear',
        type: SnackbarType.warning,
      );
      return;
    }

    final res = await PosBarcodeScannerService.resolveCode(
      rawBarcode,
      warehouseId: cubit.state.selectedWarehouseId,
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

    AppFeedbackService.mediumImpact();
    final wasAddedNew = cubit.handleScannedProduct(
      product: res.product,
      variant: res.variant,
    );

    AppSnackbar.show(
      context,
      message:
          wasAddedNew
              ? 'Agregado: "${res.product.name}"'
              : '+1 a "${res.product.name}"',
      type: wasAddedNew ? SnackbarType.success : SnackbarType.info,
    );
  }

  void _removeItemWithUndo(InventoryEntryFormCubit cubit, int index) {
    final items = cubit.state.items;
    if (index < 0 || index >= items.length) return;
    final removed = items[index];

    AppFeedbackService.lightImpact();
    cubit.removeItem(index);

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Quitaste "${removed.productName}"'),
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

  Future<void> _handleSave() async {
    final cubit = context.read<InventoryEntryFormCubit>();
    cubit.setDocumentNumber(_documentNumberCtrl.text.trim());

    if (!mounted) return;

    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      AppSnackbar.show(
        context,
        message: 'Por favor complete los campos obligatorios del formulario',
        type: SnackbarType.warning,
      );
      return;
    }

    final activeShiftId = cubit.state.activeShiftId ?? "";

    if (!cubit.validate(activeShiftId)) {
      AppSnackbar.show(
        context,
        message: cubit.state.errorMessage,
        type: SnackbarType.error,
      );
      return;
    }

    await cubit.saveEntry(_notesCtrl.text.trim());
    if (!mounted) return;

    if (cubit.state.isSuccess) {
      AppSnackbar.show(
        context,
        message:
            widget.purchaseOrderId != null
                ? 'Recepción registrada. Kardex y Orden actualizados.'
                : 'Ingreso manual registrado correctamente.',
        type: SnackbarType.success,
      );
      if (!mounted) return;
      if (widget.purchaseOrderId != null) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          context.go('/purchase-orders?selectedId=${widget.purchaseOrderId}');
        }
      } else {
        context.go('/inventory-entries');
      }
    } else if (cubit.state.errorMessage.isNotEmpty) {
      AppSnackbar.show(
        context,
        message: cubit.state.errorMessage,
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _handleClearDraft() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Descartar Borrador'),
            content: const Text(
              '¿Estás seguro de que quieres limpiar los productos ingresados?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Descartar',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      context.read<InventoryEntryFormCubit>().clearDraft();
      _documentNumberCtrl.clear();
      _notesCtrl.clear();
      AppSnackbar.show(
        context,
        message: 'Borrador descartado',
        type: SnackbarType.info,
      );
    }
  }

  Future<void> _handleBackButton() async {
    final cubit = context.read<InventoryEntryFormCubit>();
    if (cubit.state.isSaving) return;

    if (widget.purchaseOrderId != null) {
      _exitForm();
      return;
    }

    if (cubit.state.items.isEmpty) {
      cubit.clearDraft();
      _exitForm();
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cambios sin guardar'),
            content: const Text(
              'Tienes un registro en curso. ¿Qué deseas hacer al salir?',
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
      _exitForm();
    } else if (action == 'draft') {
      _exitForm();
    }
  }

  void _exitForm([Object? result]) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else {
      AppBackHandler.handleBack(context);
    }
  }

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
        child: BlocConsumer<InventoryEntryFormCubit, InventoryEntryFormState>(
          listenWhen:
              (prev, curr) => prev.documentNumber != curr.documentNumber,
          listener: (context, state) {
            if (state.documentNumber != null &&
                _documentNumberCtrl.text != state.documentNumber) {
              _documentNumberCtrl.text = state.documentNumber!;
            }
          },
          buildWhen:
              (prev, curr) =>
                  prev.isLoading != curr.isLoading ||
                  prev.isSaving != curr.isSaving ||
                  prev.errorMessage != curr.errorMessage ||
                  prev.warehouses != curr.warehouses ||
                  prev.suppliers != curr.suppliers ||
                  prev.accounts != curr.accounts ||
                  prev.activeShiftsByAccount != curr.activeShiftsByAccount ||
                  prev.activeShiftId != curr.activeShiftId ||
                  prev.selectedWarehouseId != curr.selectedWarehouseId ||
                  prev.selectedSupplierId != curr.selectedSupplierId ||
                  prev.paymentMode != curr.paymentMode ||
                  prev.documentType != curr.documentType ||
                  prev.documentDate != curr.documentDate ||
                  prev.selectedAccountId != curr.selectedAccountId ||
                  prev.items != curr.items,
          builder: (context, state) {
            final cubit = context.read<InventoryEntryFormCubit>();
            final screenTitle =
                widget.purchaseOrderId != null
                    ? 'Recepción de Orden'
                    : 'Nueva Entrada Manual';

            // ── POLÍTICA ZERO-SHIMMER: Solo mostramos pantalla completa si NO hay datos en caché ──
            final hasCachedData =
                state.warehouses.isNotEmpty || state.items.isNotEmpty;

            if (state.isLoading && !hasCachedData) {
              return AdminLayout(
                title: screenTitle,
                showBackButton: true,
                onBack: _handleBackButton,
                showProfileButton: false,
                showDrawerButton: false,
                body: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            // Error crítico si no hay almacenes y falló la inicialización en frío
            if (!state.isLoading &&
                state.errorMessage.isNotEmpty &&
                state.warehouses.isEmpty) {
              return AdminLayout(
                title: screenTitle,
                showBackButton: true,
                onBack: _handleBackButton,
                showProfileButton: false,
                showDrawerButton: false,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Error al cargar catálogos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadInitialData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return AdminLayout(
              title: screenTitle,
              showBackButton: true,
              onBack: _handleBackButton,
              showProfileButton: false,
              showDrawerButton: false,
              body: Stack(
                children: [
                  AbsorbPointer(
                    absorbing: state.isSaving,
                    child: Form(
                      key: _formKey,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Columna Izquierda: Datos, Finanzas, Documento (40%)
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
                                          EntryFormMainDataCard(
                                            state: state,
                                            cubit: cubit,
                                            prefillSupplierName:
                                                widget.prefillSupplierName,
                                          ),
                                          const SizedBox(height: 16),
                                          if (widget.purchaseOrderId ==
                                              null) ...[
                                            EntryFormFinanceCard(
                                              state: state,
                                              cubit: cubit,
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                          EntryFormDocumentCard(
                                            state: state,
                                            cubit: cubit,
                                            documentNumberCtrl:
                                                _documentNumberCtrl,
                                            notesCtrl: _notesCtrl,
                                            onPickDate:
                                                () =>
                                                    _pickDocumentDate(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Columna Derecha: Productos y Botón Guardar (60%)
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(24.0),
                                          child: EntryFormProductsSection(
                                            isDesktop: true,
                                            purchaseOrderId:
                                                widget.purchaseOrderId,
                                            onAddNewRow:
                                                () => _showAddProductSheet(
                                                  context,
                                                ),
                                            onScanBarcode:
                                                () =>
                                                    _scanAndAddProduct(context),
                                            onClearDraft: _handleClearDraft,
                                            onEditBatch:
                                                (index, item) =>
                                                    EntryBatchEditDialog.show(
                                                      context,
                                                      itemIndex: index,
                                                      item: item,
                                                      cubit: cubit,
                                                    ),
                                            onRemoveItem:
                                                (index) => _removeItemWithUndo(
                                                  cubit,
                                                  index,
                                                ),
                                            onUpdateQuantity:
                                                (index, qty) =>
                                                    cubit.updateItemQuantity(
                                                      index,
                                                      qty,
                                                    ),
                                            onUpdateCost:
                                                (index, cost) =>
                                                    cubit.updateItemCost(
                                                      index,
                                                      cost,
                                                    ),
                                          ),
                                        ),
                                      ),
                                      EntryFormStickySaveBar(
                                        onSave: _handleSave,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          // Layout Móvil
                          return Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      EntryFormMainDataCard(
                                        state: state,
                                        cubit: cubit,
                                        prefillSupplierName:
                                            widget.prefillSupplierName,
                                      ),
                                      const SizedBox(height: 16),
                                      if (widget.purchaseOrderId == null) ...[
                                        EntryFormFinanceCard(
                                          state: state,
                                          cubit: cubit,
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      EntryFormDocumentCard(
                                        state: state,
                                        cubit: cubit,
                                        documentNumberCtrl: _documentNumberCtrl,
                                        notesCtrl: _notesCtrl,
                                        onPickDate:
                                            () => _pickDocumentDate(context),
                                      ),
                                      const SizedBox(height: 16),
                                      EntryFormProductsSection(
                                        isDesktop: false,
                                        purchaseOrderId: widget.purchaseOrderId,
                                        onAddNewRow:
                                            () => _showAddProductSheet(context),
                                        onScanBarcode:
                                            () => _scanAndAddProduct(context),
                                        onClearDraft: _handleClearDraft,
                                        onEditBatch:
                                            (index, item) =>
                                                EntryBatchEditDialog.show(
                                                  context,
                                                  itemIndex: index,
                                                  item: item,
                                                  cubit: cubit,
                                                ),
                                        onRemoveItem:
                                            (index) => _removeItemWithUndo(
                                              cubit,
                                              index,
                                            ),
                                        onUpdateQuantity:
                                            (index, qty) => cubit
                                                .updateItemQuantity(index, qty),
                                        onUpdateCost:
                                            (index, cost) => cubit
                                                .updateItemCost(index, cost),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ),
                              EntryFormStickySaveBar(onSave: _handleSave),
                            ],
                          );
                        },
                      ),
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
      ),
    );
  }
}
