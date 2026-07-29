import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
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
  @override
  void initState() {
    super.initState();
    // Fetch initial data for this tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersCubit>().fetchUsers(
        searchQuery: widget.searchQuery,
        onlyActive: widget.onlyActive,
        page: 0,
      );
    });
  }

  @override
  void didUpdateWidget(covariant UsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.onlyActive != widget.onlyActive) {
      context.read<UsersCubit>().fetchUsers(
        searchQuery: widget.searchQuery,
        onlyActive: widget.onlyActive,
        page: 0,
      );
    }
  }

  void _showUserDetail(BuildContext context, String userId) {
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
              userId: userId,
              onUserUpdated: () {
                // Re-fetch users if a user was updated
                context.read<UsersCubit>().fetchUsers();
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            message: 'No se encontraron usuarios.',
          );
        }

        int totalPages = (state.totalCount / UsersCubit.pageSize).ceil();
        if (totalPages == 0) totalPages = 1;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Total: ${state.totalCount} registros',
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
                    itemCount: state.currentUsers.length,
                    itemBuilder: (context, index) {
                      final user = state.currentUsers[index];
                      return UserCard(
                        user: user,
                        role: widget.role,
                        onTap: () => _showUserDetail(context, user.id),
                      );
                    },
                  ),
                  if (state is UsersLoading)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                ],
              ),
            ),
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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
}
