import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/supplier_form_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/suppliers_content_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/suppliers_kpi_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/suppliers_pagination_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/suppliers_toolbar_section.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  final ValueNotifier<bool> _isTableViewNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String?> _selectedSupplierIdNotifier =
      ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    final initialQuery = context.read<SuppliersCubit>().state.searchQuery;
    if (initialQuery.isNotEmpty) {
      _searchCtrl.text = initialQuery;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    _isTableViewNotifier.dispose();
    _selectedSupplierIdNotifier.dispose();
    super.dispose();
  }

  bool get _isInputFieldFocused {
    if (_searchFocusNode.hasFocus) return true;
    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusContext = primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null ||
        focusContext.findAncestorStateOfType<EditableTextState>() != null;
  }

  KeyEventResult _handleKeyShortcuts(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final cubit = context.read<SuppliersCubit>();
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyN) {
      _openSupplierModal();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyR) {
      cubit.loadSuppliers(forceRefresh: true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyV) {
      _isTableViewNotifier.value = !_isTableViewNotifier.value;
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_selectedSupplierIdNotifier.value != null) {
        _selectedSupplierIdNotifier.value = null;
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        cubit.setSearchQuery('');
      }
      _searchFocusNode.unfocus();
      _screenFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    final suppliers = cubit.state.suppliers;
    if (suppliers.isNotEmpty) {
      final selectedId = _selectedSupplierIdNotifier.value;
      final currentIndex =
          selectedId != null
              ? suppliers.indexWhere((s) => s.id == selectedId)
              : -1;

      if (key == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, suppliers.length - 1);
        _selectedSupplierIdNotifier.value = suppliers[nextIndex].id;
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, suppliers.length - 1);
        _selectedSupplierIdNotifier.value = suppliers[prevIndex].id;
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final supplier =
            currentIndex >= 0 ? suppliers[currentIndex] : suppliers.first;
        _openSupplierModal(supplier);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _openSupplierModal([SupplierEntity? supplier]) {
    if (supplier != null) {
      _selectedSupplierIdNotifier.value = supplier.id;
    }
    final cubit = context.read<SuppliersCubit>();
    AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 540.0,
      barrierLabel: 'Cerrar proveedor',
      builder:
          (ctx) => BlocProvider.value(
            value: cubit,
            child: SupplierFormSheet(
              supplierToEdit: supplier,
              isDialog: AdaptiveDetailSheet.isSideSheet(ctx),
              onSaved: () {},
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 640;
    final isDesktop = width >= 1024;
    final cubit = context.read<SuppliersCubit>();

    return Focus(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyShortcuts,
      child: BlocListener<SuppliersCubit, SuppliersState>(
        listenWhen:
            (prev, curr) =>
                prev.mutationStatus != curr.mutationStatus &&
                (curr.mutationStatus == SupplierMutationStatus.success ||
                    curr.mutationStatus == SupplierMutationStatus.failure),
        listener: (context, state) {
          final msg = state.mutationMessage;
          if (msg != null && msg.isNotEmpty) {
            AppSnackbar.show(
              context,
              message: msg,
              type:
                  state.mutationStatus == SupplierMutationStatus.success
                      ? SnackbarType.success
                      : SnackbarType.error,
            );
          }
          cubit.clearMutationFeedback();
        },
        child: AdminLayout(
          title: 'Directorio de Proveedores',
          floatingActionButton:
              !isDesktop
                  ? FloatingActionButton.extended(
                    heroTag: 'add_supplier_fab',
                    backgroundColor: AppColors.primary,
                    elevation: 4,
                    icon: const Icon(
                      Icons.add_business_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Nuevo Proveedor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () => _openSupplierModal(),
                  )
                  : null,
          body: RefreshIndicator(
            onRefresh: () => cubit.loadSuppliers(forceRefresh: true),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: AdminPageHeader(
                    title: 'Directorio de Proveedores',
                    subtitle:
                        'Gestiona tus proveedores, su información y datos de contacto',
                    isDesktop: isDesktop,
                    actions: [
                      AdminHeaderButton.primary(
                        label: 'Nuevo Proveedor',
                        icon: Icons.add_business_rounded,
                        tooltip: 'Nuevo proveedor (Atajo: N)',
                        onPressed: () => _openSupplierModal(),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: SuppliersKpiSection(isWide: isWide)),
                SliverToBoxAdapter(
                  child: SuppliersToolbarSection(
                    isDesktop: isDesktop,
                    searchController: _searchCtrl,
                    searchFocusNode: _searchFocusNode,
                    isTableViewNotifier: _isTableViewNotifier,
                  ),
                ),
                SuppliersContentSection(
                  isWide: isWide,
                  isTableViewNotifier: _isTableViewNotifier,
                  selectedSupplierIdNotifier: _selectedSupplierIdNotifier,
                  onEdit: _openSupplierModal,
                  onToggleStatus: cubit.toggleSupplierStatus,
                  onBulkToggleStatus: cubit.bulkToggleSuppliersStatus,
                  onCreateSupplier: () => _openSupplierModal(),
                  onClearFilters: () {
                    _searchCtrl.clear();
                    cubit.clearFilters();
                  },
                ),
                SuppliersPaginationSection(
                  onPageChanged: (page) {
                    cubit.setPage(page);
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
