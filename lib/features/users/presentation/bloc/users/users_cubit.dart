import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/features/users/domain/usecases/get_global_users_count_usecase.dart';
import 'package:inventory_store_app/features/users/domain/usecases/get_users_usecase.dart';
import 'package:inventory_store_app/features/users/domain/usecases/update_user_usecase.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_state.dart';

@injectable
class UsersCubit extends Cubit<UsersState> {
  final GetUsersUseCase _getUsers;
  final GetGlobalUsersCountUseCase _getCounts;
  final UpdateUserUseCase _updateUser;

  static const int pageSize = 8;
  String _currentRole = AppRoles.customer;

  UsersCubit(
    this._getUsers,
    this._getCounts,
    this._updateUser,
  ) : super(const UsersInitial());

  Future<void> init(String role) async {
    _currentRole = role;
    await fetchCounts();
    await fetchUsers();
  }

  void setRole(String role) {
    _currentRole = role;
    fetchUsers(page: 0); // Reset page on role change
  }

  Future<void> fetchCounts() async {
    final customerRes = await _getCounts(role: AppRoles.customer);
    final adminRes = await _getCounts(role: AppRoles.admin);
    final employeeRes = await _getCounts(role: AppRoles.employee);

    int cTotal = state.customerTotal;
    int aTotal = state.adminTotal;
    int eTotal = state.employeeTotal;

    customerRes.fold((l) => null, (r) => cTotal = r);
    adminRes.fold((l) => null, (r) => aTotal = r);
    employeeRes.fold((l) => null, (r) => eTotal = r);

    emit(UsersLoading(
      currentUsers: state.currentUsers,
      searchQuery: state.searchQuery,
      onlyActive: state.onlyActive,
      currentPage: state.currentPage,
      totalCount: state.totalCount,
      customerTotal: cTotal,
      adminTotal: aTotal,
      employeeTotal: eTotal,
    ));
    
    // We emit Loading but don't fetch users here, fetchUsers should be called separately or we emit Loaded if we were already loaded
    if (state is UsersLoaded) {
       emit(UsersLoaded(
          users: state.currentUsers,
          searchQuery: state.searchQuery,
          onlyActive: state.onlyActive,
          currentPage: state.currentPage,
          totalCount: state.totalCount,
          customerTotal: cTotal,
          adminTotal: aTotal,
          employeeTotal: eTotal,
        ));
    }
  }

  Future<void> fetchUsers({
    String? searchQuery,
    bool? onlyActive,
    int? page,
  }) async {
    final q = searchQuery ?? state.searchQuery;
    final act = onlyActive ?? state.onlyActive;
    
    // Si cambian los filtros, volvemos a la página 0
    int p = page ?? state.currentPage;
    if (searchQuery != null && searchQuery != state.searchQuery) p = 0;
    if (onlyActive != null && onlyActive != state.onlyActive) p = 0;

    emit(UsersLoading(
      currentUsers: state.currentUsers,
      searchQuery: q,
      onlyActive: act,
      currentPage: p,
      totalCount: state.totalCount,
      customerTotal: state.customerTotal,
      adminTotal: state.adminTotal,
      employeeTotal: state.employeeTotal,
    ));

    final res = await _getUsers(
      role: _currentRole,
      searchQuery: q,
      onlyActive: act,
      page: p,
      pageSize: pageSize,
    );

    res.fold(
      (failure) {
        emit(UsersError(
          message: failure.message,
          currentUsers: state.currentUsers,
          searchQuery: q,
          onlyActive: act,
          currentPage: p,
          totalCount: state.totalCount,
          customerTotal: state.customerTotal,
          adminTotal: state.adminTotal,
          employeeTotal: state.employeeTotal,
        ));
      },
      (users) async {
        // Need to update the count for the CURRENT role to calculate totalPages correctly
        final countRes = await _getCounts(role: _currentRole);
        int newTotal = state.totalCount;
        countRes.fold((l) => null, (r) => newTotal = r);

        emit(UsersLoaded(
          users: users,
          searchQuery: q,
          onlyActive: act,
          currentPage: p,
          totalCount: newTotal,
          customerTotal: _currentRole == AppRoles.customer ? newTotal : state.customerTotal,
          adminTotal: _currentRole == AppRoles.admin ? newTotal : state.adminTotal,
          employeeTotal: _currentRole == AppRoles.employee ? newTotal : state.employeeTotal,
        ));
      },
    );
  }

  Future<void> toggleUserStatus(String userId, bool currentStatus) async {
    final userIdx = state.currentUsers.indexWhere((u) => u.id == userId);
    if (userIdx == -1) return;

    final user = state.currentUsers[userIdx];
    final res = await _updateUser(
      id: user.id,
      fullName: user.fullName,
      role: user.role,
      phone: user.phone,
      documentType: user.documentType,
      documentNumber: user.documentNumber,
      isActive: !currentStatus,
    );

    res.fold(
      (failure) {
        emit(UsersError(
          message: failure.message,
          currentUsers: state.currentUsers,
          searchQuery: state.searchQuery,
          onlyActive: state.onlyActive,
          currentPage: state.currentPage,
          totalCount: state.totalCount,
          customerTotal: state.customerTotal,
          adminTotal: state.adminTotal,
          employeeTotal: state.employeeTotal,
        ));
      },
      (r) {
        // Fetch users again to ensure state is in sync
        fetchUsers();
      },
    );
  }
}
