import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
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
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/quick_create_customer_dialog.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_processing_overlay.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_sidebar_rail.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_sales_view.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/all_cash_shifts_screen.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';

extension ProductToCartExtension on ProductEntity {
  CartItemEntity toCartItem() {
    final variant = defaultVariant;
    final cartKey = variant?.id ?? id;
    return CartItemEntity(
      productId: id,
      productName: name,
      cartKey: cartKey,
      variantId: variant?.id,
      variantLabel: variant?.label,
      quantity: 1,
      unitPrice: displaySalePrice ?? 0.0,
      unitCost: variant?.unitCost ?? 0.0,
      availableStock: stockControl ? totalStock : CartItemEntity.unlimitedStock,
      usesBatches: usesBatches,
      wholesalePrice: variant?.wholesalePrice,
      sku: variant?.sku,
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
  CashShiftsCubit? _cashShiftsCubit;
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

      // Asegurar que la configuración global de negocio (fidelidad, etc.) esté cargada
      final appConfigCubit = context.read<AppConfigCubit>();
      if (appConfigCubit.businessInfo == null) {
        appConfigCubit.loadBusinessInfo();
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

  bool _isInputFieldFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final context = primaryFocus.context;
    if (context == null) return false;

    if (context.widget is EditableText) return true;

    bool isEditing = false;
    context.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        isEditing = true;
        return false;
      }
      return true;
    });
    return isEditing;
  }

  void _refreshActiveTab() {
    switch (_selectedSidebarIndex) {
      case 0:
        _catalogCubit.refreshProducts();
        context.read<PosCubit>().refreshAccountsAndShift();
        break;
      case 1:
        context.read<InventoryCubit>().initStockTab();
        break;
      case 2:
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

  bool _handleGlobalHardwareKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;

    try {
      final isAlt = HardwareKeyboard.instance.isAltPressed;
      final isControl = HardwareKeyboard.instance.isControlPressed;
      final isMeta = HardwareKeyboard.instance.isMetaPressed;
      final hasModifier = isAlt || isControl || isMeta;

      // ── Regla de Aislamiento de Foco Pro Tools ───────────────────────────
      // Si el usuario presiona una tecla SIN modificador pero tiene el foco
      // en un campo de texto editable, NO interceptamos la tecla para permitir
      // la escritura normal de caracteres.
      if (!hasModifier && _isInputFieldFocused()) {
        return false;
      }

      // 1. Tab 0: Venta POS (V, Alt+V, Alt+1, 1 numpad)
      if (event.logicalKey == LogicalKeyboardKey.keyV ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.digit1) ||
          event.logicalKey == LogicalKeyboardKey.numpad1) {
        _onSidebarTabSelected(0);
        return true;
      }

      // 2. Tab 1: Lotes / Inventario (L, Alt+L, Alt+2, 2 numpad)
      if (event.logicalKey == LogicalKeyboardKey.keyL ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.digit2) ||
          event.logicalKey == LogicalKeyboardKey.numpad2) {
        _onSidebarTabSelected(1);
        return true;
      }

      // 3. Tab 2: Historial de Ventas (H, Alt+H, Alt+3, 3 numpad)
      if (event.logicalKey == LogicalKeyboardKey.keyH ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.digit3) ||
          event.logicalKey == LogicalKeyboardKey.numpad3) {
        _onSidebarTabSelected(2);
        return true;
      }

      // 4. Tab 3: Turnos de Caja (T, Alt+T, Alt+4, 4 numpad)
      if (event.logicalKey == LogicalKeyboardKey.keyT ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.digit4) ||
          event.logicalKey == LogicalKeyboardKey.numpad4) {
        _onSidebarTabSelected(3);
        return true;
      }

      // 5. Foco en Buscador de Productos ( / o K o Alt+K)
      if (event.logicalKey == LogicalKeyboardKey.slash ||
          event.logicalKey == LogicalKeyboardKey.keyK) {
        if (_selectedSidebarIndex == 0) {
          _focusSearch();
          return true;
        }
      }

      // 6. Guardar Borrador (B o Alt+B)
      if (event.logicalKey == LogicalKeyboardKey.keyB) {
        if (_selectedSidebarIndex == 0) {
          _desktopPanelKey.currentState?.triggerDraft();
          return true;
        }
      }

      // 7. Abrir Buscador de Cliente (C o Alt+C)
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        if (_selectedSidebarIndex == 0) {
          _desktopPanelKey.currentState?.openClientSearch();
          return true;
        }
      }

      // 8. Nuevo Cliente Express (N o Alt+A o Alt+N)
      if (event.logicalKey == LogicalKeyboardKey.keyN ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.keyA)) {
        if (_selectedSidebarIndex == 0) {
          _openQuickCreateCustomer();
          return true;
        }
      }

      // 9. Alternar modo Producto vs Ingrediente Activo (I o Alt+I)
      if (event.logicalKey == LogicalKeyboardKey.keyI) {
        if (_selectedSidebarIndex == 0) {
          _catalogCubit.toggleSearchByIngredient(!_catalogCubit.state.searchByIngredient);
          return true;
        }
      }

      // 10. Recargar datos de la pestaña activa (R o Alt+R)
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _refreshActiveTab();
        return true;
      }
    } catch (_) {
      return false;
    }

    return false;
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
    if (index == 3 && _cashShiftsCubit == null) {
      _cashShiftsCubit = sl<CashShiftsCubit>();
    }
    setState(() {
      _selectedSidebarIndex = index;
    });
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
                    backgroundColor: AppColors.primary,
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
    _cashShiftsCubit?.close();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _irAVenta(ProductEntity product) async {
    // Si el producto no tiene variantes o tiene solo 1 (la default) y no usa lotes:
    // Flujo POS de Alta Velocidad (1-Click): se agrega directo a la caja sin abrir modal.
    if (product.productVariants.length <= 1 && !product.usesBatches) {
      if (product.stockControl && product.totalStock <= 0) {
        AppSnackbar.show(
          context,
          message: '${product.name} está agotado',
          type: SnackbarType.warning,
        );
        return;
      }
      final cart = context.read<CartCubit>();
      cart.addItem(product.toCartItem());
      HapticFeedback.lightImpact();
      return;
    }

    // Si tiene múltiples variantes (> 1) o requiere selección de lote, se abre el modal
    PosAddToCartSheet.show(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Foco de Búsqueda (Ctrl+K, Cmd+K, Alt+K)
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, alt: true): _focusSearch,

        // Guardar Borrador (Alt+B)
        const SingleActivator(LogicalKeyboardKey.keyB, alt: true): () {
          _desktopPanelKey.currentState?.triggerDraft();
        },

        // Navegación Sidebar: Venta (Ctrl+1 / Cmd+1 / Alt+1 / Alt+V / Numpad 1)
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => _onSidebarTabSelected(0),
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () => _onSidebarTabSelected(0),
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () => _onSidebarTabSelected(0),
        const SingleActivator(LogicalKeyboardKey.numpad1): () => _onSidebarTabSelected(0),
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () => _onSidebarTabSelected(0),
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () => _onSidebarTabSelected(0),
        const SingleActivator(LogicalKeyboardKey.keyV, alt: true): () => _onSidebarTabSelected(0),

        // Navegación Sidebar: Lotes / Stock (Ctrl+2 / Cmd+2 / Alt+2 / Alt+L / Alt+S / Numpad 2)
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.numpad2): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.keyL, alt: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.keyS, alt: true): () => _onSidebarTabSelected(1),

        // Navegación Sidebar: Ventas / Historial (Ctrl+3 / Cmd+3 / Alt+3 / Alt+H / Numpad 3)
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => _onSidebarTabSelected(2),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () => _onSidebarTabSelected(2),
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () => _onSidebarTabSelected(2),
        const SingleActivator(LogicalKeyboardKey.numpad3): () => _onSidebarTabSelected(2),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () => _onSidebarTabSelected(2),
        const SingleActivator(LogicalKeyboardKey.keyH, meta: true): () => _onSidebarTabSelected(2),
        const SingleActivator(LogicalKeyboardKey.keyH, alt: true): () => _onSidebarTabSelected(2),

        // Navegación Sidebar: Turnos de Caja (Ctrl+4 / Cmd+4 / Alt+4 / Alt+T / Numpad 4)
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => _onSidebarTabSelected(3),
        const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () => _onSidebarTabSelected(3),
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () => _onSidebarTabSelected(3),
        const SingleActivator(LogicalKeyboardKey.numpad4): () => _onSidebarTabSelected(3),
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () => _onSidebarTabSelected(3),
        const SingleActivator(LogicalKeyboardKey.keyT, meta: true): () => _onSidebarTabSelected(3),
        const SingleActivator(LogicalKeyboardKey.keyT, alt: true): () => _onSidebarTabSelected(3),

        // Alternar modo de búsqueda Producto vs Ingrediente Activo (Ctrl+I / Cmd+I / Alt+I)
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
          _catalogCubit.toggleSearchByIngredient(!_catalogCubit.state.searchByIngredient);
        },
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () {
          _catalogCubit.toggleSearchByIngredient(!_catalogCubit.state.searchByIngredient);
        },
        const SingleActivator(LogicalKeyboardKey.keyI, alt: true): () {
          _catalogCubit.toggleSearchByIngredient(!_catalogCubit.state.searchByIngredient);
        },

        // Cobrar Inmediato en Desktop (F2 o Alt+Enter)
        const SingleActivator(LogicalKeyboardKey.f2): () {
          _desktopPanelKey.currentState?.triggerCheckout();
        },
        const SingleActivator(LogicalKeyboardKey.enter, alt: true): () {
          _desktopPanelKey.currentState?.triggerCheckout();
        },

        // Abrir Búsqueda de Cliente en Desktop (Alt+C)
        const SingleActivator(LogicalKeyboardKey.keyC, alt: true): () {
          _desktopPanelKey.currentState?.openClientSearch();
        },

        // Nuevo Cliente Express (Alt+A)
        const SingleActivator(LogicalKeyboardKey.keyA, alt: true): _openQuickCreateCustomer,

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
                    indicatorColor: AppColors.teal.withValues(alpha: 0.15),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.point_of_sale_outlined),
                        selectedIcon: Icon(Icons.point_of_sale, color: AppColors.tealDark),
                        label: 'Venta',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2, color: AppColors.tealDark),
                        label: 'Lotes/Stock',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long, color: AppColors.tealDark),
                        label: 'Ventas',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.tealDark),
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
                    Expanded(
                      child: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                        buildWhen: (prev, current) =>
                            prev.products != current.products ||
                            prev.catalogState != current.catalogState ||
                            prev.errorMessage != current.errorMessage,
                        builder: (context, state) =>
                            _buildMainContent(
                              context,
                              context.read<AdminCatalogCubit>(),
                              state,
                              headerSliver: _buildCatalogHeaderSliver(context),
                              chipsSliver: _buildCategoryChipsSliver(context),
                            ),
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
                    onOpenCashShifts: () => _onSidebarTabSelected(3),
                  ),
                );
              } else if (_selectedSidebarIndex == 3) {
                _cashShiftsCubit ??= sl<CashShiftsCubit>();
                activeView = Expanded(
                  child: AllCashShiftsScreen(
                    isEmbedded: true,
                    cubit: _cashShiftsCubit,
                  ),
                );
              } else {
                activeView = Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: RepaintBoundary(child: catalogContent),
                      ),
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
                          child: RepaintBoundary(
                            child: DesktopPosPanel(
                              key: _desktopPanelKey,
                              onSaleCompleted: (soldQuantities) {
                                context
                                    .read<AdminCatalogCubit>()
                                    .decrementStockLocal(soldQuantities);
                              },
                            ),
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
                        RepaintBoundary(
                          child: PosSidebarRail(
                            selectedIndex: _selectedSidebarIndex,
                            onDestinationSelected: _onSidebarTabSelected,
                            onExitPos: _onExitPos,
                          ),
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

  Widget _buildCatalogHeaderSliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: BlocSelector<AdminCatalogCubit, AdminCatalogState, bool>(
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
      ),
    );
  }

  Widget _buildCategoryChipsSliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
        buildWhen: (prev, current) =>
            prev.categories != current.categories ||
            prev.selectedCategoryId != current.selectedCategoryId ||
            prev.brands != current.brands ||
            prev.selectedBrandId != current.selectedBrandId ||
            prev.filterIsActive != current.filterIsActive ||
            prev.sortOption != current.sortOption ||
            prev.stockFilter != current.stockFilter,
        builder: (context, state) {
          if (state.categories.isEmpty && state.brands.isEmpty) {
            return const SizedBox.shrink();
          }
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CategoryChips(
              categories: state.categories,
              selectedCategoryId: state.selectedCategoryId,
              onSelected: context.read<AdminCatalogCubit>().setCategory,
              brands: state.brands,
              selectedBrandId: state.selectedBrandId,
              onBrandSelected: context.read<AdminCatalogCubit>().setBrand,
              filterIsActive: state.filterIsActive,
              showStatusFilter: false,
              sortOption: state.sortOption,
              onSortSelected: context.read<AdminCatalogCubit>().setSortOption,
              stockFilter: state.stockFilter,
              onStockFilterSelected: context.read<AdminCatalogCubit>().setStockFilter,
              onClearAllFilters: () {
                final cubit = context.read<AdminCatalogCubit>();
                cubit.setCategory(null);
                cubit.setBrand(null);
                cubit.setStockFilter(CatalogStockFilter.all);
                cubit.setSortOption(CatalogSortOption.recent);
                cubit.setFilterIsActive(true);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AdminCatalogCubit cubit,
    AdminCatalogState state, {
    required Widget headerSliver,
    required Widget chipsSliver,
  }) {
    if ((state.catalogState == ViewState.loading) && state.products.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          headerSliver,
          chipsSliver,
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
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
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return const AppShimmer(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 16,
                  );
                },
                childCount: 12,
              ),
            ),
          ),
        ],
      );
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          headerSliver,
          chipsSliver,
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CatalogErrorState(message: state.errorMessage!)),
          ),
        ],
      );
    }

    if (state.products.isEmpty && !(state.catalogState == ViewState.loading)) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          headerSliver,
          chipsSliver,
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CatalogEmptyState(
                searchByIngredient: state.searchByIngredient,
                searchTerm: state.searchTerm,
              ),
            ),
          ),
        ],
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
      headerSliver: headerSliver,
      chipsSliver: chipsSliver,
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
