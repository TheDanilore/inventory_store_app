import 'dart:math';

import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/widgets/user_detail_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/screens/admin/user_form_screen.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  static const int _pageSize = 8;

  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  bool _onlyActive = false;
  final Map<String, int> _pageByRole = {
    AppRoles.customer: 0,
    AppRoles.admin: 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      // ✅ Usamos la vista profiles_with_email para obtener el correo también
      final response = await _supabase
          .from('profiles_with_email')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.show(
          context,
          message: 'Error al cargar usuarios: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _refresh() {
    _fetchUsers();
  }

  void _showUserDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.90,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: UserDetailSheet(userData: user, onUserUpdated: _refresh),
          ),
    );
  }

  Widget _buildRoleTab(String role) {
    final query = _searchCtrl.text.toLowerCase();
    final filtered =
        _profiles.where((p) {
          final isRole = p['role'] == role;
          if (!isRole) return false;
          if (_onlyActive && p['is_active'] != true) return false;
          if (query.isNotEmpty) {
            final name = (p['full_name'] as String? ?? '').toLowerCase();
            final phone = (p['phone'] as String? ?? '').toLowerCase();
            final doc = (p['document_number'] as String? ?? '').toLowerCase();
            final email = (p['email'] as String? ?? '').toLowerCase();
            if (!name.contains(query) &&
                !phone.contains(query) &&
                !doc.contains(query) &&
                !email.contains(query)) {
              return false;
            }
          }
          return true;
        }).toList();

    final totalPages =
        filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    int currentPage = _pageByRole[role] ?? 0;
    if (currentPage >= totalPages) {
      currentPage = max(0, totalPages - 1);
      _pageByRole[role] = currentPage;
    }

    final start = currentPage * _pageSize;
    final end = min(start + _pageSize, filtered.length);
    final pageItems = filtered.sublist(start, end);

    if (pageItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron usuarios.',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                'Total: ${filtered.length} registros',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: pageItems.length,
            itemBuilder: (context, index) {
              final user = pageItems[index];
              final String fullName = user['full_name'] ?? 'Sin nombre';
              final String? email = user['email'];
              final String? phone = user['phone'];
              final bool isActive = user['is_active'] ?? true;
              final int walletBalance = user['wallet_balance'] ?? 0;
              final String initial =
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showUserDetail(user),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                role == AppRoles.admin
                                    ? Colors.indigo.withValues(alpha: 0.1)
                                    : AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color:
                                    role == AppRoles.admin
                                        ? Colors.indigo.shade700
                                        : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Nombre + email/teléfono
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              if (email != null && email.isNotEmpty)
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                )
                              else if (phone != null && phone.isNotEmpty)
                                Text(
                                  phone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              // Monedas
                              Row(
                                children: [
                                  Icon(
                                    Icons.stars_rounded,
                                    size: 13,
                                    color: Colors.amber.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$walletBalance monedas',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Estado + chevron
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isActive
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color:
                                      isActive
                                          ? Colors.green.shade200
                                          : Colors.red.shade200,
                                ),
                              ),
                              child: Text(
                                isActive ? 'ACTIVO' : 'INACTIVO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isActive
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: AdminPageBlocks(
              currentPage: currentPage,
              totalPages: totalPages,
              onPageChanged: (page) {
                setState(() {
                  _pageByRole[role] = page;
                });
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerTotal =
        _profiles.where((p) => p['role'] == AppRoles.customer).length;
    final adminTotal =
        _profiles.where((p) => p['role'] == AppRoles.admin).length;

    return DefaultTabController(
      length: 2,
      child: AdminLayout(
        title: 'Usuarios',
        showBackButton: true,
        body: Column(
          children: [
            // ─── BUSCADOR Y FILTROS ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) {
                      setState(() {
                        _pageByRole[AppRoles.customer] = 0;
                        _pageByRole[AppRoles.admin] = 0;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, correo, teléfono o DNI...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.grey.shade400,
                      ),
                      suffixIcon:
                          _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                              : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mostrar solo usuarios activos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Switch(
                        value: _onlyActive,
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) {
                          setState(() {
                            _onlyActive = val;
                            _pageByRole[AppRoles.customer] = 0;
                            _pageByRole[AppRoles.admin] = 0;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── TABS ────────────────────────────────────────────────────────
            Material(
              color: AppColors.primary,
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3.5,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    iconMargin: const EdgeInsets.only(bottom: 6),
                    icon: const Icon(Icons.people_outline_rounded, size: 20),
                    text: 'Clientes ($customerTotal)',
                  ),
                  Tab(
                    iconMargin: const EdgeInsets.only(bottom: 6),
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 20,
                    ),
                    text: 'Admins ($adminTotal)',
                  ),
                ],
              ),
            ),

            // ─── LISTAS ──────────────────────────────────────────────────────
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                        children: [
                          _buildRoleTab(AppRoles.customer),
                          _buildRoleTab(AppRoles.admin),
                        ],
                      ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          onPressed: () async {
            final changed = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserFormScreen()),
            );
            if (changed == true) _refresh();
          },
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text(
            'Nuevo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
