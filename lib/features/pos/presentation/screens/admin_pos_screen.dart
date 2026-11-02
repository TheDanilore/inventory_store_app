import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/orders_screen.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/admin_pos/pos_catalog_view.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/admin_pos/pos_checkout_fab.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/admin_pos/pos_exit_dialog.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/admin_pos/pos_hardware_keyboard_listener.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_add_to_cart_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/desktop_pos_panel.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_processing_overlay.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/quick_create_customer_dialog.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_sidebar_rail.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/all_cash_shifts_screen.dart';

class AdminPosScreen extends StatefulWidget {
  final String? initialWarehouseId;

  const AdminPosScreen({super.key, this.initialWarehouseId});

  @override
  State<AdminPosScreen> createState() => _AdminPosScreenState();
}

class _AdminPosScreenState extends State<AdminPosScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _desktopPanelKey = GlobalKey<DesktopPosPanelState>();

  late final AdminCatalogCubit _catalogCubit;
  late final PosHardwareKeyHandler _hardwareKeyHandler;

  int _selectedSidebarIndex = 0;
  InventoryCubit? _inventoryCubit;
  OrdersCubit? _ordersCubit;
  bool _visitedTab1 = false;
  bool _visitedTab2 = false;
  bool _visitedTab3 = false;
  bool _isPosActive = false;

  @override
  void initState() {
    super.initState();
    _catalogCubit = context.read<AdminCatalogCubit>();

    _hardwareKeyHandler = PosHardwareKeyHandler(
      getSelectedTab: () => _selectedSidebarIndex,
      onBarcodeScanned: _processScannedBarcode,
      onTabSelected: _onSidebarTabSelected,
      onFocusSearch: _focusSearch,
      onTriggerDraft: () => _desktopPanelKey.currentState?.triggerDraft(),
      onOpenClientSearch:
          () => _desktopPanelKey.currentState?.openClientSearch(),
      onQuickCreateCustomer: _openQuickCreateCustomer,
      onToggleIngredientSearch: () {
        _catalogCubit.toggleSearchByIngredient(
          !_catalogCubit.state.searchByIngredient,
        );
      },
      onRefreshTab: _refreshActiveTab,
      onTriggerCheckout: () => _desktopPanelKey.currentState?.triggerCheckout(),
      onCameraScanner: _openCameraScanner,
      onUnfocusSearch: () {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_catalogCubit.state.filterIsActive != true) {
        _catalogCubit.setFilterIsActive(true);
      }
      if (_searchCtrl.text != _catalogCubit.state.searchTerm) {
        _searchCtrl.text = _catalogCubit.state.searchTerm;
      }

      final posCubit = context.read<PosCubit>();
      final authUser = context.read<AuthCubit>().state.currentUser;
      final targetWarehouseId =
          widget.initialWarehouseId ?? authUser?.warehouseId;

      if (posCubit.state.warehouses.isEmpty ||
          posCubit.state.accounts.isEmpty) {
        posCubit.initPosData(preferredWarehouseId: targetWarehouseId);
      } else if (widget.initialWarehouseId != null &&
          widget.initialWarehouseId != posCubit.state.selectedWarehouseId) {
        posCubit.setWarehouse(widget.initialWarehouseId);
      }

      final appConfigCubit = context.read<AppConfigCubit>();
      if (appConfigCubit.businessInfo == null) {
        appConfigCubit.loadBusinessInfo();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isNowActive = ModalRoute.of(context)?.isActive ?? false;
    if (_isPosActive != isNowActive) {
      _isPosActive = isNowActive;
      if (_isPosActive) {
        _hardwareKeyHandler.attach();
      } else {
        _hardwareKeyHandler.detach();
      }
    }
  }

  @override
  void didUpdateWidget(covariant AdminPosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialWarehouseId != null &&
        widget.initialWarehouseId != oldWidget.initialWarehouseId) {
      final posCubit = context.read<PosCubit>();
      if (posCubit.state.selectedWarehouseId != widget.initialWarehouseId) {
        posCubit.setWarehouse(widget.initialWarehouseId);
      }
    }
  }

  @override
  void dispose() {
    _hardwareKeyHandler.detach();
    _inventoryCubit?.close();
    _ordersCubit?.close();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool get _isCashierOnly {
    final user = context.read<AuthCubit>().state.currentUser;
    return user?.isPosOnly ?? false;
  }

  Future<void> _onExitPos() async {
    await PosExitDialog.handleExit(context, isCashierOnly: _isCashierOnly);
  }

  void _onSidebarTabSelected(int index) {
    if (index == 1) {
      _visitedTab1 = true;
      _inventoryCubit ??= sl<InventoryCubit>()..initStockTab();
    }
    if (index == 2) {
      _visitedTab2 = true;
      _ordersCubit ??= sl<OrdersCubit>();
    }
    if (index == 3) {
      _visitedTab3 = true;
    }
    setState(() {
      _selectedSidebarIndex = index;
    });
  }

  void _refreshActiveTab() {
    switch (_selectedSidebarIndex) {
      case 0:
        _catalogCubit.refreshProducts();
        context.read<PosCubit>().refreshAccountsAndShift();
        break;
      case 1:
        _inventoryCubit?.initStockTab();
        break;
      case 2:
        _ordersCubit?.loadOrders(background: true);
        context.read<PosCubit>().fetchRecentOrders(forceRefresh: true);
        context.read<PosCubit>().fetchDailySalesSummary();
        break;
      case 3:
        context.read<CashShiftsCubit>().fetchShifts();
        break;
    }
    AppSnackbar.show(
      context,
      message: 'Datos actualizados',
      type: SnackbarType.info,
    );
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

  Future<void> _openCameraScanner() async {
    final warehouseId = context.read<PosCubit>().state.selectedWarehouseId;
    final cartCubit = context.read<CartCubit>();
    await PosBarcodeScannerService.openCameraScanner(
      context: context,
      cartCubit: cartCubit,
      warehouseId: warehouseId,
    );
  }

  Future<void> _processScannedBarcode(String code) async {
    final warehouseId = context.read<PosCubit>().state.selectedWarehouseId;
    final cartCubit = context.read<CartCubit>();

    AppFeedbackService.triggerFeedback();

    AppSnackbar.show(
      context,
      message: 'Escaneado: "$code"',
      type: SnackbarType.info,
    );

    final scanResult = await PosBarcodeScannerService.resolveCode(
      code,
      warehouseId: warehouseId,
    );

    if (!mounted) return;

    if (scanResult != null) {
      await PosBarcodeScannerService.addScanResultToCart(
        context: context,
        scanResult: scanResult,
        cartCubit: cartCubit,
        warehouseId: warehouseId,
      );
    } else {
      AppSnackbar.show(
        context,
        message: 'No se encontró producto con el código "$code"',
        type: SnackbarType.warning,
      );
    }
  }

  Future<void> _openQuickCreateCustomer() async {
    final customer = await QuickCreateCustomerDialog.show(context);
    if (customer != null && mounted) {
      final posCubit = context.read<PosCubit>();
      posCubit.setClient(
        customer.id,
        customer.fullName,
        customer.walletBalance.toInt(),
      );
      posCubit.fetchClientCredit(customer.id);
      AppSnackbar.show(
        context,
        message: 'Cliente "${customer.fullName}" seleccionado',
        type: SnackbarType.success,
      );
    }
  }

  void _irAVenta(ProductEntity product) {
    final warehouseId = context.read<PosCubit>().state.selectedWarehouseId;

    if (product.productVariants.length <= 1) {
      final targetVariant = product.defaultVariant;
      final variantId = targetVariant?.id;
      final cartKey = variantId ?? product.id;
      final cart = context.read<CartCubit>();

      if (product.stockControl) {
        if (warehouseId == null || warehouseId.isEmpty) {
          AppSnackbar.show(
            context,
            message: 'Selecciona un almacén antes de agregar productos a caja.',
            type: SnackbarType.warning,
          );
          return;
        }

        int warehouseStock = product.getStockForWarehouse(
          warehouseId,
          variantId: variantId,
        );

        if (warehouseStock <= 0 &&
            product.warehouseStockBatches.isEmpty &&
            product.totalStock > 0) {
          warehouseStock = product.totalStock;
        }

        if (warehouseStock <= 0) {
          AppSnackbar.show(
            context,
            message:
                '${product.name} no tiene stock disponible en este almacén.',
            type: SnackbarType.warning,
          );
          return;
        }

        final existingItem = cart.state.items[cartKey];
        final inCartQty = existingItem?.quantity ?? 0;
        if (inCartQty + 1 > warehouseStock) {
          AppSnackbar.show(
            context,
            message:
                'Stock insuficiente en este almacén (Disponibles: $warehouseStock${inCartQty > 0 ? ', ya en caja: $inCartQty' : ''}).',
            type: SnackbarType.warning,
          );
          return;
        }

        cart.addItem(product.toCartItem(warehouseStock: warehouseStock));
      } else {
        cart.addItem(product.toCartItem());
      }

      AppFeedbackService.triggerFeedback();
      return;
    }

    PosAddToCartSheet.show(context, product, warehouseId: warehouseId);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return AppPopScope(
      onCustomBack: _onExitPos,
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
            AppFeedbackService.lightImpact();
          }
        },
        child: FocusScope(
          autofocus: true,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            bottomNavigationBar:
                isDesktop
                    ? null
                    : NavigationBar(
                      selectedIndex: _selectedSidebarIndex,
                      onDestinationSelected: _onSidebarTabSelected,
                      backgroundColor: Colors.white,
                      elevation: 8,
                      indicatorColor: AppColors.teal.withValues(alpha: 0.15),
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.point_of_sale_outlined),
                          selectedIcon: Icon(
                            Icons.point_of_sale,
                            color: AppColors.tealDark,
                          ),
                          label: 'Venta',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.inventory_2_outlined),
                          selectedIcon: Icon(
                            Icons.inventory_2,
                            color: AppColors.tealDark,
                          ),
                          label: 'Lotes/Stock',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(
                            Icons.receipt_long,
                            color: AppColors.tealDark,
                          ),
                          label: 'Ventas',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.account_balance_wallet_outlined),
                          selectedIcon: Icon(
                            Icons.account_balance_wallet,
                            color: AppColors.tealDark,
                          ),
                          label: 'Turnos',
                        ),
                      ],
                    ),
            body: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDesktop)
                      RepaintBoundary(
                        child: PosSidebarRail(
                          selectedIndex: _selectedSidebarIndex,
                          onDestinationSelected: _onSidebarTabSelected,
                          onExitPos: _onExitPos,
                          isCashierOnly: _isCashierOnly,
                        ),
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedSidebarIndex,
                        children: [
                          // Tab 0: Catálogo POS + Panel de Cobro Desktop
                          Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: RepaintBoundary(
                                  child: PosCatalogView(
                                    searchController: _searchCtrl,
                                    searchFocusNode: _searchFocusNode,
                                    onSearchChanged: _onSearchChanged,
                                    onScanBarcode: _openCameraScanner,
                                    onExitPos: _onExitPos,
                                    isCashierOnly: _isCashierOnly,
                                    onSale: _irAVenta,
                                  ),
                                ),
                              ),
                              if (isDesktop)
                                Container(
                                  width:
                                      MediaQuery.of(context).size.width >= 1300
                                          ? 440
                                          : MediaQuery.of(context).size.width >=
                                              1000
                                          ? 400
                                          : 360,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      left: BorderSide(
                                        color: Colors.grey.withValues(
                                          alpha: 0.15,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.03,
                                        ),
                                        blurRadius: 24,
                                        spreadRadius: -4,
                                        offset: const Offset(-8, 0),
                                      ),
                                    ],
                                  ),
                                  child: RepaintBoundary(
                                    child: DesktopPosPanel(
                                      key: _desktopPanelKey,
                                      onSaleCompleted: (soldQuantities) {
                                        context
                                            .read<AdminCatalogCubit>()
                                            .decrementStockLocal(
                                              soldQuantities,
                                            );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Tab 1: Lotes / Inventario (Montado lazy)
                          _visitedTab1 && _inventoryCubit != null
                              ? SafeArea(
                                bottom: false,
                                child: RepaintBoundary(
                                  child: BlocProvider.value(
                                    value: _inventoryCubit!,
                                    child: const InventoryScreen(
                                      isEmbedded: true,
                                    ),
                                  ),
                                ),
                              )
                              : const SizedBox.shrink(),

                          // Tab 2: Historial de Ventas POS (Montado lazy)
                          _visitedTab2 && _ordersCubit != null
                              ? SafeArea(
                                bottom: false,
                                child: RepaintBoundary(
                                  child: BlocProvider.value(
                                    value: _ordersCubit!,
                                    child: OrdersScreen(
                                      isEmbedded: true,
                                      customTitle: 'Historial de Ventas POS',
                                      onOpenCashShifts:
                                          () => _onSidebarTabSelected(3),
                                    ),
                                  ),
                                ),
                              )
                              : const SizedBox.shrink(),

                          // Tab 3: Turnos de Caja (Reutiliza el cubit del árbol)
                          _visitedTab3
                              ? SafeArea(
                                bottom: false,
                                child: RepaintBoundary(
                                  child: AllCashShiftsScreen(
                                    isEmbedded: true,
                                    cubit: context.read<CashShiftsCubit>(),
                                  ),
                                ),
                              )
                              : const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ],
                ),
                // Overlay de procesamiento
                BlocSelector<PosCubit, PosState, bool>(
                  selector: (s) => s.status == PosStatus.loading,
                  builder:
                      (ctx, isLoading) =>
                          isLoading
                              ? const PosProcessingOverlay(isVisible: true)
                              : const SizedBox.shrink(),
                ),
              ],
            ),
            floatingActionButton:
                isDesktop || _selectedSidebarIndex != 0
                    ? null
                    : const PosCheckoutFab(),
          ),
        ),
      ),
    );
  }
}
