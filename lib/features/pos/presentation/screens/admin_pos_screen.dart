import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_header.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_category_chips.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_grid_view.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_add_to_cart_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/desktop_pos_panel.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_processing_overlay.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_sidebar_rail.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_sales_view.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/all_cash_shifts_screen.dart';

extension ProductToCartExtension on ProductEntity {
  CartItemEntity toCartItem() {
    return CartItemEntity(
      productId: id,
      productName: name,
      cartKey: id,
      quantity: 1,
      unitPrice: displaySalePrice ?? 0.0,
      unitCost: defaultVariant?.unitCost ?? 0.0,
      availableStock: stockControl ? totalStock : 999999,
      usesBatches: false,
      wholesalePrice: defaultVariant?.wholesalePrice,
      imageUrl: primaryImageUrl,
      isSelected: true,
    );
  }
}

class AdminPosScreen extends StatefulWidget {
  const AdminPosScreen({super.key});

  @override
  State<AdminPosScreen> createState() => _AdminPosScreenState();
}

class _AdminPosScreenState extends State<AdminPosScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _desktopPanelKey = GlobalKey<DesktopPosPanelState>();
  late final AdminCatalogCubit _catalogCubit;
  int _selectedSidebarIndex = 0;
  InventoryCubit? _inventoryCubit;
  bool _isMountedReady = false;
  // Controla si el POS es el branch activo (evita que los shortcuts de hardware
  // intercepten teclas del ERP cuando el POS está en IndexedStack pero invisible).
  bool _isPosActive = false;

  @override
  void initState() {
    super.initState();
    _catalogCubit = context.read<AdminCatalogCubit>();
    // No registramos el handler aquí; se registra en didChangeDependencies
    // cuando confirmamos que la ruta POS es la activa.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isMountedReady) {
        setState(() => _isMountedReady = true);
      }
      if (_catalogCubit.state.filterIsActive != true) {
        _catalogCubit.setFilterIsActive(true);
      }
      if (_searchCtrl.text != _catalogCubit.state.searchTerm) {
        _searchCtrl.text = _catalogCubit.state.searchTerm;
      }

      // [QA CRITICAL FIX] Inicializar POS (almacenes, cuentas y turno activo) en el ciclo de vida raíz.
      // Previene que en mobile la cabecera quede sin almacenes ni turno al no montarse DesktopPosPanel.
      final posCubit = context.read<PosCubit>();
      if (posCubit.state.warehouses.isEmpty || posCubit.state.accounts.isEmpty) {
        posCubit.initPosData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con StatefulShellRoute + IndexedStack, el POS puede estar montado pero
    // oculto (cuando el ERP es el branch activo). Activamos/desactivamos el
    // handler de hardware keyboard según la visibilidad real de la ruta.
    final isNowActive = ModalRoute.of(context)?.isActive ?? false;
    if (_isPosActive != isNowActive) {
      _isPosActive = isNowActive;
      if (_isPosActive) {
        HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey);
      } else {
        HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
      }
    }
  }

  bool _handleGlobalHardwareKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;

    // NOTA: Escape y F2 están en CallbackShortcuts (árbol de widgets).
    // Este handler solo cubre Alt-keys para teclas que deben funcionar
    // incluso cuando un TextField tiene el focus (fuera del árbol de focus).
    try {
      final isAlt = HardwareKeyboard.instance.isAltPressed;
      if (!isAlt) return false;

      // Alt + 1 / Numpad 1 / Alt + V: Tab 0 (Venta)
      if (event.logicalKey == LogicalKeyboardKey.digit1 ||
          event.logicalKey == LogicalKeyboardKey.numpad1 ||
          event.logicalKey == LogicalKeyboardKey.keyV) {
        _onSidebarTabSelected(0);
        return true;
      }

      // Alt + 2 / Numpad 2 / Alt + L / Alt + S: Tab 1 (Lotes/Stock)
      if (event.logicalKey == LogicalKeyboardKey.digit2 ||
          event.logicalKey == LogicalKeyboardKey.numpad2 ||
          event.logicalKey == LogicalKeyboardKey.keyL ||
          event.logicalKey == LogicalKeyboardKey.keyS) {
        _onSidebarTabSelected(1);
        return true;
      }

      // Alt + 3 / Numpad 3 / Alt + H: Tab 2 (Ventas)
      if (event.logicalKey == LogicalKeyboardKey.digit3 ||
          event.logicalKey == LogicalKeyboardKey.numpad3 ||
          event.logicalKey == LogicalKeyboardKey.keyH) {
        _onSidebarTabSelected(2);
        return true;
      }

      // Alt + 4 / Numpad 4 / Alt + T: Tab 3 (Turnos)
      if (event.logicalKey == LogicalKeyboardKey.digit4 ||
          event.logicalKey == LogicalKeyboardKey.numpad4 ||
          event.logicalKey == LogicalKeyboardKey.keyT) {
        _onSidebarTabSelected(3);
        return true;
      }

      // Alt + K / Alt + B: Foco en Buscador del Catálogo POS (solo en Tab 0)
      if (event.logicalKey == LogicalKeyboardKey.keyK ||
          event.logicalKey == LogicalKeyboardKey.keyB) {
        if (_selectedSidebarIndex == 0) {
          _focusSearch();
          return true;
        }
        // Permitir que fluya al Tab activo (Lotes/Stock o Ventas)
        return false;
      }

      // Alt + I: Alternar modo de búsqueda Producto vs Ingrediente Activo (solo en Tab 0)
      if (event.logicalKey == LogicalKeyboardKey.keyI) {
        if (_selectedSidebarIndex == 0) {
          _catalogCubit.toggleSearchByIngredient(!_catalogCubit.state.searchByIngredient);
          return true;
        }
        return false;
      }

      // Alt + C: Cobrar en Desktop (solo en Tab 0)
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        if (_selectedSidebarIndex == 0) {
          _desktopPanelKey.currentState?.triggerCheckout();
          return true;
        }
        return false;
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  void _onSearchChanged(String val) {
    _catalogCubit.submitSearch(val, force: true);
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
    _searchCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchCtrl.text.length,
    );
  }

  void _onSidebarTabSelected(int index) {
    if (index == 1 && _inventoryCubit == null) {
      _inventoryCubit = sl<InventoryCubit>()..initStockTab();
    }
    setState(() => _selectedSidebarIndex = index);
  }

  Future<void> _onExitPos() async {
    final cart = context.read<CartCubit>();
    final hasItems = cart.state.items.isNotEmpty;

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              hasItems ? Icons.warning_amber_rounded : Icons.logout_rounded,
              color: hasItems ? AppColors.warning : AppColors.primary,
            ),
            const SizedBox(width: 8),
            const Text('¿Salir de Caja POS?'),
          ],
        ),
        content: Text(
          hasItems
              ? 'Tienes productos agregados en la caja. Si sales al panel administrativo, la venta actual continuará en tu carrito para cuando regreses.\n\n¿Deseas volver al panel de administración ERP?'
              : '¿Estás seguro de que deseas salir del Punto de Venta y regresar al panel de administración ERP?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Quedarme en Caja'),
          ),
          () {
            bool isExiting = false;
            return StatefulBuilder(
              builder: (ctx, setBtnState) {
                return FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF142B1A),
                  ),
                  onPressed: isExiting
                      ? null
                      : () async {
                          setBtnState(() => isExiting = true);
                          await Future.delayed(const Duration(milliseconds: 60));
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx, true);
                          }
                        },
                  child: isExiting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salir al ERP'),
                );
              },
            );
          }(),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      context.go('/');
    }
  }

  @override
  void dispose() {
    // Solo desregistrar si el handler fue registrado (primera visita activa).
    if (_isPosActive) {
      HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    }
    _inventoryCubit?.close();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _irAVenta(ProductEntity product) async {
    if (product.productVariants.isEmpty && !product.usesBatches) {
      final cart = context.read<CartCubit>();
      cart.addItem(product.toCartItem());
      return;
    }

    PosAddToCartSheet.show(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Foco de Búsqueda (Alt+K, Alt+B)
        const SingleActivator(LogicalKeyboardKey.keyK, alt: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyB, alt: true): _focusSearch,

        // Navegación Sidebar: Venta (Alt+1 / Alt+V / Numpad 1)
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () => _onSidebarTabSelected(0),
        const SingleActivator(LogicalKeyboardKey.numpad1, alt: true): () => _onSidebarTabSelected(0),
        const SingleActivator(LogicalKeyboardKey.keyV, alt: true): () => _onSidebarTabSelected(0),

        // Navegación Sidebar: Lotes / Stock (Alt+2 / Alt+L / Alt+S / Numpad 2)
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.numpad2, alt: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.keyL, alt: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.keyS, alt: true): () => _onSidebarTabSelected(1),

        // Navegación Sidebar: Ventas / Historial (Alt+3 / Alt+H / Numpad 3)
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () => _onSidebarTabSelected(2),
        const SingleActivator(LogicalKeyboardKey.numpad3, alt: true): () => _onSidebarTabSelected(2),
        const SingleActivator(LogicalKeyboardKey.keyH, alt: true): () => _onSidebarTabSelected(2),

        // Navegación Sidebar: Turnos de Caja (Alt+4 / Alt+T / Numpad 4)
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () => _onSidebarTabSelected(3),
        const SingleActivator(LogicalKeyboardKey.numpad4, alt: true): () => _onSidebarTabSelected(3),
        const SingleActivator(LogicalKeyboardKey.keyT, alt: true): () => _onSidebarTabSelected(3),

        // Alternar modo de búsqueda Producto vs Ingrediente Activo (Alt+I)
        const SingleActivator(LogicalKeyboardKey.keyI, alt: true): () {
          _catalogCubit.toggleSearchByIngredient(!_catalogCubit.state.searchByIngredient);
        },

        // Cobrar Inmediato en Desktop (F2 o Alt+C)
        const SingleActivator(LogicalKeyboardKey.f2): () {
          _desktopPanelKey.currentState?.triggerCheckout();
        },
        const SingleActivator(LogicalKeyboardKey.keyC, alt: true): () {
          _desktopPanelKey.currentState?.triggerCheckout();
        },

        // Escape solo desenfoca el buscador en Tab 0 (sin salir del ERP)
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
        },
      },
      child: BlocListener<CartCubit, CartState>(
        listenWhen:
            (previous, current) =>
                (current.errorMessage != null &&
                    current.errorMessage != previous.errorMessage) ||
                (current.items.length > previous.items.length),
        listener: (context, state) {
          if (state.errorMessage != null) {
            AppSnackbar.show(
              context,
              message: state.errorMessage!,
              type: SnackbarType.warning,
            );
          } else if (state.items.isNotEmpty) {
            // Un item ha sido agregado exitosamente: feedback táctil sin saturar con SnackBars
            HapticFeedback.lightImpact();
          }
        },
        child: FocusScope(
          autofocus: true,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            bottomNavigationBar: isDesktop
                ? null
                : NavigationBar(
                    selectedIndex: _selectedSidebarIndex,
                    onDestinationSelected: _onSidebarTabSelected,
                    backgroundColor: Colors.white,
                    elevation: 8,
                    indicatorColor: const Color(0xFFD4E157).withValues(alpha: 0.25),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.point_of_sale_outlined),
                        selectedIcon: Icon(Icons.point_of_sale, color: Color(0xFF1B4D3E)),
                        label: 'Venta',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2, color: Color(0xFF1B4D3E)),
                        label: 'Lotes/Stock',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF1B4D3E)),
                        label: 'Ventas',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(Icons.account_balance_wallet, color: Color(0xFF1B4D3E)),
                        label: 'Turnos',
                      ),
                    ],
                  ),
            body: Builder(
              builder: (context) {
                if (!_isMountedReady) {
                  return const PosDesktopSkeleton();
                }

                Widget catalogContent = Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          BlocSelector<AdminCatalogCubit, AdminCatalogState, bool>(
                            selector: (state) => state.searchByIngredient,
                            builder: (context, searchByIngredient) {
                              return PosHeader(
                                searchController: _searchCtrl,
                                searchFocusNode: _searchFocusNode,
                                onSearchChanged: _onSearchChanged,
                                searchByIngredient: searchByIngredient,
                                onToggleIngredientSearch:
                                    context.read<AdminCatalogCubit>().toggleSearchByIngredient,
                                onBack: _onExitPos,
                              );
                            },
                          ),
                        const SizedBox(height: 12),
                        BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                          buildWhen: (prev, current) =>
                              prev.categories != current.categories ||
                              prev.selectedCategoryId != current.selectedCategoryId ||
                              prev.brands != current.brands ||
                              prev.selectedBrandId != current.selectedBrandId ||
                              prev.filterIsActive != current.filterIsActive ||
                              prev.sortOption != current.sortOption ||
                              prev.stockFilter != current.stockFilter,
                          builder: (context, state) {
                            if (state.categories.isEmpty && state.brands.isEmpty) return const SizedBox.shrink();
                            return CategoryChips(
                              categories: state.categories,
                              selectedCategoryId: state.selectedCategoryId,
                              onSelected: context.read<AdminCatalogCubit>().setCategory,
                              brands: state.brands,
                              selectedBrandId: state.selectedBrandId,
                              onBrandSelected: context.read<AdminCatalogCubit>().setBrand,
                              filterIsActive: state.filterIsActive,
                              onStatusSelected: context.read<AdminCatalogCubit>().setFilterIsActive,
                              sortOption: state.sortOption,
                              onSortSelected: context.read<AdminCatalogCubit>().setSortOption,
                              stockFilter: state.stockFilter,
                              onStockFilterSelected: context.read<AdminCatalogCubit>().setStockFilter,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                      buildWhen: (prev, current) =>
                          prev.products != current.products ||
                          prev.catalogState != current.catalogState ||
                          prev.errorMessage != current.errorMessage,
                      builder: (context, state) =>
                          _buildMainContent(context, context.read<AdminCatalogCubit>(), state),
                    ),
                  ),
                  BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                    buildWhen: (prev, current) =>
                        prev.currentPage != current.currentPage ||
                        prev.totalPages != current.totalPages ||
                        prev.products != current.products,
                    builder: (context, state) {
                      if (state.products.isNotEmpty && state.totalPages > 1) {
                        return Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: AdminPageBlocks(
                              currentPage: state.currentPage,
                              totalPages: state.totalPages,
                              onPageChanged: context.read<AdminCatalogCubit>().setPage,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              );

              Widget activeView;
              if (_selectedSidebarIndex == 1) {
                _inventoryCubit ??= sl<InventoryCubit>()..initStockTab();
                activeView = Expanded(
                  child: BlocProvider.value(
                    value: _inventoryCubit!,
                    child: const InventoryScreen(isEmbedded: true),
                  ),
                );
              } else if (_selectedSidebarIndex == 2) {
                activeView = Expanded(
                  child: PosSalesView(
                    onOpenCashShifts: () => setState(() => _selectedSidebarIndex = 3),
                  ),
                );
              } else if (_selectedSidebarIndex == 3) {
                activeView = Expanded(
                  child: AllCashShiftsScreen(
                    isEmbedded: true,
                    onBack: () => setState(() => _selectedSidebarIndex = 2),
                  ),
                );
              } else {
                activeView = Expanded(
                  child: Row(
                    children: [
                      Expanded(flex: 6, child: catalogContent),
                      if (isDesktop)
                        Container(
                          width:
                              MediaQuery.of(context).size.width >= 1300
                                  ? 440
                                  : MediaQuery.of(context).size.width >= 1000
                                  ? 400
                                  : 360,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              left: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 24,
                                spreadRadius: -4,
                                offset: const Offset(-8, 0),
                              ),
                            ],
                          ),
                          child: DesktopPosPanel(
                            key: _desktopPanelKey,
                            onSaleCompleted: (soldQuantities) {
                              context
                                  .read<AdminCatalogCubit>()
                                  .decrementStockLocal(soldQuantities);
                            },
                          ),
                        ),
                    ],
                  ),
                );
              }

              return Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isDesktop)
                        PosSidebarRail(
                          selectedIndex: _selectedSidebarIndex,
                          onDestinationSelected: _onSidebarTabSelected,
                          onExitPos: _onExitPos,
                        ),
                      activeView,
                    ],
                  ),
                  // Overlay global de procesamiento: cubre toda la pantalla
                  BlocSelector<PosCubit, PosState, bool>(
                    selector: (s) => s.status == PosStatus.loading,
                    builder:
                        (ctx, isLoading) =>
                            isLoading
                                ? const PosProcessingOverlay(isVisible: true)
                                : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
          floatingActionButton:
              isDesktop || _selectedSidebarIndex != 0
                  ? null
                  : BlocBuilder<CartCubit, CartState>(
                      builder: (context, cartState) {
                        final hasItems = cartState.items.isNotEmpty;
                        final itemCount = cartState.items.values.fold<int>(
                          0,
                          (sum, item) => sum + item.quantity,
                        );
                        final totalAmount = cartState.totalAmount;

                        return FloatingActionButton.extended(
                          onPressed: () async {
                            final sold = await context.push<Map<String, int>>('/pos-checkout');
                            if (sold != null && context.mounted) {
                              context.read<AdminCatalogCubit>().decrementStockLocal(sold);
                            }
                          },
                          backgroundColor:
                              hasItems
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                          foregroundColor: Colors.white,
                          icon: Icon(
                            hasItems
                                ? Icons.shopping_bag_rounded
                                : Icons.shopping_cart_checkout_rounded,
                            size: 20,
                          ),
                          label: Text(
                            hasItems
                                ? 'Ir a Caja ($itemCount) • S/ ${totalAmount.toStringAsFixed(2)}'
                                : 'Ir a Caja',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AdminCatalogCubit cubit,
    AdminCatalogState state,
  ) {
    if ((state.catalogState == ViewState.loading) && state.products.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:
              MediaQuery.of(context).size.width >= 1200
                  ? 6
                  : MediaQuery.of(context).size.width >= 800
                      ? 4
                      : MediaQuery.of(context).size.width >= 600
                          ? 3
                          : 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          return const AppShimmer(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 16,
          );
        },
      );
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return Center(child: CatalogErrorState(message: state.errorMessage!));
    }

    if (state.products.isEmpty && !(state.catalogState == ViewState.loading)) {
      return Center(
        child: CatalogEmptyState(
          searchByIngredient: state.searchByIngredient,
          searchTerm: state.searchTerm,
        ),
      );
    }

    return CatalogGridScrollView(
      products: state.products,
      pageSize: AdminCatalogState.pageSize,
      currentPage: state.currentPage,
      totalCount: state.totalCount,
      onPageChanged: cubit.setPage,
      onSale: _irAVenta,
      onToggleActive:
          (p) => Future.value(), // No permitimos editar en modo caja
      searchByIngredient: state.searchByIngredient,
      matchedIngredients: state.matchedIngredients,
      bottomPadding: MediaQuery.of(context).size.width >= 800 ? 24 : 100,
      isPosMode: true,
      onEdit: (product) {}, // No permitimos editar en modo caja
    );
  }
}

/// Esqueleto Shimmer ultra-ligero montado en el Frame 0 (<5ms)
/// para erradicar el congelamiento y garantizar 60 FPS estables al abrir el POS.
class PosDesktopSkeleton extends StatelessWidget {
  const PosDesktopSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDesktop)
          const PosSidebarRail(
            selectedIndex: 0,
            onDestinationSelected: _dummyIndex,
            onExitPos: _dummyVoid,
          ),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: const Column(
                  children: [
                    AppShimmer(
                      width: double.infinity,
                      height: 44,
                      borderRadius: 12,
                    ),
                    SizedBox(height: 12),
                    AppShimmer(
                      width: double.infinity,
                      height: 36,
                      borderRadius: 10,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.of(context).size.width >= 1200
                            ? 6
                            : MediaQuery.of(context).size.width >= 800
                            ? 4
                            : 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: 8,
                  itemBuilder:
                      (_, _) => const AppShimmer(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 16,
                      ),
                ),
              ),
            ],
          ),
        ),
        if (isDesktop)
          Container(
            width:
                MediaQuery.of(context).size.width >= 1300
                    ? 440
                    : MediaQuery.of(context).size.width >= 1000
                    ? 400
                    : 360,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmer(width: 120, height: 28, borderRadius: 8),
                SizedBox(height: 16),
                AppShimmer(
                  width: double.infinity,
                  height: 50,
                  borderRadius: 12,
                ),
                SizedBox(height: 16),
                AppShimmer(
                  width: double.infinity,
                  height: 80,
                  borderRadius: 12,
                ),
                Spacer(),
                AppShimmer(
                  width: double.infinity,
                  height: 120,
                  borderRadius: 12,
                ),
                SizedBox(height: 16),
                AppShimmer(
                  width: double.infinity,
                  height: 52,
                  borderRadius: 14,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static void _dummyIndex(int _) {}
  static void _dummyVoid() {}
}
