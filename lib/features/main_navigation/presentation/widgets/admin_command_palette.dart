import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';

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
      transitionDuration: const Duration(milliseconds: 180),
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
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);
  final ValueNotifier<List<AdminCommandPaletteItem>> _filteredItems =
      ValueNotifier<List<AdminCommandPaletteItem>>(const []);

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
      title: 'Ayuda y Soporte',
      subtitle: 'Manuales operativos y diagnóstico del sistema',
      routePath: '/help',
      icon: Icons.help_outline_rounded,
      category: 'Sistema',
    ),
    AdminCommandPaletteItem(
      title: 'Mi Perfil',
      subtitle: 'Datos de cuenta y sesión de usuario',
      routePath: '/profile',
      icon: Icons.person_outline_rounded,
      category: 'Cuenta',
    ),
  ];

  // Índice pre-normalizado sin tildes construido una única vez.
  static final List<({AdminCommandPaletteItem item, String haystack})>
  _normalizedCatalog = List.unmodifiable(
    _allItems.map(
      (item) => (
        item: item,
        haystack: _normalize('${item.title} ${item.subtitle} ${item.category}'),
      ),
    ),
  );

  List<({AdminCommandPaletteItem item, String haystack})> _allowedEntries =
      const [];
  String? _lastResolvedUserId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _resolveAllowedItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUserId = context.read<AuthCubit>().state.currentUser?.id;
    if (currentUserId != _lastResolvedUserId) {
      _resolveAllowedItems();
    }
  }

  void _resolveAllowedItems() {
    final currentUser = context.read<AuthCubit>().state.currentUser;
    _lastResolvedUserId = currentUser?.id;
    final isAdmin = currentUser?.isAdmin ?? false;

    _allowedEntries = List.unmodifiable(
      _normalizedCatalog.where((entry) {
        if (isAdmin) return true;
        final perms = entry.item.permissions;
        if (perms == null || perms.isEmpty) return true;
        return currentUser?.hasAnyPermission(perms) ?? false;
      }),
    );

    _applyFilter();
  }

  void _applyFilter() {
    final query = _normalize(_searchController.text.trim());
    if (query.isEmpty) {
      _filteredItems.value = List<AdminCommandPaletteItem>.unmodifiable(
        _allowedEntries.map((e) => e.item),
      );
    } else {
      _filteredItems.value = List<AdminCommandPaletteItem>.unmodifiable(
        _allowedEntries
            .where((e) => e.haystack.contains(query))
            .map((e) => e.item),
      );
    }
    _selectedIndex.value = 0;
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    final items = _filteredItems.value;
    if (items.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _selectedIndex.value = (_selectedIndex.value + 1) % items.length;
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _selectedIndex.value =
          (_selectedIndex.value - 1 + items.length) % items.length;
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _navigate(AdminCommandPaletteItem item) {
    Navigator.of(context).pop();
    context.go(item.routePath);
  }

  static String _normalize(String s) {
    if (s.isEmpty) return s;
    final buffer = StringBuffer();
    final lower = s.toLowerCase();
    for (var i = 0; i < lower.length; i++) {
      final code = lower.codeUnitAt(i);
      switch (code) {
        case 0xE1:
        case 0xE0:
        case 0xE4:
        case 0xE2:
          buffer.write('a');
        case 0xE9:
        case 0xE8:
        case 0xEB:
        case 0xEA:
          buffer.write('e');
        case 0xED:
        case 0xEC:
        case 0xEF:
        case 0xEE:
          buffer.write('i');
        case 0xF3:
        case 0xF2:
        case 0xF6:
        case 0xF4:
          buffer.write('o');
        case 0xFA:
        case 0xF9:
        case 0xFC:
        case 0xFB:
          buffer.write('u');
        case 0xF1:
          buffer.write('n');
        default:
          buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    _focusNode.dispose();
    _selectedIndex.dispose();
    _filteredItems.dispose();
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
        child: Focus(
          onKeyEvent: _handleKeyEvent,
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
                      Icon(
                        Icons.search_rounded,
                        color: textSecondary,
                        size: 22,
                      ),
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
                            final items = _filteredItems.value;
                            final idx = _selectedIndex.value;
                            if (items.isNotEmpty && idx < items.length) {
                              _navigate(items[idx]);
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

                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ValueListenableBuilder<List<AdminCommandPaletteItem>>(
                    valueListenable: _filteredItems,
                    builder: (context, items, _) {
                      if (items.isEmpty) {
                        return Container(
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
                        );
                      }

                      return ValueListenableBuilder<int>(
                        valueListenable: _selectedIndex,
                        builder: (context, selectedIdx, _) {
                          return ListView.builder(
                            shrinkWrap: true,
                            itemExtent: 64,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isSelected = index == selectedIdx;
                              return _CommandPaletteTile(
                                item: item,
                                isSelected: isSelected,
                                isDark: isDark,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                onTap: () => _navigate(item),
                                onHover: () {
                                  if (_selectedIndex.value != index) {
                                    _selectedIndex.value = index;
                                  }
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

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
                    border: Border(
                      top: BorderSide(color: borderColor, width: 1),
                    ),
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
                      const SizedBox(width: 12),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'DANILORE ONE',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandPaletteTile extends StatelessWidget {
  final AdminCommandPaletteItem item;
  final bool isSelected;
  final bool isDark;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _CommandPaletteTile({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onHover: (hovered) {
        if (hovered) onHover();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isDark
                      ? AppColors.primary.withValues(alpha: 0.18)
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
                            ? AppColors.darkSurfaceElevated
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
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color:
                          isSelected
                              ? (isDark
                                  ? Colors.white
                                  : const Color(0xFF1E40AF))
                              : textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
  }
}
