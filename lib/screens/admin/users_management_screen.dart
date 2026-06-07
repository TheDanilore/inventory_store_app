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
    _loadProfiles();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String text, {Color color = Colors.red}) {
    if (!mounted) return;
    AppSnackbar.show(
      context,
      message: text,
      type: color == Colors.red ? SnackbarType.error : SnackbarType.info,
      backgroundColor: color,
    );
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('profiles_with_email')
          .select('*')
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _profiles = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profiles = [];
        _isLoading = false;
      });
      _showMessage('No se pudieron cargar los usuarios: $e');
    }
  }

  bool _isCustomerRole(String role) => AppRoles.isCustomer(role);

  List<Map<String, dynamic>> _filteredProfiles(String role) {
    final search = _searchCtrl.text.trim().toLowerCase();

    return _profiles.where((profile) {
      final profileRole = (profile['role'] as String?) ?? AppRoles.customer;
      final matchesRole =
          role == AppRoles.customer
              ? _isCustomerRole(profileRole)
              : profileRole == AppRoles.admin;
      if (!matchesRole) return false;

      if (_onlyActive && !((profile['is_active'] as bool?) ?? true)) {
        return false;
      }

      if (search.isEmpty) return true;

      final name = ((profile['full_name'] as String?) ?? '').toLowerCase();
      final phone = ((profile['phone'] as String?) ?? '').toLowerCase();
      final document =
          ((profile['document_number'] as String?) ?? '').toLowerCase();
      final email = ((profile['email'] as String?) ?? '').toLowerCase();
      final roleText = profileRole.toLowerCase();

      return name.contains(search) ||
          phone.contains(search) ||
          document.contains(search) ||
          email.contains(search) ||
          roleText.contains(search);
    }).toList();
  }

  int _roleTotal(String role) {
    return _profiles.where((profile) {
      final profileRole = (profile['role'] as String?) ?? AppRoles.customer;
      final matchesRole =
          role == AppRoles.customer
              ? _isCustomerRole(profileRole)
              : profileRole == AppRoles.admin;
      if (!matchesRole) return false;
      if (_onlyActive && !((profile['is_active'] as bool?) ?? true)) {
        return false;
      }
      return true;
    }).length;
  }

  void _setPage(String role, int page) {
    final nextPage = page < 0 ? 0 : page;
    setState(() {
      _pageByRole[role] = nextPage;
    });
  }

  Future<void> _changeRole(Map<String, dynamic> profile) async {
    final currentRole = (profile['role'] as String?) ?? AppRoles.customer;
    String selectedRole = currentRole;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cambiar rol de usuario'),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            items: const [
              DropdownMenuItem(
                value: AppRoles.customer,
                child: Text('Cliente'),
              ),
              DropdownMenuItem(
                value: AppRoles.admin,
                child: Text('Administrador'),
              ),
            ],
            onChanged: (value) {
              if (value != null) selectedRole = value;
            },
            decoration: const InputDecoration(
              labelText: 'Rol nuevo',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (confirm != true || selectedRole == currentRole) return;

    try {
      await _supabase
          .from('profiles')
          .update({'role': selectedRole})
          .eq('id', profile['id']);
      _showMessage('Rol actualizado con éxito.', color: AppColors.success);
      await _loadProfiles();
    } catch (e) {
      _showMessage('No se pudo cambiar el rol: $e');
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> profile) async {
    final isActive = (profile['is_active'] as bool?) ?? true;
    final actionText = isActive ? 'desactivar' : 'reactivar';

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${isActive ? 'Desactivar' : 'Reactivar'} usuario'),
            content: Text('Vas a $actionText este usuario. ¿Deseas continuar?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .from('profiles')
          .update({'is_active': !isActive})
          .eq('id', profile['id']);
      _showMessage(
        isActive ? 'Usuario desactivado.' : 'Usuario reactivado.',
        color: isActive ? AppColors.warning : AppColors.success,
      );
      await _loadProfiles();
    } on PostgrestException catch (e) {
      _showMessage('No se pudo actualizar el estado: $e');
    } catch (e) {
      _showMessage('Error al cambiar estado: $e');
    }
  }

  Future<void> _deleteProfile(Map<String, dynamic> profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar usuario'),
            content: const Text(
              'Esta acción borrará definitivamente el perfil del usuario de la base de datos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('profiles').delete().eq('id', profile['id']);
      _showMessage('Usuario eliminado.', color: AppColors.error);
      await _loadProfiles();
    } catch (e) {
      _showMessage('No se pudo eliminar: $e');
    }
  }

  Future<void> _openCreateUserFlow() async {
    final role = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Crear nuevo usuario'),
          content: const Text(
            'Selecciona el tipo de usuario que quieres crear.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, AppRoles.customer),
              child: const Text('Cliente'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, AppRoles.admin),
              child: const Text('Administrador'),
            ),
          ],
        );
      },
    );

    if (role == null) return;

    // Verificar que la pantalla siga montada tras el await del diálogo
    if (!mounted) return;

    final created = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => UserFormScreen(initialRole: role),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (created == true) {
      if (!mounted) return;
      await _loadProfiles();
    }
  }

  Widget _buildProfileCard(Map<String, dynamic> profile, String role) {
    final name = (profile['full_name'] as String?) ?? 'Sin nombre';
    final isActive = (profile['is_active'] as bool?) ?? true;
    final avatarUrl = profile['avatar_url'] as String?;
    final phone = (profile['phone'] as String?) ?? '-';
    final documentType = (profile['document_type'] as String?) ?? 'DNI';
    final documentNumber = (profile['document_number'] as String?) ?? '-';
    final email = (profile['email'] as String?) ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // 1. Usamos InkWell para dar el efecto de onda al tocar
      child: InkWell(
        borderRadius: BorderRadius.circular(12), // Debe coincidir con el Card
        onTap: () async {
          // 2. Acción al tocar la tarjeta: Abrir la hoja de detalles
          final refresh = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => UserDetailSheet(profile: profile),
          );

          // 3. Si la hoja devolvió true, refrescamos la lista
          if (refresh == true) {
            _loadProfiles();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... (todo tu contenido actual de la Row)
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    role == AppRoles.admin
                        ? Colors.orange.shade100
                        : AppColors.primary.withValues(alpha: 0.1),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child:
                    avatarUrl == null
                        ? Icon(
                          role == AppRoles.admin
                              ? Icons.admin_panel_settings
                              : Icons.person,
                          color:
                              role == AppRoles.admin
                                  ? Colors.orange.shade900
                                  : AppColors.primaryDark,
                          size: 26,
                        )
                        : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isActive
                                      ? Colors.green.shade300
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            isActive ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  isActive
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$documentType: $documentNumber',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onSelected: (value) {
                  if (value == 'role') {
                    _changeRole(profile);
                  } else if (value == 'active') {
                    _toggleActive(profile);
                  } else if (value == 'delete') {
                    _deleteProfile(profile);
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'role',
                        child: Text('Cambiar rol'),
                      ),
                      PopupMenuItem(
                        value: 'active',
                        child: Text(isActive ? 'Desactivar' : 'Reactivar'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar de la BD'),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(String role) {
    final filtered = _filteredProfiles(role);
    final total = filtered.length;
    final totalPages = max(1, (total / _pageSize).ceil());
    final currentPage = min(_pageByRole[role] ?? 0, totalPages - 1);
    final start = currentPage * _pageSize;
    final end = min(start + _pageSize, total);
    final pageItems =
        total == 0 ? <Map<String, dynamic>>[] : filtered.sublist(start, end);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Mostrando ${total == 0 ? 0 : start + 1}-$end de $total',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const Spacer(),
              Text(
                'Página ${total == 0 ? 0 : currentPage + 1} / $totalPages',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              total == 0
                  ? const Center(
                    child: Text(
                      'No se encontraron usuarios.',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: pageItems.length,
                    itemBuilder: (context, index) {
                      return _buildProfileCard(pageItems[index], role);
                    },
                  ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: AdminPageBlocks(
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: (page) => _setPage(role, page),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerTotal = _roleTotal(AppRoles.customer);
    final adminTotal = _roleTotal(AppRoles.admin);

    return DefaultTabController(
      length: 2,
      child: AdminLayout(
        title: 'Gestión de Usuarios',
        showBackButton: true,
        showProfileButton: false,
        floatingActionButton: FloatingActionButton(
          onPressed: _openCreateUserFlow,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.person_add_alt_1),
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Buscar por nombre, teléfono, documento o rol',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          _searchCtrl.text.trim().isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Switch(
                        value: _onlyActive,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _onlyActive = val),
                      ),
                      Text(
                        'Mostrar solo usuarios activos',
                        style: TextStyle(
                          color: Colors.blueGrey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Material(
              color: AppColors.primary,
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3.5,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(
                    text: 'Clientes ($customerTotal)',
                    icon: const Icon(Icons.people_outline, size: 20),
                  ),
                  Tab(
                    text: 'Administradores ($adminTotal)',
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
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
      ),
    );
  }
}
