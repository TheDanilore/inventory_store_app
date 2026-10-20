import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/roles/presentation/widgets/roles_management_view.dart';

class RolesManagementScreen extends StatelessWidget {
  const RolesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminLayout(
      title: 'Roles y Permisos',
      body: RolesManagementView(),
    );
  }
}
