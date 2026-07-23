import 'package:inventory_store_app/core/di/injection_container.dart';

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_state.dart';
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
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_pricing_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_ingredients_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_batch_section.dart';

class ProductFormScreen extends StatelessWidget {
  final ProductEntity? productToEdit;

  const ProductFormScreen({super.key, this.productToEdit});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductFormCubit>(),
      child: _ProductFormScreenContent(productToEdit: productToEdit),
    );
  }
}

class _ProductFormScreenContent extends StatefulWidget {
  final ProductEntity? productToEdit;

  const _ProductFormScreenContent({this.productToEdit});

  @override
  State<_ProductFormScreenContent> createState() =>
      _ProductFormScreenContentState();
}

class _ProductFormScreenContentState extends State<_ProductFormScreenContent> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers del formulario principal ─────────────────────────────────
  final _nombreCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _precioMayorCtrl = TextEditingController();
  final _cantidadMayorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cubit = context.read<ProductFormCubit>();
    final initialValues = await cubit.loadInitialData(widget.productToEdit);
    if (mounted) {
      _nombreCtrl.text = initialValues.nombre;
      _costoCtrl.text = initialValues.costo;
      _precioCtrl.text = initialValues.precio;
      _precioMayorCtrl.text = initialValues.precioMayor;
      _cantidadMayorCtrl.text = initialValues.cantidadMayor;
      _descCtrl.text = initialValues.desc;
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _costoCtrl.dispose();
    _precioCtrl.dispose();
    _precioMayorCtrl.dispose();
    _cantidadMayorCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final cubit = context.read<ProductFormCubit>();
    final state = cubit.state;
    if (state.isSaving || state.isInitializingData) return false;
    if (!cubit.hasUnsavedChanges) return true;

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
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<ProductFormCubit>();
    if (cubit.state.isSaving) return;

    await cubit.saveProduct(
      nombre: _nombreCtrl.text,
      costo: _costoCtrl.text,
      precio: _precioCtrl.text,
      precioMayor: _precioMayorCtrl.text,
      cantidadMayor: _cantidadMayorCtrl.text,
      desc: _descCtrl.text,
      ingredients: cubit.state.ingredientRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.productToEdit != null;

    return BlocListener<ProductFormCubit, ProductFormState>(
      listenWhen:
          (p, c) =>
              c.snackMessage != p.snackMessage ||
              c.snackError != p.snackError ||
              c.saveSuccess != p.saveSuccess,
      listener: (context, state) {
        if (state.saveSuccess) {
          Navigator.pop(context, true);
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
        builder: (context, state) {
          final cubit = context.read<ProductFormCubit>();
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) Navigator.pop(context);
            },
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                    _guardar,
                const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                    _guardar,
                const SingleActivator(LogicalKeyboardKey.escape): () async {
                  final shouldPop = await _onWillPop();
                  if (shouldPop && context.mounted) Navigator.pop(context);
                },
              },
              child: AdminLayout(
                title: isEdit ? 'Editar Producto' : 'Nuevo Producto',
                showBackButton: true,
                showProfileButton: false,
                showDrawerButton: false,
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
                                        state,
                                        cubit,
                                        isEdit,
                                      )
                                    else
                                      _buildMobileSingleColumnLayout(
                                        context,
                                        state,
                                        cubit,
                                        isEdit,
                                      ),

                                    if (state.isSaving)
                                      Positioned.fill(
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 5.0,
                                            sigmaY: 5.0,
                                          ),
                                          child: Container(
                                            color: AppColors.surface.withValues(
                                              alpha: 0.4,
                                            ),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.primary,
                                              ),
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
          ],
        ),
      ),
    );
  }

  // ── Layout Desktop: Split ERP 2 Columnas (width >= 1024) ────────────────────
  Widget _buildDesktopSplitLayout(
    BuildContext context,
    ProductFormState state,
    ProductFormCubit cubit,
    bool isEdit,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                    ProductPricingSection(
                      formKey: _formKey,
                      costoCtrl: _costoCtrl,
                      precioCtrl: _precioCtrl,
                      precioMayorCtrl: _precioMayorCtrl,
                      cantidadMayorCtrl: _cantidadMayorCtrl,
                    ),
                    const SizedBox(height: 20),
                    const ProductIngredientsSection(),
                    const SizedBox(height: 20),
                    const ProductBatchSection(),
                    const SizedBox(height: 20),
                    _buildVariantsHeader(cubit),
                    const SizedBox(height: 12),
                    _buildVariantsList(state, cubit),
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
                    // Sticky Save Card ERP
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppColors.radiusLg,
                        ),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.cardShadow(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                isEdit
                                    ? 'Guardar Cambios'
                                    : 'Publicar Producto',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Puedes presionar Ctrl+S en cualquier momento para guardar rápidamente.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppPrimaryButton(
                            label:
                                isEdit
                                    ? 'Actualizar Producto'
                                    : 'Guardar Producto',
                            onPressed: state.isSaving ? null : _guardar,
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Layout Móvil: 1 Columna Vertical Continua (width < 1024) ─────────────
  Widget _buildMobileSingleColumnLayout(
    BuildContext context,
    ProductFormState state,
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
                  ProductPricingSection(
                    formKey: _formKey,
                    costoCtrl: _costoCtrl,
                    precioCtrl: _precioCtrl,
                    precioMayorCtrl: _precioMayorCtrl,
                    cantidadMayorCtrl: _cantidadMayorCtrl,
                  ),
                  const SizedBox(height: 16),
                  const ProductIngredientsSection(),
                  const SizedBox(height: 16),
                  const ProductBatchSection(),
                  const SizedBox(height: 16),
                  _buildVariantsHeader(cubit),
                  const SizedBox(height: 8),
                  if (state.variantDrafts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(AppColors.radius),
                      ),
                      child: const Text(
                        'Sin variantes aún. Agrega una si este producto cambia por color, talla, etc.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            if (state.variantDrafts.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return VariantDraftCard(
                      index: index,
                      draft: state.variantDrafts[index],
                      onRemove: () => cubit.removeVariantDraft(index),
                      onDuplicate: () => cubit.duplicateVariantDraft(index),
                      onActiveChanged: (val) {
                        cubit.updateVariantDraft(
                          index,
                          state.variantDrafts[index].copyWith(isActive: val),
                        );
                      },
                      onPickImage: () => cubit.pickVariantImage(index),
                      onUpdate:
                          (newDraft) =>
                              cubit.updateVariantDraft(index, newDraft),
                    );
                  }, childCount: state.variantDrafts.length),
                ),
              ),
            if (state.variantDrafts.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
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
                              borderRadius: BorderRadius.circular(
                                AppColors.radius,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
              filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 32,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.85),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: AppPrimaryButton(
                  label: isEdit ? 'Actualizar Producto' : 'Guardar Producto',
                  onPressed: state.isSaving ? null : _guardar,
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
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
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Variantes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: cubit.addVariantDraft,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text(
            'Agregar',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildVariantsList(ProductFormState state, ProductFormCubit cubit) {
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

    return Column(
      children: [
        ...List.generate(state.variantDrafts.length, (index) {
          return VariantDraftCard(
            index: index,
            draft: state.variantDrafts[index],
            onRemove: () => cubit.removeVariantDraft(index),
            onDuplicate: () => cubit.duplicateVariantDraft(index),
            onActiveChanged: (val) {
              cubit.updateVariantDraft(
                index,
                state.variantDrafts[index].copyWith(isActive: val),
              );
            },
            onPickImage: () => cubit.pickVariantImage(index),
            onUpdate: (newDraft) => cubit.updateVariantDraft(index, newDraft),
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
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
              ),
            ),
          ),
        ),
      ],
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
