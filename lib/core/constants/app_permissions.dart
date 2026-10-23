/// Catálogo centralizado de Permisos Granulares del Sistema ERP / POS
class AppPermissions {
  AppPermissions._();

  // ─── ACCESO A ENTORNOS ────────────────────────────────────────────────────
  /// Permiso de acceso al entorno administrativo (ERP / Dashboard).
  /// Los roles que NO tengan este permiso son redirigidos exclusivamente al POS.
  static const String erpAccess = 'erp.access';

  // ─── MÓDULO POS ───────────────────────────────────────────────────────────
  static const String posView = 'pos.view';
  static const String posSale = 'pos.sale';
  static const String posDiscount = 'pos.discount';
  static const String posPriceOverride = 'pos.price_override';
  static const String posCancelSale = 'pos.cancel_sale';
  static const String posCashShiftOpen = 'pos.cash_shift.open';
  static const String posCashShiftClose = 'pos.cash_shift.close';

  // ─── MÓDULO ALMACENES ─────────────────────────────────────────────────────
  static const String warehousesViewAll = 'warehouses.view_all';
  static const String warehousesManage = 'warehouses.manage';

  // ─── MÓDULO PROVEEDORES ───────────────────────────────────────────────────
  static const String suppliersView = 'suppliers.view';
  static const String suppliersManage = 'suppliers.manage';

  // ─── MÓDULO COMPRAS ───────────────────────────────────────────────────────
  static const String purchasesView = 'purchases.view';
  static const String purchasesCreate = 'purchases.create';
  static const String purchasesReceive = 'purchases.receive';
  static const String purchasesCancel = 'purchases.cancel';

  // ─── MÓDULO MARCAS Y CATEGORÍAS ───────────────────────────────────────────
  static const String brandsManage = 'brands.manage';
  static const String categoriesManage = 'categories.manage';

  // ─── MÓDULO CLIENTES Y CRÉDITOS ───────────────────────────────────────────
  static const String customersView = 'customers.view';
  static const String customersManage = 'customers.manage';
  static const String creditsManage = 'credits.manage';

  // ─── MÓDULO FINANZAS Y TESORERÍA ──────────────────────────────────────────
  static const String financialAccountsManage = 'financial.accounts.manage';
  static const String financialMovementsCreate = 'financial.movements.create';

  // ─── MÓDULO INVENTARIO ────────────────────────────────────────────────────
  static const String inventoryView = 'inventory.view';
  static const String inventoryAdjust = 'inventory.adjust';
  static const String inventoryTransfer = 'inventory.transfer';
  static const String inventoryPhysicalCount = 'inventory.physical_count';
  static const String inventoryEntries = 'inventory.entries';
  static const String inventoryExits = 'inventory.exits';
  static const String inventoryKardex = 'inventory.kardex';

  // ─── MÓDULO PRODUCTOS Y CATÁLOGO ──────────────────────────────────────────
  static const String productsView = 'products.view';
  static const String productsCreate = 'products.create';
  static const String productsEdit = 'products.edit';
  static const String productsDelete = 'products.delete';
  static const String productsCostsView = 'products.costs.view';
  static const String productsPricesEdit = 'products.prices.edit';

  // ─── MÓDULO USUARIOS Y ROLES ──────────────────────────────────────────────
  static const String usersView = 'users.view';
  static const String usersCreate = 'users.create';
  static const String usersEdit = 'users.edit';
  static const String usersDelete = 'users.delete';
  static const String rolesManage = 'roles.manage';
  static const String permissionsAssign = 'permissions.assign';

  // ─── MÓDULO REPORTES ──────────────────────────────────────────────────────
  static const String reportsView = 'reports.view';
  static const String reportsSales = 'reports.sales';
  static const String reportsInventory = 'reports.inventory';
  static const String reportsFinancial = 'reports.financial';
  static const String reportsExport = 'reports.export';

  // ─── MÓDULO CONFIGURACIÓN ─────────────────────────────────────────────────
  static const String settingsView = 'settings.view';
  static const String settingsEdit = 'settings.edit';
  static const String settingsHardware = 'settings.hardware';

  /// Lista con todos los permisos del sistema
  static const List<String> all = [
    erpAccess,
    warehousesViewAll,
    warehousesManage,
    suppliersView,
    suppliersManage,
    purchasesView,
    purchasesCreate,
    purchasesReceive,
    purchasesCancel,
    brandsManage,
    categoriesManage,
    customersView,
    customersManage,
    creditsManage,
    financialAccountsManage,
    financialMovementsCreate,
    posView,
    posSale,
    posDiscount,
    posPriceOverride,
    posCancelSale,
    posCashShiftOpen,
    posCashShiftClose,
    inventoryView,
    inventoryAdjust,
    inventoryTransfer,
    inventoryPhysicalCount,
    inventoryEntries,
    inventoryExits,
    inventoryKardex,
    productsView,
    productsCreate,
    productsEdit,
    productsDelete,
    productsCostsView,
    productsPricesEdit,
    usersView,
    usersCreate,
    usersEdit,
    usersDelete,
    rolesManage,
    permissionsAssign,
    reportsView,
    reportsSales,
    reportsInventory,
    reportsFinancial,
    reportsExport,
    settingsView,
    settingsEdit,
    settingsHardware,
  ];

