import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_state.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/user_card.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/user_detail_sheet.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/users_skeleton.dart';

class UsersTab extends StatefulWidget {
  final String role;
  final String searchQuery;
  final bool onlyActive;
  final ScrollController? scrollController;
  final TabController tabController;
  final int tabIndex;

  const UsersTab({
    super.key,
    required this.role,
    required this.searchQuery,
    required this.onlyActive,
    this.scrollController,
    required this.tabController,
    required this.tabIndex,
  });

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab>
    with AutomaticKeepAliveClientMixin {
  bool _hasFetched = false;
  late final ScrollController _scrollController;
  bool _createdLocalController = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _createdLocalController = true;
    }
    widget.tabController.addListener(_onTabChanged);
    // Fetch initial data if this is the active tab
    if (widget.tabController.index == widget.tabIndex) {
      _fetchData();
    }
  }

  @override
  void didUpdateWidget(covariant UsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.onlyActive != widget.onlyActive) {
      // Solo actualiza si es el tab activo para evitar múltiples peticiones
      if (widget.tabController.index == widget.tabIndex) {
        _fetchData();
      } else {
        _hasFetched = false;
      }
    }
  }

  void _onTabChanged() {
    if (widget.tabController.index == widget.tabIndex && !_hasFetched) {
      _fetchData();
    }
  }

  void _fetchData() {
    _hasFetched = true;
    context.read<UsersCubit>().fetchUsers(
      searchQuery: widget.searchQuery,
      onlyActive: widget.onlyActive,
      page: 0,
    );
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    if (_createdLocalController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _showUserDetail(BuildContext context, String userId) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

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
                onUserUpdated: () {
                  context.read<UsersCubit>().fetchUsers();
                },
              ),
            ),
      );
    }
  }

  void _onEditUser(BuildContext context, UserEntity user) {
    context.go(
      '/admin/users/form',
      extra: {'existingUser': user, 'initialRole': user.role},
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

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

        if (state.currentUsers.isEmpty) {
          return const AppEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Sin Usuarios',
            message: 'No se encontraron registros para este filtro.',
          );
        }

        int totalPages = (state.totalCount / UsersCubit.pageSize).ceil();
        if (totalPages == 0) totalPages = 1;

        return Column(
          children: [
            // Barra de conteo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Text(
                    'Mostrando ${state.currentUsers.length} de ${state.totalCount} registros',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (state is UsersLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            // Contenido principal: Grid Desktop vs Lista Móvil
            Expanded(
              child:
                  isDesktop
                      ? _buildDesktopTable(context, state)
                      : _buildMobileList(context, state),
            ),

            // Paginación
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: AdminPageBlocks(
                  currentPage: state.currentPage,
                  totalPages: totalPages,
                  onPageChanged: (page) {
                    context.read<UsersCubit>().fetchUsers(page: page);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  /// Vista Desktop: Tabla Data Grid de Alta Densidad (Stripe / Linear)
  Widget _buildDesktopTable(BuildContext context, UsersState state) {
    final isLoyaltyEnabled =
        context.watch<AppConfigCubit>().loyaltyGlobalEnabled;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Cabecera de la tabla
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'USUARIO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'CONTACTO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'DOCUMENTO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'ROL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (isLoyaltyEnabled)
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'PUNTOS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'ESTADO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 100,
                    child: Text(
                      'ACCIONES',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Filas
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                itemCount: state.currentUsers.length,
                separatorBuilder:
                    (context, index) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                itemBuilder: (context, index) {
                  final user = state.currentUsers[index];
                  return _DesktopTableRow(
                    user: user,
                    isLoyaltyEnabled: isLoyaltyEnabled,
                    onTap: () => _showUserDetail(context, user.id),
                    onEdit: () => _onEditUser(context, user),
                    onToggleActive: (val) {
                      context.read<UsersCubit>().toggleUserStatus(
                        user.id,
                        user.isActive,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista Móvil: Lista de Tarjetas Apple HIG
  Widget _buildMobileList(BuildContext context, UsersState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: state.currentUsers.length,
      itemBuilder: (context, index) {
        final user = state.currentUsers[index];
        return UserCard(
          user: user,
          role: widget.role,
          onTap: () => _showUserDetail(context, user.id),
        );
      },
    );
  }
}

/// Fila individual para la tabla Desktop
class _DesktopTableRow extends StatefulWidget {
  final UserEntity user;
  final bool isLoyaltyEnabled;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;

  const _DesktopTableRow({
    required this.user,
    required this.isLoyaltyEnabled,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  State<_DesktopTableRow> createState() => _DesktopTableRowState();
}

class _DesktopTableRowState extends State<_DesktopTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initial =
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?';

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          hoverColor: AppColors.primary.withValues(alpha: 0.02),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color:
                _isHovered
                    ? AppColors.primary.withValues(alpha: 0.03)
                    : Colors.transparent,
            child: Row(
              children: [
                // 1. Usuario (Avatar + Nombre)
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color:
                              user.role == AppRoles.admin
                                  ? Colors.indigo.withValues(alpha: 0.12)
                                  : user.role == AppRoles.employee
                                  ? Colors.orange.withValues(alpha: 0.12)
                                  : AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                                  user.role == AppRoles.admin
                                      ? Colors.indigo.shade700
                                      : user.role == AppRoles.employee
                                      ? Colors.orange.shade700
                                      : AppColors.primary,
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
                  ),
                ),

                // 2. Contacto (Email + Phone)
                Expanded(
                  flex: 3,
                  child: Column(
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
                  ),
                ),

                // 3. Documento
                Expanded(
                  flex: 2,
                  child: Text(
                    user.documentNumber != null &&
                            user.documentNumber!.isNotEmpty
                        ? '${user.documentType}: ${user.documentNumber}'
                        : '—',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // 4. Rol
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            user.role == AppRoles.admin
                                ? Colors.indigo.shade50
                                : user.role == AppRoles.employee
                                ? Colors.orange.shade50
                                : AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              user.role == AppRoles.admin
                                  ? Colors.indigo.shade200
                                  : user.role == AppRoles.employee
                                  ? Colors.orange.shade200
                                  : AppColors.border,
                        ),
                      ),
                      child: Text(
                        user.role == AppRoles.admin
                            ? 'ADMIN'
                            : user.role == AppRoles.employee
                            ? 'EMPLEADO'
                            : 'CLIENTE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              user.role == AppRoles.admin
                                  ? Colors.indigo.shade700
                                  : user.role == AppRoles.employee
                                  ? Colors.orange.shade700
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),

                // 5. Puntos (Fidelidad)
                if (widget.isLoyaltyEnabled)
                  Expanded(
                    flex: 2,
                    child: Row(
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
                    ),
                  ),

                // 6. Estado (Micro-badge + switch)
                Expanded(
                  flex: 2,
                  child: Row(
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
                        scale: 0.6,
                        child: CupertinoSwitch(
                          value: user.isActive,
                          activeTrackColor: Colors.green,
                          onChanged: widget.onToggleActive,
                        ),
                      ),
                    ],
                  ),
                ),

                // 7. Acciones
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        tooltip: 'Ver detalle lateral',
                        splashRadius: 18,
                        color: Colors.grey.shade600,
                        onPressed: widget.onTap,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Editar usuario',
                        splashRadius: 18,
                        color: AppColors.primary,
                        onPressed: widget.onEdit,
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
