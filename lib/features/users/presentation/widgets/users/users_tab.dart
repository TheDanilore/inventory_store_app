import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_state.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/user_card.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/user_delete_flow.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/user_detail_sheet.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/users_skeleton.dart';

class UsersTab extends StatefulWidget {
  final String role;
  final String searchQuery;
  final bool onlyActive;
  final ScrollController? scrollController;
  final TabController? tabController;
  final int tabIndex;

  const UsersTab({
    super.key,
    required this.role,
    required this.searchQuery,
    required this.onlyActive,
    this.scrollController,
    this.tabController,
    this.tabIndex = 0,
  });

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab>
    with AutomaticKeepAliveClientMixin {
  final Set<Object> _selectedIds = {};
  String? _sortColumnId = 'name';
  bool _isSortAscending = true;

  @override
  bool get wantKeepAlive => true;

  void _showUserDetail(BuildContext context, String userId) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final cubit = context.read<UsersCubit>();

    if (isDesktop) {
      // Linear Slide-Over Drawer en Desktop
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Cerrar',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (dialogCtx, anim1, anim2) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 480,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(-4, 0),
                    ),
                  ],
                ),
                child: UserDetailSheet(
                  userId: userId,
                  isSideSheet: true,
                  onUserUpdated: () {
                    context.read<UsersCubit>().fetchUsers();
                  },
                ),
              ),
            ),
          );
        },
        transitionBuilder: (dialogCtx, anim, secondaryAnim, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
      );
    } else {
      // Bottom Sheet Apple HIG en Móvil
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (sheetCtx) => Container(
              height: MediaQuery.of(sheetCtx).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: UserDetailSheet(
                userId: userId,
                isSideSheet: false,
                onUserUpdated: cubit.fetchUsers,
                onToggleStatus: (u) => cubit.toggleUserStatus(u.id, u.isActive),
              ),
            ),
      );
    }
  }

  void _onEditUser(BuildContext context, UserEntity user) {
    context.go(
      '/users/form',
      extra: {'existingUser': user, 'initialRole': user.role},
    );
  }

  Future<void> _confirmDeleteUser(BuildContext context, UserEntity user) async {
    final cubit = context.read<UsersCubit>();
    final deleted = await runDeleteUserFlow(
      context,
      user: user,
      onDeactivate: () => cubit.toggleUserStatus(user.id, user.isActive),
      onDelete: () => cubit.deleteUser(user.id),
    );
    if (deleted && context.mounted) {
      AppSnackbar.show(
        context,
        message: 'Usuario "${user.fullName}" eliminado correctamente',
        type: SnackbarType.success,
      );
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: 'Se copió $label al portapapeles',
      type: SnackbarType.success,
    );
  }

  List<UserEntity> _getSortedList(List<UserEntity> users) {
    if (_sortColumnId == null) return users;
    final list = List<UserEntity>.from(users);
    list.sort((a, b) {
      int comparison = 0;
      switch (_sortColumnId) {
        case 'name':
          comparison = a.fullName.toLowerCase().compareTo(
            b.fullName.toLowerCase(),
          );
          break;
        case 'contact':
          comparison = (a.email ?? '').toLowerCase().compareTo(
            (b.email ?? '').toLowerCase(),
          );
          break;
        case 'document':
          comparison = (a.documentNumber ?? '').compareTo(
            b.documentNumber ?? '',
          );
          break;
        case 'status':
          comparison = (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
          break;
        default:
          comparison = 0;
      }
      return _isSortAscending ? comparison : -comparison;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isLoyaltyEnabled =
        context.watch<AppConfigCubit>().loyaltyGlobalEnabled;

    return BlocBuilder<UsersCubit, UsersState>(
      builder: (context, state) {
        if (state is UsersInitial ||
            (state is UsersLoading && state.currentUsers.isEmpty)) {
          return const UsersSkeleton();
        }

        if (state is UsersError && state.currentUsers.isEmpty) {
          return AppEmptyState(
            icon: Icons.error_outline_rounded,
            color: Colors.red,
            title: 'Ocurrió un error al cargar',
            message: state.message,
            action: TextButton(
              onPressed: () => context.read<UsersCubit>().fetchUsers(),
              child: const Text('Reintentar'),
            ),
          );
        }

        final sortedUsers = _getSortedList(state.currentUsers);

        return AdminProTable<UserEntity>(
          items: sortedUsers,
          itemId: (u) => u.id,
          selectedIds: _selectedIds,
          enableMultiSelect: true,
          onSelectionChanged: (ids) {
            setState(() {
              _selectedIds
                ..clear()
                ..addAll(ids);
            });
          },
          sortColumnId: _sortColumnId,
          isSortAscending: _isSortAscending,
          onSort: (colId, asc) {
            setState(() {
              _sortColumnId = colId;
              _isSortAscending = asc;
            });
          },
          minTableWidth: 960,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onRowTap: (user) => _showUserDetail(context, user.id),
          isLoading: state is UsersLoading,
          emptyState: const AppEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Sin Colaboradores',
            message: 'No se encontraron colaboradores para este filtro.',
          ),
          bulkActions: [
            AdminBulkAction<UserEntity>(
              label: 'Copiar Correos',
              icon: Icons.email_outlined,
              onPressed: (selected) {
                final emails = selected
                    .map((u) => u.email)
                    .where((e) => e != null && e.isNotEmpty)
                    .join(', ');
                _copyToClipboard(context, emails, '${selected.length} correos');
              },
            ),
            AdminBulkAction<UserEntity>(
              label: 'Copiar Nombres',
              icon: Icons.copy_rounded,
              onPressed: (selected) {
                final names = selected.map((u) => u.fullName).join('\n');
                _copyToClipboard(context, names, '${selected.length} nombres');
              },
            ),
            AdminBulkAction<UserEntity>(
              label: 'Limpiar Selección',
              icon: Icons.close_rounded,
              onPressed: (_) => setState(() => _selectedIds.clear()),
            ),
          ],
          paginationConfig: AdminTablePaginationConfig(
            currentPage: state.currentPage + 1,
            pageSize: UsersCubit.pageSize,
            totalItems: state.totalCount,
            onPageChanged: (page) {
              context.read<UsersCubit>().fetchUsers(page: page - 1);
            },
            onPageSizeChanged: (_) {},
          ),
          mobileCardBuilder: (context, user, isSelected, onSelect) {
            return UserCard(
              user: user,
              role: widget.role,
              onTap: () => _showUserDetail(context, user.id),
              onDelete: () => _confirmDeleteUser(context, user),
            );
          },
          columns: [
            // 1. USUARIO (Avatar + Nombre)
            AdminTableColumn<UserEntity>(
              id: 'name',
              label: 'USUARIO',
              flex: 3,
              isSortable: true,
              cellBuilder: (context, user) {
                final initial =
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : '?';
                final isAdmin =
                    user.allRoles.contains(AppRoles.admin) ||
                    user.role == AppRoles.admin;
                final isEmployee =
                    user.allRoles.contains(AppRoles.employee) ||
                    user.role == AppRoles.employee;
                final isCashier =
                    user.allRoles.contains(AppRoles.cashier) ||
                    user.role == AppRoles.cashier;

                final avatarBg =
                    isAdmin
                        ? Colors.indigo.withValues(alpha: 0.12)
                        : isCashier
                        ? Colors.teal.withValues(alpha: 0.12)
                        : isEmployee
                        ? Colors.orange.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.1);

                final avatarFg =
                    isAdmin
                        ? Colors.indigo.shade700
                        : isCashier
                        ? Colors.teal.shade700
                        : isEmployee
                        ? Colors.orange.shade700
                        : AppColors.primary;

                return Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: avatarBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: avatarFg,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),

            // 2. CONTACTO (Email + Teléfono)
            AdminTableColumn<UserEntity>(
              id: 'contact',
              label: 'CONTACTO',
              flex: 3,
              isSortable: true,
              cellBuilder: (context, user) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user.email != null && user.email!.isNotEmpty)
                      Text(
                        user.email!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        'Sin correo',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (user.phone != null && user.phone!.isNotEmpty)
                      Text(
                        user.phone!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                );
              },
            ),

            // 3. DOCUMENTO
            AdminTableColumn<UserEntity>(
              id: 'document',
              label: 'DOCUMENTO',
              flex: 2,
              isSortable: true,
              cellBuilder: (context, user) {
                final hasDoc =
                    user.documentNumber != null &&
                    user.documentNumber!.isNotEmpty;
                return Text(
                  hasDoc ? '${user.documentType}: ${user.documentNumber}' : '—',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),

            // 4. ROLES
            AdminTableColumn<UserEntity>(
              id: 'roles',
              label: 'ROLES',
              flex: 3,
              cellBuilder: (context, user) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children:
                        user.allRoles
                            .where((r) => r.isNotEmpty)
                            .map(_buildRoleBadge)
                            .toList(),
                  ),
                );
              },
            ),

            // 5. PUNTOS (Fidelidad si está activado globalmente)
            if (isLoyaltyEnabled)
              AdminTableColumn<UserEntity>(
                id: 'points',
                label: 'PUNTOS',
                flex: 2,
                cellBuilder: (context, user) {
                  return Row(
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        size: 15,
                        color: Colors.amber.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${user.walletBalance}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  );
                },
              ),

            // 6. ESTADO (Micro-badge + switch)
            AdminTableColumn<UserEntity>(
              id: 'status',
              label: 'ESTADO',
              flex: 2,
              isSortable: true,
              cellBuilder: (context, user) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            user.isActive
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color:
                              user.isActive
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        user.isActive ? 'ACTIVO' : 'INACTIVO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color:
                              user.isActive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.scale(
                      scale: 0.65,
                      child: CupertinoSwitch(
                        value: user.isActive,
                        activeTrackColor: Colors.green,
                        onChanged: (val) {
                          context.read<UsersCubit>().toggleUserStatus(
                            user.id,
                            user.isActive,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            // 7. ACCIONES
            AdminTableColumn<UserEntity>(
              id: 'actions',
              label: 'ACCIONES',
              fixedWidth: 124,
              alignment: Alignment.centerRight,
              cellBuilder: (context, user) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      tooltip: 'Ver detalle lateral',
                      splashRadius: 18,
                      color: Colors.grey.shade600,
                      onPressed: () => _showUserDetail(context, user.id),
                    ),
                    if (context.hasPermission(AppPermissions.usersEdit))
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Editar colaborador',
                        splashRadius: 18,
                        color: AppColors.primary,
                        onPressed: () => _onEditUser(context, user),
                      ),
                    PopupMenuButton<String>(
                      tooltip: 'Más opciones',
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                      splashRadius: 18,
                      onSelected: (v) {
                        if (v == 'toggle') {
                          context.read<UsersCubit>().toggleUserStatus(
                            user.id,
                            user.isActive,
                          );
                        } else if (v == 'delete') {
                          _confirmDeleteUser(context, user);
                        }
                      },
                      itemBuilder:
                          (_) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(
                                    user.isActive
                                        ? Icons.block_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    user.isActive
                                        ? 'Desactivar cuenta'
                                        : 'Reactivar cuenta',
                                  ),
                                ],
                              ),
                            ),
                            if (context.hasPermission(
                              AppPermissions.usersDelete,
                            )) ...[
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Eliminar…',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoleBadge(String r) {
    Color bg;
    Color fg;
    Color border;
    String label;

    switch (r.toLowerCase()) {
      case 'admin':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade700;
        border = Colors.indigo.shade200;
        label = 'Admin';
        break;
      case 'cashier':
      case 'cajero':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade700;
        border = Colors.teal.shade200;
        label = 'Cajero';
        break;
      case 'warehouse_keeper':
      case 'almacenero':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        border = Colors.purple.shade200;
        label = 'Almacén';
        break;
      case 'employee':
      case 'empleado':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        border = Colors.amber.shade200;
        label = 'Empleado';
        break;
      case 'customer':
      case 'cliente':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        border = Colors.blue.shade200;
        label = 'Cliente';
        break;
      default:
        bg = Colors.blueGrey.shade50;
        fg = Colors.blueGrey.shade800;
        border = Colors.blueGrey.shade200;
        label = r.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
