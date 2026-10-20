class AppRoles {
  static const String admin = 'admin';
  static const String cashier = 'cashier';
  static const String warehouseKeeper = 'warehouse_keeper';
  static const String employee = 'employee';
  static const String customer = 'customer';

  static const String legacyCustomer = 'cliente';

  static bool isCustomer(String? role) {
    return role == customer || role == legacyCustomer;
  }

  static String getLabel(String role) {
    switch (role) {
      case admin:
        return 'Administrador';
      case cashier:
        return 'Cajero';
      case warehouseKeeper:
        return 'Almacenero';
      case employee:
        return 'Empleado';
      case customer:
      case legacyCustomer:
        return 'Cliente';
      default:
        return role;
    }
  }
}
