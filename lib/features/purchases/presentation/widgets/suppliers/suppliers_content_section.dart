import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/supplier_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/suppliers_table_view.dart';

class SuppliersContentSection extends StatelessWidget {
  final bool isWide;
  final ValueNotifier<bool> isTableViewNotifier;
  final ValueNotifier<String?> selectedSupplierIdNotifier;
  final ValueChanged<SupplierEntity> onEdit;
  final ValueChanged<SupplierEntity> onToggleStatus;
  final ValueChanged<List<SupplierEntity>> onBulkToggleStatus;
  final VoidCallback onCreateSupplier;
  final VoidCallback onClearFilters;

  const SuppliersContentSection({
    super.key,
    required this.isWide,
    required this.isTableViewNotifier,
    required this.selectedSupplierIdNotifier,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onBulkToggleStatus,
    required this.onCreateSupplier,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      SuppliersCubit,
      SuppliersState,
      ({
        SuppliersLoadStatus status,
        bool isColdLoading,
        List<SupplierEntity> suppliers,
        Failure? loadFailure,
        String searchQuery,
        bool? filterIsActive,
      })
    >(
      selector:
          (state) => (
            status: state.status,
            isColdLoading: state.isColdLoading,
            suppliers: state.suppliers,
            loadFailure: state.loadFailure,
            searchQuery: state.searchQuery,
            filterIsActive: state.filterIsActive,
          ),
      builder: (context, vm) {
        final cubit = context.read<SuppliersCubit>();

        return ValueListenableBuilder<bool>(
          valueListenable: isTableViewNotifier,
          builder: (context, isTableView, _) {
            if (vm.isColdLoading) {
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _SingleTickerSuppliersSkeleton(
                    isTableView: isWide && isTableView,
                    isWide: isWide,
                  ),
                ),
              );
            }

            // ErrorCold: sin datos cacheados — nunca confundir con lista vacía
            if (vm.status == SuppliersLoadStatus.error &&
                vm.suppliers.isEmpty) {
              final failure = vm.loadFailure;
              final isNetwork = failure is NetworkFailure;
              final isUnauth = failure is UnauthorizedFailure;

              return SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon:
                      isNetwork
                          ? Icons.wifi_off_rounded
                          : (isUnauth
                              ? Icons.lock_outline_rounded
                              : Icons.error_outline_rounded),
                  color: AppColors.danger,
                  title:
                      isNetwork
                          ? 'Sin conexión a internet'
                          : (isUnauth
                              ? 'Acceso restringido'
                              : 'Error al cargar proveedores'),
                  message:
                      failure?.message ??
                      'No pudimos obtener el directorio de proveedores.',
                  action: ElevatedButton.icon(
                    onPressed: () => cubit.loadSuppliers(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ),
              );
            }

            if (vm.suppliers.isEmpty) {
              final hasFilters =
                  vm.searchQuery.isNotEmpty || vm.filterIsActive != null;
              return SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.storefront_rounded,
                  title:
                      hasFilters
                          ? 'No se encontraron resultados'
                          : 'No hay proveedores registrados',
                  message:
                      hasFilters
                          ? 'Intenta con otro término o limpia los filtros.'
                          : 'Registra un nuevo proveedor para comenzar.',
                  action:
                      hasFilters
                          ? OutlinedButton.icon(
                            onPressed: onClearFilters,
                            icon: const Icon(Icons.clear_all_rounded),
                            label: const Text('Limpiar filtros'),
                          )
                          : ElevatedButton.icon(
                            onPressed: onCreateSupplier,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add_business_rounded),
                            label: const Text('Nuevo Proveedor'),
                          ),
                ),
              );
            }

            final contentSliver =
                (isWide && isTableView)
                    ? SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: SuppliersTableView(
                            suppliers: vm.suppliers,
                            onEdit: onEdit,
                            onToggleStatus: onToggleStatus,
                            onBulkToggleStatus: onBulkToggleStatus,
                          ),
                        ),
                      ),
                    )
                    : _SuppliersCardsSliver(
                      suppliers: vm.suppliers,
                      isWide: isWide,
                      selectedSupplierIdNotifier: selectedSupplierIdNotifier,
                      onEdit: onEdit,
                      onToggleStatus: onToggleStatus,
                    );

            if (vm.loadFailure == null) return contentSliver;

            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: _DegradedErrorBanner(
                    message: vm.loadFailure!.message,
                    onRetry: () => cubit.loadSuppliers(forceRefresh: true),
                  ),
                ),
                contentSliver,
              ],
            );
          },
        );
      },
    );
  }
}

class _SuppliersCardsSliver extends StatelessWidget {
  final List<SupplierEntity> suppliers;
  final bool isWide;
  final ValueNotifier<String?> selectedSupplierIdNotifier;
  final ValueChanged<SupplierEntity> onEdit;
  final ValueChanged<SupplierEntity> onToggleStatus;

  const _SuppliersCardsSliver({
    required this.suppliers,
    required this.isWide,
    required this.selectedSupplierIdNotifier,
    required this.onEdit,
    required this.onToggleStatus,
  });

  Widget _buildCard(BuildContext context, int index) {
    final supplier = suppliers[index];
    return ValueListenableBuilder<String?>(
      valueListenable: selectedSupplierIdNotifier,
      builder: (context, selectedId, _) {
        return RepaintBoundary(
          child: SupplierCard(
            supplier: supplier,
            isSelected: selectedId == supplier.id,
            onEdit: () => onEdit(supplier),
            onToggleStatus: () => onToggleStatus(supplier),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 440,
            mainAxisExtent: 180,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            _buildCard,
            childCount: suppliers.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCard(context, index),
          ),
          childCount: suppliers.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
        ),
      ),
    );
  }
}

class _DegradedErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DegradedErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppColors.warningDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mostrando directorio en caché · $message',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warningDark,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.warningDark,
            ),
            child: const Text(
              'Reintentar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleTickerSuppliersSkeleton extends StatefulWidget {
  final bool isTableView;
  final bool isWide;

  const _SingleTickerSuppliersSkeleton({
    required this.isTableView,
    required this.isWide,
  });

  @override
  State<_SingleTickerSuppliersSkeleton> createState() =>
      _SingleTickerSuppliersSkeletonState();
}

class _SingleTickerSuppliersSkeletonState
    extends State<_SingleTickerSuppliersSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color =
            Color.lerp(
              const Color(0xFFE2E8F0),
              const Color(0xFFF1F5F9),
              _controller.value,
            )!;

        if (widget.isTableView) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(
                6,
                (i) => Container(
                  height: 44,
                  margin: EdgeInsets.only(bottom: i == 5 ? 0 : 10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          );
        }

        if (widget.isWide) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 440,
              mainAxisExtent: 180,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 6,
            itemBuilder:
                (_, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
          );
        }

        return Column(
          children: List.generate(
            5,
            (i) => Container(
              height: 160,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}
