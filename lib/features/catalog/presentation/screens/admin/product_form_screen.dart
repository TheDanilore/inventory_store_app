import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_brands_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_by_id_uc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/layouts/product_form_desktop_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/layouts/product_form_mobile_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/layouts/product_form_skeleton.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_preview_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class ProductFormScreen extends StatelessWidget {
  final ProductEntity? productToEdit;

  /// Id del producto cuando se entra por /admin/products/product-form/:id sin que
  /// haya llegado el ProductEntity completo por `extra` (deep-link o
  /// refresh del navegador). Si viene, el Cubit lo busca en el arranque.
  final String? productId;

  const ProductFormScreen({super.key, this.productToEdit, this.productId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductFormCubit>(),
      child: _ProductFormScreenContent(
        productToEdit: productToEdit,
        productId: productId,
      ),
    );
  }
}

class _ProductFormScreenContent extends StatefulWidget {
  final ProductEntity? productToEdit;
  final String? productId;

  const _ProductFormScreenContent({this.productToEdit, this.productId});

  @override
  State<_ProductFormScreenContent> createState() =>
      _ProductFormScreenContentState();
}

class _ProductFormScreenContentState extends State<_ProductFormScreenContent> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers del formulario principal ─────────────────────────────────
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // ── Control de expansión masiva en Mobile ────────────────────────────────
  bool? _allExpanded;

  bool _initialized = false;
  bool _isShowingPopDialog = false;
  bool _allowExplicitPop = false;

  @override
  void initState() {
    super.initState();
    // Optimización Zero-Shimmer: Si los datos o entidades ya residen en caché L1,
    // precargamos los controladores síncronamente antes del primer frame.
    final effectiveId = widget.productToEdit?.id ?? widget.productId;
    final cachedProduct =
        widget.productToEdit ??
        (effectiveId != null
            ? sl<GetProductByIdUC>().getCached(effectiveId)
            : null);

    if (cachedProduct != null) {
      _nombreCtrl.text = cachedProduct.name;
      _descCtrl.text = cachedProduct.description ?? '';
      _initialized = true;
    } else if (widget.productId == null && widget.productToEdit == null) {
      if (sl<GetCategoriesUC>().getCached() != null &&
          sl<GetBrandsUC>().getCached() != null) {
        _initialized = true;
      }
    }

    _nombreCtrl.addListener(_onFieldInput);
    _descCtrl.addListener(_onFieldInput);
    _loadData();
  }

  void _onFieldInput() {
    if (_initialized) {
      context.read<ProductFormCubit>().markAsDirty();
    }
  }

  void _toggleExpandCollapseAll() {
    setState(() {
      final current = _allExpanded ?? false;
      _allExpanded = !current;
    });
  }

  Future<void> _loadData() async {
    final cubit = context.read<ProductFormCubit>();
    final initialValues = await cubit.loadInitialData(
      widget.productToEdit,
      productId: widget.productId,
    );
    if (mounted) {
      _nombreCtrl.text = initialValues.nombre;
      _descCtrl.text = initialValues.desc;
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.removeListener(_onFieldInput);
    _descCtrl.removeListener(_onFieldInput);
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final cubit = context.read<ProductFormCubit>();
    final state = cubit.state;
    if (state.isSaving || state.isInitializingData) return false;
    if (!cubit.hasUnsavedChanges) return true;
    if (_isShowingPopDialog) return false;

    _isShowingPopDialog = true;

    try {
      final shouldPop = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('¿Descartar cambios?'),
              content: const Text(
                'Si sales ahora, los cambios no guardados se perderán. ¿Deseas salir de todas formas?',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Salir',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
      );
      return shouldPop ?? false;
    } finally {
      _isShowingPopDialog = false;
    }
  }

  Future<void> _handleExit() async {
    final cubit = context.read<ProductFormCubit>();
    final state = cubit.state;
    if (!cubit.hasUnsavedChanges &&
        !state.isSaving &&
        !state.isInitializingData) {
      _exitForm();
      return;
    }

    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) {
      setState(() => _allowExplicitPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _exitForm();
        }
      });
    }
  }

  void _exitForm([Object? result]) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else {
      AppBackHandler.handleBack(context);
    }
  }

  bool _isEditableFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final widget = primaryFocus.context?.widget;
    return widget is EditableText ||
        primaryFocus.context?.findAncestorWidgetOfExactType<EditableText>() !=
            null;
  }

  void _handleEscapeKey() {
    if (_isEditableFocused()) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    _handleExit();
  }

  void _openPreview() {
    final cubit = context.read<ProductFormCubit>();
    ProductPreviewSheet.show(
      context,
      state: cubit.state,
      productName: _nombreCtrl.text,
      productDesc: _descCtrl.text,
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<ProductFormCubit>();
    if (cubit.state.isSaving) return;

    await cubit.saveProduct(
      nombre: _nombreCtrl.text.trim(),
      desc: _descCtrl.text.trim(),
      ingredients: cubit.state.ingredientRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.productToEdit != null || widget.productId != null;

    return BlocListener<ProductFormCubit, ProductFormState>(
      listenWhen:
          (p, c) =>
              c.snackMessage != p.snackMessage ||
              c.snackError != p.snackError ||
              c.saveSuccess != p.saveSuccess,
      listener: (context, state) {
        if (state.saveSuccess) {
          _exitForm();
          return;
        }
        if (state.snackMessage != null) {
          AppSnackbar.show(
            context,
            message: state.snackMessage!,
            type: SnackbarType.warning,
          );
        }
        if (state.snackError != null) {
          AppSnackbar.show(
            context,
            message: state.snackError!,
            type: SnackbarType.error,
          );
        }
      },
      child: BlocBuilder<ProductFormCubit, ProductFormState>(
        buildWhen:
            (prev, current) =>
                prev.isInitializingData != current.isInitializingData ||
                prev.isBackgroundSyncing != current.isBackgroundSyncing ||
                prev.hasErrorLoading != current.hasErrorLoading ||
                prev.errorMessage != current.errorMessage,
        builder: (context, state) {
          final canPopNow = _allowExplicitPop;
          return PopScope(
            canPop: canPopNow,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final currentCubit = context.read<ProductFormCubit>();
              final currentState = currentCubit.state;
              if (!currentCubit.hasUnsavedChanges &&
                  !currentState.isSaving &&
                  !currentState.isInitializingData) {
                setState(() => _allowExplicitPop = true);
                _exitForm();
                return;
              }
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                setState(() => _allowExplicitPop = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    _exitForm();
                  }
                });
              }
            },
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                    _guardar,
                const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                    _guardar,
                const SingleActivator(LogicalKeyboardKey.keyS, alt: true):
                    _guardar,
                const SingleActivator(LogicalKeyboardKey.keyG, alt: true):
                    _guardar,
                const SingleActivator(LogicalKeyboardKey.keyP, control: true):
                    _openPreview,
                const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
                    _openPreview,
                const SingleActivator(LogicalKeyboardKey.keyV, alt: true): () {
                  final cubit = context.read<ProductFormCubit>();
                  if (!cubit.state.hasMultipleVariants) {
                    cubit.setHasMultipleVariants(true);
                  }
                  cubit.addVariantDraft();
                },
                const SingleActivator(LogicalKeyboardKey.keyE, alt: true):
                    _toggleExpandCollapseAll,
                const SingleActivator(LogicalKeyboardKey.escape):
                    _handleEscapeKey,
              },
              child: AdminLayout(
                title: isEdit ? 'Editar Producto' : 'Nuevo Producto',
                breadcrumb:
                    'Catálogo  ›  ${isEdit ? 'Editar Producto' : 'Nuevo Producto'}',
                showBackButton: true,
                showProfileButton: false,
                showDrawerButton: false,
                onBack: _handleExit,
                actions: const [],
                body: Scaffold(
                  backgroundColor: AppColors.background,
                  body:
                      !_initialized || state.isInitializingData
                          ? const ProductFormSkeleton()
                          : state.hasErrorLoading
                          ? _buildErrorState()
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              final isDesktop = constraints.maxWidth >= 1024;
                              return Form(
                                key: _formKey,
                                child: Stack(
                                  children: [
                                    if (isDesktop)
                                      ProductFormDesktopLayout(
                                        isEdit: isEdit,
                                        nombreCtrl: _nombreCtrl,
                                        descCtrl: _descCtrl,
                                        onExit: _handleExit,
                                        onPreview: _openPreview,
                                        onSave: _guardar,
                                      )
                                    else
                                      ProductFormMobileLayout(
                                        isEdit: isEdit,
                                        nombreCtrl: _nombreCtrl,
                                        descCtrl: _descCtrl,
                                        allExpanded: _allExpanded,
                                        onToggleExpandCollapseAll:
                                            _toggleExpandCollapseAll,
                                        onExit: _handleExit,
                                        onPreview: _openPreview,
                                        onSave: _guardar,
                                      ),

                                    // Indicador sutil de sincronización en segundo plano (SWR)
                                    if (state.isBackgroundSyncing)
                                      const Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: LinearProgressIndicator(
                                          minHeight: 2.5,
                                          color: AppColors.primary,
                                          backgroundColor: Colors.transparent,
                                        ),
                                      ),

                                    // Overlay de guardado
                                    BlocSelector<
                                      ProductFormCubit,
                                      ProductFormState,
                                      bool
                                    >(
                                      selector: (s) => s.isSaving,
                                      builder: (context, isSaving) {
                                        if (!isSaving) {
                                          return const SizedBox.shrink();
                                        }
                                        return Positioned.fill(
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 5.0,
                                              sigmaY: 5.0,
                                            ),
                                            child: Container(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              context.read<ProductFormCubit>().state.errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Reintentar cargar datos',
              onPressed: _loadData,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.go('/products'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Volver al Inventario'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
