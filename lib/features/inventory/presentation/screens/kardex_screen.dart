import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex_state.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_skeleton.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'dart:async';

class KardexScreen extends StatefulWidget {
  const KardexScreen({super.key});

  @override
  State<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  final _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KardexCubit>().loadMovements();
    });
    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _isFabExtended.value) {
        _isFabExtended.value = false;
      } else if (_scrollController.offset <= 10 && !_isFabExtended.value) {
        _isFabExtended.value = true;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _isFabExtended.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<KardexCubit>().setSearchText(value);
    });
  }

  Future<void> _openExitScreen(BuildContext context) async {
    final result = await context.push('/admin/inventory-exit-form');
    if (result == true && context.mounted) {
      context.read<KardexCubit>().loadMovements();
    }
  }

  Future<void> _openEntryScreen(BuildContext context) async {
    final result = await context.push('/admin/inventory-entry-form');
    if (result == true && context.mounted) {
      context.read<KardexCubit>().loadMovements();
    }
  }

  void _showActionOptionsMobile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Registrar Movimiento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade50,
                      child: Icon(
                        Icons.add_shopping_cart,
                        color: Colors.green.shade700,
                      ),
                    ),
                    title: const Text(
                      'Ingreso de inventario',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Registrar compras o retornos'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openEntryScreen(context);
                    },
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade50,
                      child: Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red.shade700,
                      ),
                    ),
                    title: const Text(
                      'Salida de inventario',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Registrar mermas o retiros manuales'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openExitScreen(context);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildFilterChip(KardexLoaded state, String label, String value) {
    final isSelected = state.typeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => context.read<KardexCubit>().setTypeFilter(value),
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          checkmarkColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
          labelStyle: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KardexCubit, KardexState>(
      listener: (context, state) {
        if (state is KardexError) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        if (state is KardexInitial ||
            state is KardexLoading && state is! KardexLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final loadedState =
            state is KardexLoaded
                ? state
                : (state is KardexLoading
                    ? context.read<KardexCubit>().state as KardexLoaded?
                    : null);

        if (loadedState == null && state is KardexError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        final currentState =
            loadedState ??
            const KardexLoaded(
              movements: [],
              typeFilter: 'ALL',
              searchText: '',
              currentPage: 0,
              totalCount: 0,
              totalPages: 1,
              isExporting: false,
            );

        final isLoading = state is KardexLoading;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 800;

            return AdminLayout(
              title: 'Kardex',
              showBackButton: true,
              body: Column(
                children: [
                  // Acciones principales en Tablet
                  if (isTablet)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _openEntryScreen(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade50,
                              foregroundColor: Colors.green.shade700,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text(
                              'Ingreso',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openExitScreen(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              foregroundColor: Colors.red.shade700,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                            ),
                            label: const Text(
                              'Salida',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh:
                          () async => context.read<KardexCubit>().loadMovements(
                            page: 0,
                          ),
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // --- STICKY HEADER (FILTROS Y BÚSQUEDA) ---
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _StickyKardexFiltersDelegate(
                              child: Container(
                                color: AppColors.background,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SearchField(
                                            controller: _searchCtrl,
                                            hint: 'Buscar producto...',
                                            onChanged: _onSearchChanged,
                                            onClear: () {
                                              _searchCtrl.clear();
                                              context
                                                  .read<KardexCubit>()
                                                  .setSearchText('');
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        DateFilterCalendar(
                                          dateRange:
                                              currentState.startDate != null &&
                                                      currentState.endDate !=
                                                          null
                                                  ? DateTimeRange(
                                                    start:
                                                        currentState.startDate!,
                                                    end: currentState.endDate!,
                                                  )
                                                  : null,
                                          onDateRangeSelected: (picked) {
                                            context
                                                .read<KardexCubit>()
                                                .setDateRange(
                                                  picked.start,
                                                  picked.end,
                                                );
                                          },
                                          onClear: () {
                                            context
                                                .read<KardexCubit>()
                                                .setDateRange(null, null);
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          _buildFilterChip(
                                            currentState,
                                            'Todos',
                                            'ALL',
                                          ),
                                          _buildFilterChip(
                                            currentState,
                                            'Ingresos',
                                            'ENTRY',
                                          ),
                                          _buildFilterChip(
                                            currentState,
                                            'Salidas',
                                            'EXIT',
                                          ),
                                          _buildFilterChip(
                                            currentState,
                                            'Ventas',
                                            'SALE',
                                          ),
                                          _buildFilterChip(
                                            currentState,
                                            'Devoluciones',
                                            'RETURN',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // --- CONTEO ---
                          if (!isLoading && currentState.movements.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  12,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${currentState.totalCount} movimientos encontrados',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // --- LISTADO ---
                          if (isLoading && currentState.movements.isEmpty)
                            const SliverFillRemaining(child: KardexSkeleton())
                          else if (currentState.movements.isEmpty)
                            const SliverFillRemaining(
                              child: AppEmptyState(
                                icon: Icons.history,
                                title: 'No hay movimientos',
                                message:
                                    'Aún no se han registrado ingresos o salidas de inventario con estos filtros.',
                              ),
                            )
                          else
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: ListView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: currentState.movements.length,
                                  itemBuilder: (context, index) {
                                    return KardexCard(
                                      item: currentState.movements[index],
                                      isLast:
                                          index ==
                                          currentState.movements.length - 1,
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                ],
              ),
              bottomNavigationBar:
                  currentState.totalPages > 1 && !isLoading
                      ? Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: AdminPageBlocks(
                            currentPage: currentState.currentPage,
                            totalPages: currentState.totalPages,
                            onPageChanged:
                                (page) =>
                                    context.read<KardexCubit>().changePage(
                                      page,
                                    ),
                          ),
                        ),
                      )
                      : null,
              floatingActionButton:
                  !isTablet
                      ? FloatingActionButton.extended(
                        onPressed: () => _showActionOptionsMobile(context),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.add),
                        label: ValueListenableBuilder<bool>(
                          valueListenable: _isFabExtended,
                          builder: (context, isExtended, _) {
                            return AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child:
                                  isExtended
                                      ? const Text(
                                        'Movimiento',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                      : const SizedBox.shrink(),
                            );
                          },
                        ),
                      )
                      : null,
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DELEGATES Y WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _StickyKardexFiltersDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyKardexFiltersDelegate({required this.child});

  @override
  double get minExtent => 125.0;
  @override
  double get maxExtent => 125.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyKardexFiltersDelegate oldDelegate) {
    return true;
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          suffixIcon:
              controller.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: onClear,
                  )
                  : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
