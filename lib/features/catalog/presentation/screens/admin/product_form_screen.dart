import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/presentation/providers/product_form_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

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
  final ProductModel? productToEdit;

  const ProductFormScreen({super.key, this.productToEdit});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProductFormProvider()..initData(productToEdit),
      child: _ProductFormScreenContent(),
    );
  }
}

class _ProductFormScreenContent extends StatefulWidget {
  @override
  State<_ProductFormScreenContent> createState() =>
      _ProductFormScreenContentState();
}

class _ProductFormScreenContentState extends State<_ProductFormScreenContent> {
  final _formKey = GlobalKey<FormState>();

  Future<bool> _onWillPop(BuildContext context) async {
    final provider = context.read<ProductFormProvider>();
    if (provider.isSaving || provider.isInitializingData) return false;

    if (!provider.hasUnsavedChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('¿Descartar cambios?'),
            content: const Text(
              'Si sales ahora, los cambios no guardados se perderán. ¿Deseas salir de todas formas?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    return shouldPop ?? false;
  }

  void _guardar(BuildContext context) async {
    final provider = context.read<ProductFormProvider>();
    if (provider.isSaving) return;

    final success = await provider.saveProduct(context, _formKey);
    if (success && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductFormProvider>();
    final isEdit = provider.productToEdit != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop(context);
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: AdminLayout(
        title: isEdit ? 'Editar Producto' : 'Nuevo Producto',
        showBackButton: true,
        showProfileButton: false,
        showDrawerButton: false,
        body:
            provider.isInitializingData
                ? const _ProductFormSkeleton()
                : provider.hasErrorLoading
                ? Center(
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
                          provider.errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppPrimaryButton(
                          label: 'Reintentar cargar datos',
                          onPressed:
                              () => provider.initData(provider.productToEdit),
                        ),
                      ],
                    ),
                  ),
                )
                : Stack(
                  children: [
                    Form(
                      key: _formKey,
                      onChanged: () {
                        context.read<ProductFormProvider>().markAsDirty();
                      },
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(16.0),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                const ProductImagesSection(),
                                const SizedBox(height: 16),
                                const ProductBasicInfoSection(),
                                const SizedBox(height: 16),
                                const ProductConfigSection(),
                                const SizedBox(height: 16),
                                const ProductDetailsSection(),
                                const SizedBox(height: 16),
                                ProductPricingSection(formKey: _formKey),
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
                                      onPressed: provider.addVariantDraft,
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      label: const Text('Agregar'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (provider.variantDrafts.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Sin variantes aún. Agrega una si este producto cambia por color, talla, etc.',
                                    ),
                                  ),
                              ]),
                            ),
                          ),

                          if (provider.variantDrafts.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  return VariantDraftCard(
                                    index: index,
                                    draft: provider.variantDrafts[index],
                                    onRemove:
                                        () => provider.removeVariantDraft(
                                          context,
                                          index,
                                        ),
                                    onDuplicate:
                                        () => provider.duplicateVariantDraft(
                                          index,
                                        ),
                                    onActiveChanged: (val) {
                                      provider.variantDrafts[index].isActive =
                                          val;
                                      // Esto idealmente debería notificar al provider, pero VariantDraftCard usa su estado local también.
                                    },
                                    onPickImage:
                                        () => provider.pickVariantImage(
                                          context,
                                          index,
                                        ),
                                  );
                                }, childCount: provider.variantDrafts.length),
                              ),
                            ),

                          if (provider.variantDrafts.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: provider.addVariantDraft,
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        label: const Text(
                                          'Agregar otra variante',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: BorderSide(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                              color: Colors.white.withValues(alpha: 0.75),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            child: AppPrimaryButton(
                              label:
                                  isEdit
                                      ? 'Actualizar Producto'
                                      : 'Guardar Producto',
                              onPressed:
                                  provider.isSaving
                                      ? null
                                      : () => _guardar(context),
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (provider.isSaving)
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.4),
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
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [AppShimmer(width: 120, height: 40, borderRadius: 12)],
        ),
        const SizedBox(height: 16),
        const AppShimmer(width: double.infinity, height: 180, borderRadius: 16),
        const SizedBox(height: 16),
        const AppShimmer(width: double.infinity, height: 300, borderRadius: 16),
        const SizedBox(height: 16),
        const AppShimmer(width: double.infinity, height: 120, borderRadius: 16),
        const SizedBox(height: 16),
        const AppShimmer(width: double.infinity, height: 250, borderRadius: 16),
      ],
    );
  }
}
