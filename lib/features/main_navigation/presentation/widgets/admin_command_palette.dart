import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_permissions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';

class AdminCommandPaletteItem {
  final String title;
  final String subtitle;
  final String routePath;
  final IconData icon;
  final String category;
  final List<String>? permissions;

  const AdminCommandPaletteItem({
    required this.title,
    required this.subtitle,
    required this.routePath,
    required this.icon,
    required this.category,
    this.permissions,
  });
}

class AdminCommandPaletteDialog extends StatefulWidget {
  const AdminCommandPaletteDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CommandPalette',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return const AdminCommandPaletteDialog();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  @override
  State<AdminCommandPaletteDialog> createState() =>
      _AdminCommandPaletteDialogState();
}

class _AdminCommandPaletteDialogState extends State<AdminCommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;

  static const List<AdminCommandPaletteItem> _allItems = [
    AdminCommandPaletteItem(
      title: 'Dashboard General',
      subtitle: 'Métricas de ventas, inventario y meta',
      routePath: '/',
      icon: Icons.bar_chart_rounded,
      category: 'Navegación Rápida',
    ),
    AdminCommandPaletteItem(
      title: 'Catálogo de Productos',
      subtitle: 'Exploración y vista comercial de productos',
      routePath: '/catalog',
      icon: Icons.grid_view_rounded,
      category: 'Navegación Rápida',
      permissions: [AppPermissions.productsView, AppPermissions.inventoryView],
    ),
    AdminCommandPaletteItem(
      title: 'Gestión de Pedidos',
      subtitle: 'Historial y despacho de órdenes de venta',
      routePath: '/orders',
      icon: Icons.receipt_long_rounded,
      category: 'Comercial',
      permissions: [AppPermissions.posView, AppPermissions.posSale],
    ),
    AdminCommandPaletteItem(
      title: 'Órdenes de Compra',
      subtitle: 'Compras a proveedores y reabastecimiento',
      routePath: '/purchase-orders',
      icon: Icons.shopping_bag_outlined,
      category: 'Compras',
      permissions: [
        AppPermissions.purchasesView,
        AppPermissions.purchasesCreate,
        AppPermissions.purchasesReceive,
      ],
    ),
    AdminCommandPaletteItem(
      title: 'Entradas de Inventario',
      subtitle: 'Ingresos manuales y recepciones de stock',
      routePath: '/inventory-entries',
      icon: Icons.add_business_rounded,
      category: 'Inventario',
      permissions: [AppPermissions.inventoryEntries],
    ),
    AdminCommandPaletteItem(
      title: 'Salidas de Inventario',
      subtitle: 'Bajas por merma, roturas o ajustes',
      routePath: '/inventory-exits',
      icon: Icons.remove_shopping_cart_rounded,
      category: 'Inventario',
      permissions: [AppPermissions.inventoryExits],
    ),
    AdminCommandPaletteItem(
      title: 'Stock e Inventario',
      subtitle: 'Control de existencias y valorización',
      routePath: '/inventory',
      icon: Icons.inventory_2_outlined,
      category: 'Inventario',
      permissions: [AppPermissions.inventoryView],
    ),
    AdminCommandPaletteItem(
      title: 'Kardex de Inventario',
      subtitle: 'Trazabilidad de movimientos de producto',
      routePath: '/kardex',
      icon: Icons.article_outlined,
      category: 'Inventario',
      permissions: [AppPermissions.inventoryKardex],
    ),
    AdminCommandPaletteItem(
      title: 'Directorio de Clientes',
      subtitle: 'Cartera de clientes, teléfonos y saldos',
      routePath: '/customers',
      icon: Icons.people_outline_rounded,
      category: 'Clientes',
      permissions: [
        AppPermissions.customersView,
        AppPermissions.customersManage,
        AppPermissions.posView,
        AppPermissions.posSale,
      ],
    ),
    AdminCommandPaletteItem(
      title: 'Créditos de Clientes',
      subtitle: 'Cuentas por cobrar y pagos pendientes',
      routePath: '/customer-credits',
      icon: Icons.credit_score_rounded,
      category: 'Clientes',
      permissions: [
        AppPermissions.creditsManage,
        AppPermissions.reportsFinancial,
      ],
    ),
    AdminCommandPaletteItem(
      title: 'Directorio de Proveedores',
      subtitle: 'Lista de empresas y contactos de suministro',
      routePath: '/suppliers',
      icon: Icons.local_shipping_outlined,
      category: 'Compras',
      permissions: [
        AppPermissions.suppliersView,
        AppPermissions.suppliersManage,
      ],
    ),
    AdminCommandPaletteItem(
      title: 'Créditos de Proveedores',
      subtitle: 'Cuentas por pagar y amortizaciones',
      routePath: '/supplier-credits',
      icon: Icons.request_quote_outlined,
      category: 'Compras',
      permissions: [
        AppPermissions.purchasesView,
        AppPermissions.reportsFinancial,
      ],
    ),
    AdminCommandPaletteItem(
      title: 'Cuentas Financieras',
      subtitle: 'Cajas, cuentas bancarias y balances',
      routePath: '/financial-accounts',
      icon: Icons.account_balance_wallet_outlined,
      category: 'Finanzas',
      permissions: [
        AppPermissions.financialAccountsManage,
        AppPermissions.reportsFinancial,
        AppPermissions.settingsView,
      ],
    ),
    AdminCommandPaletteItem(
      title: 'Categorías',
      subtitle: 'Clasificación de familias de producto',
      routePath: '/categories',
      icon: Icons.category_outlined,
      category: 'Configuración',
      permissions: [
        AppPermissions.categoriesManage,
        AppPermissions.productsEdit,
      ],
    ),
    AdminCommandPaletteItem(
      title: 'Marcas',
      subtitle: 'Gestión de fabricantes y sellos',
      routePath: '/brands',
      icon: Icons.branding_watermark_outlined,
      category: 'Configuración',
      permissions: [AppPermissions.brandsManage, AppPermissions.productsEdit],
    ),
    AdminCommandPaletteItem(
      title: 'Almacenes',
      subtitle: 'Locales, sucursales y bodegas físicas',
      routePath: '/warehouses',
      icon: Icons.warehouse_outlined,
      category: 'Configuración',
      permissions: [
        AppPermissions.warehousesManage,
        AppPermissions.inventoryTransfer,
        AppPermissions.settingsView,
      ],
    ),
    AdminCommandPaletteItem(
      title: 'Usuarios',
      subtitle: 'Control de colaboradores y accesos',
      routePath: '/users',
      icon: Icons.account_circle_outlined,
      category: 'Sistema',
      permissions: [AppPermissions.usersView],
    ),
    AdminCommandPaletteItem(
      title: 'Roles y Permisos',
      subtitle: 'Seguridad y permisos granulares',
      routePath: '/roles',
      icon: Icons.shield_outlined,
      category: 'Sistema',
      permissions: [
        AppPermissions.rolesManage,
        AppPermissions.permissionsAssign,
      ],
    ),
    AdminCommandPaletteItem(
      title: 'Datos del Negocio',
      subtitle: 'RUC, razón social y configuración global',
      routePath: '/business-info',
      icon: Icons.storefront_rounded,
      category: 'Configuración',
      permissions: [AppPermissions.settingsView, AppPermissions.settingsEdit],
    ),
    AdminCommandPaletteItem(
      title: 'Configuraciones',
      subtitle: 'Ajustes del sistema y preferencias',
      routePath: '/settings',
      icon: Icons.settings_outlined,
      category: 'Sistema',
      permissions: [AppPermissions.settingsView],
    ),
    AdminCommandPaletteItem(
      title: 'Mi Perfil',
      subtitle: 'Datos de cuenta y sesión de usuario',
      routePath: '/profile',
      icon: Icons.person_outline_rounded,
      category: 'Cuenta',
    ),
  ];

  List<AdminCommandPaletteItem> _allowedItems = const [];
  List<AdminCommandPaletteItem> _filteredItems = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAllowedItems();
  }

  void _updateAllowedItems() {
    final authState = context.read<AuthCubit>().state;
    final currentUser = authState.currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;

    _allowedItems =
        _allItems.where((item) {
          if (isAdmin) return true;
          if (item.permissions == null || item.permissions!.isEmpty)
            return true;
          return currentUser?.hasAnyPermission(item.permissions!) ?? false;
        }).toList();

    _applyFilter();
  }

  void _onSearchChanged() {
    setState(() {
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredItems = _allowedItems;
    } else {
      _filteredItems =
          _allowedItems.where((item) {
            return item.title.toLowerCase().contains(query) ||
                item.subtitle.toLowerCase().contains(query) ||
                item.category.toLowerCase().contains(query);
          }).toList();
    }
    _selectedIndex = 0;
  }

  void _navigate(AdminCommandPaletteItem item) {
    Navigator.of(context).pop();
    context.go(item.routePath);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
    final footerBg = isDark ? const Color(0xFF0D1424) : const Color(0xFFF8FAFC);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 600,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: textSecondary, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar pantalla, reporte o módulo...',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color:
                                isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) {
                          if (_filteredItems.isNotEmpty &&
                              _selectedIndex < _filteredItems.length) {
                            _navigate(_filteredItems[_selectedIndex]);
                          }
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.darkSurfaceElevated
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        'ESC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Results List
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child:
                    _filteredItems.isEmpty
                        ? Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: textSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No se encontraron coincidencias',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final isSelected = index == _selectedIndex;

                            return InkWell(
                              onTap: () => _navigate(item),
                              onHover: (hovered) {
                                if (hovered && _selectedIndex != index) {
                                  setState(() => _selectedIndex = index);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? (isDark
                                              ? AppColors.primary.withValues(
                                                alpha: 0.18,
                                              )
                                              : const Color(0xFFEFF6FF))
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? AppColors.primary.withValues(
                                                  alpha: isDark ? 0.3 : 0.12,
                                                )
                                                : (isDark
                                                    ? AppColors
                                                        .darkSurfaceElevated
                                                    : const Color(0xFFF1F5F9)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        size: 19,
                                        color:
                                            isSelected
                                                ? (isDark
                                                    ? const Color(0xFF60A5FA)
                                                    : const Color(0xFF2563EB))
                                                : textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                              color:
                                                  isSelected
                                                      ? (isDark
                                                          ? Colors.white
                                                          : const Color(
                                                            0xFF1E40AF,
                                                          ))
                                                      : textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? AppColors.darkSurfaceElevated
                                                : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Text(
                                        item.category,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),

              // Footer Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: footerBg,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.keyboard_return_rounded,
                      size: 14,
                      color:
                          isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'para seleccionar',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.swap_vert_rounded,
                      size: 15,
                      color:
                          isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'para navegar',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'DANILORE ONE Command Bar',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
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
}
