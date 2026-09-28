import 'package:inventory_store_app/core/di/injection_container.dart';

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

// Secciones modulares
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_images_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_basic_info_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_config_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_details_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_ingredients_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_batch_section.dart';

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

  // ── Control de expansión masiva y filtro de variantes ────────────────────
  bool? _allExpanded;
  int _expandCollapseVersion = 0;
  final _variantSearchCtrl = TextEditingController();
  String _variantSearchTerm = '';

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _toggleExpandCollapseAll() {
    setState(() {
      final current = _allExpanded ?? false;
      _allExpanded = !current;
      _expandCollapseVersion++;
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
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _variantSearchCtrl.dispose();
    super.dispose();
  }

  bool _isShowingPopDialog = false;
  bool _allowExplicitPop = false;

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
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        context.go('/products');
      }
      return;
    }

    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) {
      setState(() => _allowExplicitPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.go('/products');
          }
        }
      });
    }
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
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          } else {
            context.go('/products');
          }
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
        buildWhen: (prev, current) =>
            prev.isInitializingData != current.isInitializingData ||
            prev.hasErrorLoading != current.hasErrorLoading ||
            prev.errorMessage != current.errorMessage,
        builder: (context, state) {
          final cubit = context.read<ProductFormCubit>();
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
                if (Navigator.canPop(context)) {
                  Navigator.pop(context, result);
                } else {
                  context.go('/products');
                }
                return;
              }
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                setState(() => _allowExplicitPop = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context, result);
                    } else {
                      context.go('/products');
                    }
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
                const SingleActivator(LogicalKeyboardKey.keyV, alt: true):
                    () => context.read<ProductFormCubit>().addVariantDraft(),
                const SingleActivator(LogicalKeyboardKey.keyE, alt: true):
                    _toggleExpandCollapseAll,
                const SingleActivator(LogicalKeyboardKey.escape): _handleExit,
              },
              child: AdminLayout(
                title: isEdit ? 'Editar Producto' : 'Nuevo Producto',
                breadcrumb:
                    'Catálogo  ›  ${isEdit ? 'Editar Producto' : 'Nuevo Producto'}',
                showBackButton: true,
                showProfileButton: false,
                showDrawerButton: false,
                onBack: _handleExit,
                body: Scaffold(
                  backgroundColor: AppColors.background,
                  body:
                      !_initialized || state.isInitializingData
                          ? const _ProductFormSkeleton()
                          : state.hasErrorLoading
                          ? _buildErrorState()
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              final isDesktop = constraints.maxWidth >= 1024;
                              return Form(
                                key: _formKey,
                                onChanged: cubit.markAsDirty,
                                child: Stack(
                                  children: [
                                    if (isDesktop)
                                      _buildDesktopSplitLayout(
                                        context,
                                        cubit,
                                        isEdit,
                                      )
                                    else
                                      _buildMobileSingleColumnLayout(
                                        context,
                                        cubit,
                                        isEdit,
                                      ),
                                    BlocSelector<
                                      ProductFormCubit,
                                      ProductFormState,
                                      bool
                                    >(
                                      selector: (state) => state.isSaving,
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

  // ── Layout Desktop: Split ERP 2 Columnas (width >= 1024) ────────────────────
  Widget _buildDesktopSplitLayout(
    BuildContext context,
    ProductFormCubit cubit,
    bool isEdit,
  ) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Columna Principal Izquierda (60% ancho)
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProductBasicInfoSection(
                          nombreCtrl: _nombreCtrl,
                          descCtrl: _descCtrl,
                        ),
                        const SizedBox(height: 20),
                        const ProductDetailsSection(),
                        const SizedBox(height: 20),
                        const ProductIngredientsSection(),
                        const SizedBox(height: 20),
                        const ProductBatchSection(),
                        const SizedBox(height: 20),
                        _buildVariantsHeader(cubit),
                        const SizedBox(height: 12),
                        _buildVariantsList(cubit),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Columna Lateral Derecha (40% ancho)
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ProductImagesSection(),
                        const SizedBox(height: 20),
                        const ProductConfigSection(),
                        const SizedBox(height: 20),
                        _buildDesktopSaveCard(cubit, isEdit),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Barra inferior de guardado Sticky persistente (Estilo Stripe / Linear)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.94),
                  border: Border(top: BorderSide(color: AppColors.border)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Row(
                      children: [
                        // Micro-estado de cambios pendientes
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                cubit.hasUnsavedChanges
                                    ? Colors.orange.shade50
                                    : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  cubit.hasUnsavedChanges
                                      ? Colors.orange.shade200
                                      : Colors.green.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color:
                                      cubit.hasUnsavedChanges
                                          ? Colors.orange.shade600
                                          : Colors.green.shade600,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cubit.hasUnsavedChanges
                                    ? 'Cambios sin guardar'
                                    : 'Cambios al día',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      cubit.hasUnsavedChanges
                                          ? Colors.orange.shade800
                                          : Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: _nombreCtrl,
                            builder: (context, _) {
                              final name = _nombreCtrl.text.trim();
                              return Text(
                                name.isNotEmpty
                                    ? name
                                    : (isEdit
                                        ? 'Editar Producto'
                                        : 'Nuevo Producto'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: _handleExit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radius,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Descartar (Esc)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                      BlocSelector<ProductFormCubit, ProductFormState, bool>(
                        selector: (s) => s.isSaving,
                        builder: (context, isSaving) {
                          return FilledButton.icon(
                            onPressed: isSaving ? null : _guardar,
                            icon:
                                isSaving
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              isEdit
                                  ? 'Actualizar Producto (Alt+G)'
                                  : 'Guardar Producto (Alt+G)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radius,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildDesktopSaveCard(
    ProductFormCubit cubit,
    bool isEdit,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.save_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Guardar Cambios' : 'Publicar Producto',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              BlocBuilder<ProductFormCubit, ProductFormState>(
                buildWhen: (p, c) => p.isDirty != c.isDirty,
                builder: (context, state) {
                  final isDirty = cubit.hasUnsavedChanges;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDirty
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isDirty
                                ? Colors.orange.shade200
                                : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color:
                                isDirty
                                    ? Colors.orange.shade600
                                    : Colors.green.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isDirty ? 'Sin guardar' : 'Al día',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                isDirty
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          BlocSelector<ProductFormCubit, ProductFormState, bool>(
            selector: (s) => s.isSaving,
            builder: (context, isSaving) {
              return AppPrimaryButton(
                label: isEdit ? 'Actualizar Producto' : 'Guardar Producto',
                icon: const Icon(Icons.check_rounded, size: 20),
                onPressed: isSaving ? null : _guardar,
                loading: isSaving,
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _handleExit,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text(
                  'Descartar',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'Alt+G',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'Esc',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Layout Móvil: 1 Columna Vertical Continua (width < 1024) ─────────────
  Widget _buildMobileSingleColumnLayout(
    BuildContext context,
    ProductFormCubit cubit,
    bool isEdit,
  ) {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const ProductImagesSection(),
                  const SizedBox(height: 16),
                  ProductBasicInfoSection(
                    nombreCtrl: _nombreCtrl,
                    descCtrl: _descCtrl,
                  ),
                  const SizedBox(height: 16),
                  const ProductConfigSection(),
                  const SizedBox(height: 16),
                  const ProductDetailsSection(),
                  const SizedBox(height: 16),
                  const ProductIngredientsSection(),
                  const SizedBox(height: 16),
                  const ProductBatchSection(),
                  const SizedBox(height: 20),
                  _buildVariantsHeader(cubit),
                  const SizedBox(height: 12),
                  _buildVariantsList(cubit),
                ]),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
          ],
        ),

        // Barra inferior de guardado Sticky con Blur iOS
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.94),
                  border: Border(top: BorderSide(color: AppColors.border)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: _handleExit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppColors.radius,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Salir',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BlocSelector<
                          ProductFormCubit,
                          ProductFormState,
                          bool
                        >(
                          selector: (s) => s.isSaving,
                          builder: (context, isSaving) {
                            return AppPrimaryButton(
                              label:
                                  isEdit
                                      ? 'Actualizar Producto'
                                      : 'Guardar Producto',
                              icon: const Icon(Icons.check_rounded, size: 20),
                              onPressed: isSaving ? null : _guardar,
                              loading: isSaving,
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Headers & Listas de Variantes ──────────────────────────────────────────
  Widget _buildVariantsHeader(ProductFormCubit cubit) {
    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen: (p, c) =>
          p.variantDrafts.length != c.variantDrafts.length ||
          p.variantDrafts.where((d) => d.isActive).length !=
              c.variantDrafts.where((d) => d.isActive).length,
      builder: (context, state) {
        final count = state.variantDrafts.length;
        final activeCount = state.variantDrafts.where((d) => d.isActive).length;
        final isAllExpanded = _allExpanded == true;

        return Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Variantes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count ${count == 1 ? 'variante' : 'variantes'}${count > 0 ? ' • $activeCount activas' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (count > 1) ...[
              TextButton.icon(
                onPressed: _toggleExpandCollapseAll,
                icon: Icon(
                  isAllExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  size: 16,
                ),
                label: Text(
                  isAllExpanded ? 'Colapsar todo' : 'Expandir todo',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
              const SizedBox(width: 6),
            ],
            FilledButton.icon(
              onPressed: cubit.addVariantDraft,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Agregar variante',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radius),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVariantsList(ProductFormCubit cubit) {
    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen: (p, c) => p.variantDrafts != c.variantDrafts,
      builder: (context, state) {
        if (state.variantDrafts.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            child: const Text(
              'Sin variantes aún. Agrega una si este producto cambia por color, talla, etc.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          );
        }

        final totalCount = state.variantDrafts.length;
        final term = _variantSearchTerm.trim().toLowerCase();

        final List<int> filteredIndices = [];
        for (int i = 0; i < totalCount; i++) {
          if (term.isEmpty) {
            filteredIndices.add(i);
          } else {
            final d = state.variantDrafts[i];
            final matchSku = d.sku.toLowerCase().contains(term);
            final matchNum = (i + 1).toString() == term;
            final matchAttr = d.selectedAttributes.any((a) {
              final an = (a['attribute_name'] ?? '').toString().toLowerCase();
              final vn = (a['value_name'] ?? '').toString().toLowerCase();
              return an.contains(term) || vn.contains(term);
            });
            if (matchSku || matchNum || matchAttr) {
              filteredIndices.add(i);
            }
          }
        }

        return Column(
          children: [
            if (totalCount > 4) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _variantSearchCtrl,
                  onChanged: (val) => setState(() => _variantSearchTerm = val),
                  decoration: InputDecoration(
                    hintText: 'Filtrar variantes por modelo, atributo o SKU...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade400,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon:
                        _variantSearchTerm.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _variantSearchCtrl.clear();
                                setState(() => _variantSearchTerm = '');
                              },
                            )
                            : null,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ],
            if (filteredIndices.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'No se encontraron variantes que coincidan con "$_variantSearchTerm"',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...filteredIndices.map((index) {
                final draft = state.variantDrafts[index];
                return VariantDraftCard(
                  key: ValueKey(
                    '${draft.id ?? 'draft_${draft.hashCode}_$index'}_v$_expandCollapseVersion',
                  ),
                  index: index,
                  draft: draft,
                  isExpanded: _allExpanded,
                  onRemove: () => cubit.removeVariantDraft(index),
                  onDuplicate: () => cubit.duplicateVariantDraft(index),
                  onActiveChanged: (val) {
                    cubit.updateVariantDraft(
                      index,
                      draft.copyWith(isActive: val),
                      syncState: true,
                    );
                  },
                  onPickImage: () => cubit.pickVariantImage(index),
                  onUpdate:
                      (newDraft, {syncState = false}) =>
                          cubit.updateVariantDraft(
                            index,
                            newDraft,
                            syncState: syncState,
                          ),
                );
              }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: cubit.addVariantDraft,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Agregar otra variante'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Skeleton Loader Responsivo ─────────────────────────────────────────────
class _ProductFormSkeleton extends StatelessWidget {
  const _ProductFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        if (isDesktop) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: const [
                      AppShimmer(
                        width: double.infinity,
                        height: 180,
                        borderRadius: 16,
                      ),
                      SizedBox(height: 16),
                      AppShimmer(
                        width: double.infinity,
                        height: 250,
                        borderRadius: 16,
                      ),
                      SizedBox(height: 16),
                      AppShimmer(
                        width: double.infinity,
                        height: 200,
                        borderRadius: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: const [
                      AppShimmer(
                        width: double.infinity,
                        height: 220,
                        borderRadius: 16,
                      ),
                      SizedBox(height: 16),
                      AppShimmer(
                        width: double.infinity,
                        height: 160,
                        borderRadius: 16,
                      ),
                      SizedBox(height: 16),
                      AppShimmer(
                        width: double.infinity,
                        height: 100,
                        borderRadius: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [AppShimmer(width: 120, height: 40, borderRadius: 12)],
            ),
            SizedBox(height: 16),
            AppShimmer(width: double.infinity, height: 180, borderRadius: 16),
            SizedBox(height: 16),
            AppShimmer(width: double.infinity, height: 300, borderRadius: 16),
            SizedBox(height: 16),
            AppShimmer(width: double.infinity, height: 120, borderRadius: 16),
            SizedBox(height: 16),
            AppShimmer(width: double.infinity, height: 250, borderRadius: 16),
          ],
        );
      },
    );
  }
}
