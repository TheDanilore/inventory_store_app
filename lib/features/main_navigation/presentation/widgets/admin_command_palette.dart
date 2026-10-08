import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminCommandPaletteItem {
  final String title;
  final String subtitle;
  final String routePath;
  final IconData icon;
  final String category;

  const AdminCommandPaletteItem({
    required this.title,
    required this.subtitle,
    required this.routePath,
    required this.icon,
    required this.category,
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
    ),
    AdminCommandPaletteItem(
      title: 'Gestión de Pedidos',
      subtitle: 'Historial y despacho de órdenes de venta',
      routePath: '/orders',
      icon: Icons.receipt_long_rounded,
      category: 'Comercial',
    ),
    AdminCommandPaletteItem(
      title: 'Órdenes de Compra',
      subtitle: 'Compras a proveedores y reabastecimiento',
      routePath: '/purchase-orders',
      icon: Icons.shopping_bag_outlined,
      category: 'Compras',
    ),
    AdminCommandPaletteItem(
      title: 'Entradas de Inventario',
      subtitle: 'Ingresos manuales y recepciones de stock',
      routePath: '/inventory-entries',
      icon: Icons.add_business_rounded,
      category: 'Inventario',
    ),
    AdminCommandPaletteItem(
      title: 'Salidas de Inventario',
      subtitle: 'Bajas por merma, roturas o ajustes',
      routePath: '/inventory-exits',
      icon: Icons.remove_shopping_cart_rounded,
      category: 'Inventario',
    ),
    AdminCommandPaletteItem(
      title: 'Stock e Inventario',
      subtitle: 'Control de existencias y valorización',
      routePath: '/inventory',
      icon: Icons.inventory_2_outlined,
      category: 'Inventario',
    ),
    AdminCommandPaletteItem(
      title: 'Kardex de Inventario',
      subtitle: 'Trazabilidad de movimientos de producto',
      routePath: '/kardex',
      icon: Icons.article_outlined,
      category: 'Inventario',
    ),
    AdminCommandPaletteItem(
      title: 'Directorio de Clientes',
      subtitle: 'Cartera de clientes, teléfonos y saldos',
      routePath: '/customers',
      icon: Icons.people_outline_rounded,
      category: 'Clientes',
    ),
    AdminCommandPaletteItem(
      title: 'Créditos de Clientes',
      subtitle: 'Cuentas por cobrar y pagos pendientes',
      routePath: '/customer-credits',
      icon: Icons.credit_score_rounded,
      category: 'Clientes',
    ),
    AdminCommandPaletteItem(
      title: 'Directorio de Proveedores',
      subtitle: 'Lista de empresas y contactos de suministro',
      routePath: '/suppliers',
      icon: Icons.local_shipping_outlined,
      category: 'Compras',
    ),
    AdminCommandPaletteItem(
      title: 'Créditos de Proveedores',
      subtitle: 'Cuentas por pagar y amortizaciones',
      routePath: '/supplier-credits',
      icon: Icons.request_quote_outlined,
      category: 'Compras',
    ),
    AdminCommandPaletteItem(
      title: 'Cuentas Financieras',
      subtitle: 'Cajas, cuentas bancarias y balances',
      routePath: '/financial-accounts',
      icon: Icons.account_balance_wallet_outlined,
      category: 'Finanzas',
    ),
    AdminCommandPaletteItem(
      title: 'Categorías',
      subtitle: 'Clasificación de familias de producto',
      routePath: '/categories',
      icon: Icons.category_outlined,
      category: 'Configuración',
    ),
    AdminCommandPaletteItem(
      title: 'Marcas',
      subtitle: 'Gestión de fabricantes y sellos',
      routePath: '/brands',
      icon: Icons.branding_watermark_outlined,
      category: 'Configuración',
    ),
    AdminCommandPaletteItem(
      title: 'Almacenes',
      subtitle: 'Locales, sucursales y bodegas físicas',
      routePath: '/warehouses',
      icon: Icons.warehouse_outlined,
      category: 'Configuración',
    ),
    AdminCommandPaletteItem(
      title: 'Datos del Negocio',
      subtitle: 'RUC, razón social y configuración global',
      routePath: '/business-info',
      icon: Icons.storefront_rounded,
      category: 'Configuración',
    ),
    AdminCommandPaletteItem(
      title: 'Mi Perfil',
      subtitle: 'Datos de cuenta y sesión de usuario',
      routePath: '/profile',
      icon: Icons.person_outline_rounded,
      category: 'Cuenta',
    ),
  ];

  List<AdminCommandPaletteItem> _filteredItems = _allItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = _allItems;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _allItems;
      } else {
        _filteredItems =
            _allItems.where((item) {
              return item.title.toLowerCase().contains(query) ||
                  item.subtitle.toLowerCase().contains(query) ||
                  item.category.toLowerCase().contains(query);
            }).toList();
      }
      _selectedIndex = 0;
    });
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
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 600,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
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
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Buscar pantalla, reporte o módulo...',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF94A3B8),
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
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'ESC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
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
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No se encontraron coincidencias',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
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
                                          ? const Color(0xFFEFF6FF)
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
                                                ? const Color(
                                                  0xFF2563EB,
                                                ).withValues(alpha: 0.12)
                                                : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        size: 19,
                                        color:
                                            isSelected
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF64748B),
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
                                                      ? const Color(0xFF1E40AF)
                                                      : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
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
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        item.category,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.keyboard_return_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'para seleccionar',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.swap_vert_rounded,
                      size: 15,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'para navegar',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'DANILORE ONE Command Bar',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
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
