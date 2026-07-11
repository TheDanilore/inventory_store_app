import 'package:inventory_store_app/core/di/injection_container.dart';

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

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

class _ProductFormScreenContentState
    extends State<_ProductFormScreenContent> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers del formulario principal (viven aquí, no en el Cubit) ───────
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
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text(
          'Si sales ahora, los cambios no guardados se perderán. ¿Deseas salir de todas formas?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Salir', style: TextStyle(color: Colors.red)),
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
    final cubit = context.read<ProductFormCubit>();
    final isEdit = widget.productToEdit != null;

    return BlocListener<ProductFormCubit, ProductFormState>(
      listenWhen: (p, c) =>
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
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) Navigator.pop(context);
            },
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: !_initialized || state.isInitializingData
                  ? const _ProductFormSkeleton()
                  : state.hasErrorLoading
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off_rounded,
                                    size: 64, color: AppColors.error),
                                const SizedBox(height: 16),
                                Text(
                                  state.errorMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.black87),
                                ),
                                const SizedBox(height: 24),
                                AppPrimaryButton(
                                  label: 'Reintentar cargar datos',
                                  onPressed: _loadData,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Stack(
                          children: [
                            Form(
                              key: _formKey,
                              onChanged: cubit.markAsDirty,
                              child: CustomScrollView(
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
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'Variantes',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: cubit.addVariantDraft,
                                              icon: const Icon(
                                                  Icons.add_circle_outline),
                                              label: const Text('Agregar'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (state.variantDrafts.isEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Sin variantes aún. Agrega una si este producto cambia por color, talla, etc.',
                                            ),
                                          ),
                                      ]),
                                    ),
                                  ),
                                  if (state.variantDrafts.isNotEmpty)
                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            return VariantDraftCard(
                                              index: index,
                                              draft: state.variantDrafts[index],
                                              onRemove: () =>
                                                  cubit.removeVariantDraft(index),
                                              onDuplicate: () =>
                                                  cubit.duplicateVariantDraft(index),
                                              onActiveChanged: (val) {
                                                cubit.updateVariantDraft(
                                                  index,
                                                  state.variantDrafts[index]
                                                      .copyWith(isActive: val),
                                                );
                                              },
                                              onPickImage: () =>
                                                  cubit.pickVariantImage(index),
                                              onUpdate: (newDraft) =>
                                                  cubit.updateVariantDraft(index, newDraft),
                                            );
                                          },
                                          childCount: state.variantDrafts.length,
                                        ),
                                      ),
                                    ),
                                  if (state.variantDrafts.isNotEmpty)
                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      sliver: SliverToBoxAdapter(
                                        child: Column(
                                          children: [
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: cubit.addVariantDraft,
                                                icon: const Icon(
                                                    Icons.add_circle_outline),
                                                label: const Text(
                                                    'Agregar otra variante'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      AppColors.primary,
                                                  side: BorderSide(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          vertical: 14),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SliverPadding(
                                    padding: EdgeInsets.only(bottom: 100),
                                  ),
                                ],
                              ),
                            ),
                            // ── Barra inferior de guardado ─────────────────────
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ClipRRect(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 15.0, sigmaY: 15.0),
                                  child: Container(
                                    padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        top: 16,
                                        bottom: 32),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                      border: Border(
                                        top: BorderSide(
                                            color: Colors.grey
                                                .withValues(alpha: 0.2)),
                                      ),
                                    ),
                                    child: AppPrimaryButton(
                                      label: isEdit
                                          ? 'Actualizar Producto'
                                          : 'Guardar Producto',
                                      onPressed: state.isSaving
                                          ? null
                                          : _guardar,
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (state.isSaving)
                              Positioned.fill(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 5.0, sigmaY: 5.0),
                                  child: Container(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          color: AppColors.primary),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductFormSkeleton extends StatelessWidget {
  const _ProductFormSkeleton();

  @override
  Widget build(BuildContext context) {
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
  }
}
