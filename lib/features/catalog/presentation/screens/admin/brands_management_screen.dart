import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/brands/brands_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/brands/brands_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/brands/brand_form_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/brands/brands_skeleton.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';

class BrandsManagementScreen extends StatefulWidget {
  const BrandsManagementScreen({super.key});

  @override
  State<BrandsManagementScreen> createState() => _BrandsManagementScreenState();
}

class _BrandsManagementScreenState extends State<BrandsManagementScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _isFabExtended.value) {
        _isFabExtended.value = false;
      } else if (_scrollController.offset <= 10 && !_isFabExtended.value) {
        _isFabExtended.value = true;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<BrandsCubit>();
      final query = cubit.state.searchQuery;
      if (query.isNotEmpty) _searchCtrl.text = query;
      cubit.loadBrands();
    });
  }

  @override
  void dispose() {
    _isFabExtended.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showBrandForm([BrandEntity? brand]) {
    BrandFormSheet.showAdaptive(context, brand: brand);
  }

  Future<void> _handleToggleStatus(
    BrandEntity brand,
    bool val,
    BrandsCubit cubit,
  ) async {
    HapticFeedback.lightImpact();
    if (!val) {
      final confirm = await AppConfirmDialog.show(
        context,
        title: 'Desactivar Marca',
        message:
            '¿Estás seguro de desactivar la marca "${brand.name}"? '
            'Los productos vinculados a esta marca permanecerán, pero la marca no se sugerirá en nuevos registros.',
        confirmText: 'Desactivar',
        confirmColor: AppColors.error,
      );
      if (confirm != true) return;
    }
    if (!mounted) return;
    cubit.toggleStatus(brand, val);
  }

  Future<void> _confirmDeleteBrand(
    BrandEntity brand,
    BrandsCubit cubit,
  ) async {
    final hasProducts = (brand.productsCount ?? 0) > 0;
    if (hasProducts) {
      AppSnackbar.show(
        context,
        message:
            'No se puede eliminar la marca "${brand.name}" porque tiene ${brand.productsCount} producto(s) vinculado(s). Reasigna los productos antes de eliminarla.',
        type: SnackbarType.warning,
      );
      return;
    }

    final confirm = await AppConfirmDialog.show(
      context,
      title: 'Eliminar Marca',
      message:
          '¿Estás seguro de eliminar permanentemente la marca "${brand.name}"?\n'
          'Esta acción no se puede deshacer.',
      confirmText: 'Eliminar Marca',
      confirmColor: AppColors.error,
    );
    if (confirm != true) return;
    if (!mounted) return;

    final success = await cubit.deleteBrand(brand.id!);
    if (success && mounted) {
      AppSnackbar.show(
        context,
        message: 'Marca "${brand.name}" eliminada exitosamente.',
        type: SnackbarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 720;
    final cubit = context.read<BrandsCubit>();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, alt: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          _showBrandForm();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
          _showBrandForm();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, alt: true): () {
          _showBrandForm();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          } else if (_searchCtrl.text.isNotEmpty) {
            _searchCtrl.clear();
            cubit.clearSearch();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: AdminLayout(
          title: 'Marcas y Fabricantes',
          showBackButton: true,
          breadcrumb: 'Inicio  ›  Marcas',
          floatingActionButton: isMobile ? _buildMobileFab() : null,
          body: BlocConsumer<BrandsCubit, BrandsState>(
            listener: (context, state) {
              if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
                AppSnackbar.show(
                  context,
                  message: state.errorMessage!,
                  type: SnackbarType.error,
                );
              }
            },
            builder: (context, state) {
              return Column(
                children: [
                  _buildHeaderBar(context, state, isMobile),
                  Expanded(
                    child: _buildBody(context, state, isMobile),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Header Command Bar ───────────────────────────────────────────────────
  Widget _buildHeaderBar(
    BuildContext context,
    BrandsState state,
    bool isMobile,
  ) {
    final cubit = context.read<BrandsCubit>();
    final activeCount = state.brands.where((b) => b.isActive).length;
    final totalCount = state.brands.length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Buscador reactivo
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    onChanged: cubit.onSearchChanged,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: isMobile
                          ? 'Buscar marcas...'
                          : 'Buscar marcas por nombre o descripción (Ctrl + K)...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                cubit.clearSearch();
                              },
                            )
                          : (!isMobile
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildKbdBadge(AppShortcutLabels.search),
                                    ],
                                  ),
                                )
                              : null),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Botón de refresco
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Actualizar lista',
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                onPressed: () => cubit.loadBrands(forceRefresh: true),
              ),

              if (!isMobile) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showBrandForm(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Nueva Marca',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _buildKbdBadge(AppShortcutLabels.newRecord, isDark: true),
                    ],
                  ),
                ),
              ],
            ],
          ),

          if (!isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatPill(
                  icon: Icons.branding_watermark_outlined,
                  label: '$totalCount marcas registradas',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _buildStatPill(
                  icon: Icons.check_circle_outline_rounded,
                  label: '$activeCount activas',
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                _buildStatPill(
                  icon: Icons.pause_circle_outline_rounded,
                  label: '${totalCount - activeCount} inactivas',
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Body / Content ───────────────────────────────────────────────────────
  Widget _buildBody(
    BuildContext context,
    BrandsState state,
    bool isMobile,
  ) {
    if (state.viewState == ViewState.loading && state.brands.isEmpty) {
      return const BrandsSkeleton();
    }

    if (state.viewState == ViewState.error && state.brands.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'No se pudieron cargar las marcas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                state.errorMessage ?? 'Ocurrió un error inesperado al conectar.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.read<BrandsCubit>().loadBrands(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.brands.isEmpty) {
      return _buildEmptyState(context, state.searchQuery.isNotEmpty);
    }

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100 ? 3 : (width >= 650 ? 2 : 1);

    return RefreshIndicator(
      onRefresh: () => context.read<BrandsCubit>().loadBrands(forceRefresh: true),
      child: GridView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24,
          isMobile ? 16 : 20,
          isMobile ? 16 : 24,
          isMobile ? 88 : 24,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisExtent: 110,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: state.brands.length,
        itemBuilder: (context, index) {
          final brand = state.brands[index];
          return _buildBrandCard(context, brand);
        },
      ),
    );
  }

  // ── Tarjeta individual de Marca ──────────────────────────────────────────
  Widget _buildBrandCard(BuildContext context, BrandEntity brand) {
    final cubit = context.read<BrandsCubit>();
    final hasLogo = brand.logoUrl != null && brand.logoUrl!.trim().isNotEmpty;
    final productsCount = brand.productsCount ?? 0;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: brand.isActive ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showBrandForm(brand),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo o Avatar de Marca
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasLogo
                    ? CachedNetworkImage(
                        imageUrl: brand.logoUrl!,
                        fit: BoxFit.contain,
                        placeholder: (ctx, url) => const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 1.8),
                          ),
                        ),
                        errorWidget: (ctx, url, err) => _buildInitialAvatar(brand.name),
                      )
                    : _buildInitialAvatar(brand.name),
              ),

              const SizedBox(width: 14),

              // Nombre, notas y conteo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            brand.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: brand.isActive ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: brand.isActive ? AppColors.successLight : AppColors.slateLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            brand.isActive ? 'ACTIVA' : 'INACTIVA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: brand.isActive ? AppColors.success : AppColors.slate,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      brand.description != null && brand.description!.isNotEmpty
                          ? brand.description!
                          : (brand.website != null && brand.website!.isNotEmpty
                              ? brand.website!
                              : 'Sin descripción'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$productsCount producto${productsCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Acciones: Toggle Switch y Menú
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Switch(
                    value: brand.isActive,
                    activeThumbColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) => _handleToggleStatus(brand, val, cubit),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.textSecondary),
                        tooltip: 'Editar marca',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showBrandForm(brand),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.danger),
                        tooltip: 'Eliminar marca',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDeleteBrand(brand, cubit),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialAvatar(String name) {
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'M';
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
        ),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, bool isSearching) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.branding_watermark_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isSearching
                  ? 'No se encontraron marcas'
                  : 'Aún no has registrado ninguna marca',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Intenta con otro término de búsqueda o limpia el filtro.'
                  : 'Agrega marcas para asociarlas a tus productos y mejorar la búsqueda en el catálogo.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (isSearching) {
                  _searchCtrl.clear();
                  context.read<BrandsCubit>().clearSearch();
                } else {
                  _showBrandForm();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(isSearching ? Icons.clear_rounded : Icons.add_rounded, size: 18),
              label: Text(isSearching ? 'Limpiar búsqueda' : 'Registrar Primera Marca'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFab() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isFabExtended,
      builder: (context, extended, child) {
        return FloatingActionButton.extended(
          onPressed: () => _showBrandForm(),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: AnimatedCrossFade(
            firstChild: const Text(
              'Nueva Marca',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: extended ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        );
      },
    );
  }

  static Widget _buildKbdBadge(String text, {bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}
