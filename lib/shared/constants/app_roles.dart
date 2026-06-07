class AppRoles {
  static const String admin = 'admin';
  static const String customer = 'customer';

  static const String legacyCustomer = 'cliente';

  static bool isCustomer(String? role) {
    return role == customer || role == legacyCustomer;
  }
}