  /// Nombres legibles para la interfaz
  static String getLabel(String code) {
    switch (code) {
      case erpAccess:
        return 'Acceso al entorno administrativo (ERP)';
      case warehousesViewAll:
        return 'Ver todos los almacenes';
      case warehousesManage:
        return 'Administrar almacenes y sucursales';
      case suppliersView:
        return 'Ver lista y detalle de proveedores';
      case suppliersManage:
        return 'Crear, editar y eliminar proveedores';
      case purchasesView:
        return 'Ver órdenes de compra y abastecimiento';
      case purchasesCreate:
        return 'Crear y emitir órdenes de compra';
      case purchasesReceive:
        return 'Recepcionar mercadería en almacén';
      case purchasesCancel:
        return 'Anular órdenes de compra';
      case brandsManage:
        return 'Crear y editar marcas y laboratorios';
      case categoriesManage:
        return 'Crear y editar categorías de productos';
      case customersView:
        return 'Ver listado y fichas de clientes';
      case customersManage:
        return 'Crear y editar información de clientes';
      case creditsManage:
        return 'Administrar líneas de crédito y abonos';
      case financialAccountsManage:
        return 'Crear y administrar cuentas bancarias y cajas';
      case financialMovementsCreate:
        return 'Registrar ingresos y egresos manuales de dinero';
      case posView:
        return 'Acceder al POS';
      case posSale:
        return 'Realizar ventas en POS';
      case posDiscount:
        return 'Aplicar descuentos en POS';
      case posPriceOverride:
        return 'Modificar precios al vender';
      case posCancelSale:
        return 'Anular ventas';
      case posCashShiftOpen:
        return 'Abrir caja / turno';
      case posCashShiftClose:
        return 'Cerrar caja / turno';
      case inventoryView:
        return 'Ver stock e inventario';
      case inventoryAdjust:
        return 'Ajustar existencias de stock';
      case inventoryTransfer:
        return 'Transferencias entre almacenes';
      case inventoryPhysicalCount:
        return 'Toma física de inventario';
      case inventoryEntries:
        return 'Registrar ingresos de mercadería';
      case inventoryExits:
        return 'Registrar salidas de mercadería';
      case inventoryKardex:
        return 'Consultar Kárdex';
      case productsView:
        return 'Ver catálogo de productos';
      case productsCreate:
        return 'Crear productos y variantes';
      case productsEdit:
        return 'Editar productos';
      case productsDelete:
        return 'Eliminar productos';
      case productsCostsView:
        return 'Ver costo de adquisición';
      case productsPricesEdit:
        return 'Modificar precios de venta';
      case usersView:
        return 'Ver listado de usuarios';
      case usersCreate:
        return 'Crear usuarios';
      case usersEdit:
        return 'Editar datos de usuarios';
      case usersDelete:
        return 'Eliminar / desactivar usuarios';
      case rolesManage:
        return 'Gestionar roles';
      case permissionsAssign:
        return 'Asignar permisos';
      case reportsView:
        return 'Acceder a reportes';
      case reportsSales:
        return 'Reporte de ventas';
      case reportsInventory:
        return 'Reporte de inventario';
      case reportsFinancial:
        return 'Reporte financiero y cajas';
      case reportsExport:
        return 'Exportar reportes (Excel/CSV/PDF)';
      case settingsView:
        return 'Ver configuraciones';
      case settingsEdit:
        return 'Modificar ajustes del sistema';
      case settingsHardware:
        return 'Configurar impresoras y lectores';
      default:
        return code;
    }
  }

  /// Módulo de pertenencia para agrupar en la interfaz
  static String getModule(String code) {
    if (code == 'erp.access') return 'Acceso y Seguridad';
    if (code.startsWith('warehouses.')) return 'Almacenes y Sucursales';
    if (code.startsWith('pos.')) return 'Punto de Venta (POS)';
    if (code.startsWith('inventory.')) return 'Inventario y Almacén';
    if (code.startsWith('products.') ||
        code.startsWith('brands.') ||
        code.startsWith('categories.')) {
      return 'Catálogo y Productos';
    }
    if (code.startsWith('purchases.')) return 'Compras y Abastecimiento';
    if (code.startsWith('suppliers.')) return 'Proveedores';
    if (code.startsWith('customers.') || code.startsWith('credits.')) {
      return 'Clientes y Créditos';
    }
    if (code.startsWith('financial.')) return 'Finanzas y Tesorería';
    if (code.startsWith('users.') ||
        code.startsWith('roles.') ||
        code.startsWith('permissions.')) {
      return 'Usuarios y Seguridad';
    }
    if (code.startsWith('reports.')) return 'Reportes y Métricas';
    if (code.startsWith('settings.')) return 'Configuración';
    return 'General';
  }
}
