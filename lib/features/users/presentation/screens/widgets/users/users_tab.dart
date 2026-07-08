import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/users/presentation/providers/users_provider.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/users/presentation/screens/widgets/users/user_detail_sheet.dart';
import 'package:inventory_store_app/features/users/presentation/screens/widgets/users/user_card.dart';
import 'package:inventory_store_app/features/users/presentation/screens/widgets/users/users_skeleton.dart';
import 'package:provider/provider.dart';

class UsersTab extends StatefulWidget {
  final String role;
  final String searchQuery;
  final bool onlyActive;
  final ScrollController? scrollController;

  const UsersTab({
    super.key,
    required this.role,
    required this.searchQuery,
    required this.onlyActive,
    this.scrollController,
  });

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  late UsersProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = UsersProvider(role: widget.role);
    // El provider llamará a loadUsers automáticamente por primera vez
    // pero necesitamos pasarle los filtros actuales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.fetchUsers(widget.searchQuery, widget.onlyActive);
    });
  }

  @override
  void didUpdateWidget(covariant UsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.onlyActive != widget.onlyActive) {
      _provider.fetchUsers(widget.searchQuery, widget.onlyActive);
    }
  }

  void _showUserDetail(BuildContext context, Map<String, dynamic> user) {
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
            child: UserDetailSheet(
              userData: user,
              onUserUpdated: () => _provider.refresh(),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<UsersProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.users.isEmpty) {
            return const UsersSkeleton();
          }

          if (provider.errorMessage != null && provider.users.isEmpty) {
            return AppEmptyState(
              icon: Icons.error_outline_rounded,
              color: Colors.red,
              title: 'Ocurrió un error al cargar',
              message: provider.errorMessage ?? '',
              action: TextButton(
                onPressed: provider.refresh,
                child: const Text('Reintentar'),
              ),
            );
          }

          if (provider.users.isEmpty) {
            return const AppEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'Sin Usuarios',
              message: 'No se encontraron usuarios.',
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'Total: ${provider.totalCount} registros',
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
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemCount: provider.users.length,
                      itemBuilder: (context, index) {
                        final user = provider.users[index];
                        return UserCard(
                          user: user,
                          role: widget.role,
                          onTap: () => _showUserDetail(context, user),
                        );
                      },
                    ),
                    if (provider.isLoading)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(minHeight: 3),
                      ),
                  ],
                ),
              ),
              if (provider.totalPages > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: AdminPageBlocks(
                    currentPage: provider.currentPage,
                    totalPages: provider.totalPages,
                    onPageChanged: (page) {
                      provider.setPage(
                        page,
                        widget.searchQuery,
                        widget.onlyActive,
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
