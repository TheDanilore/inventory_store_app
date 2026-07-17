import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';

abstract class UsersState extends Equatable {
  final List<UserEntity> currentUsers;
  final String searchQuery;
  final bool onlyActive;
  final int currentPage;
  final int totalCount;
  final int customerTotal;
  final int adminTotal;
  final int employeeTotal;

  const UsersState({
    this.currentUsers = const [],
    this.searchQuery = '',
    this.onlyActive = false,
    this.currentPage = 0,
    this.totalCount = 0,
    this.customerTotal = 0,
    this.adminTotal = 0,
    this.employeeTotal = 0,
  });

  @override
  List<Object?> get props => [
        currentUsers,
        searchQuery,
        onlyActive,
        currentPage,
        totalCount,
        customerTotal,
        adminTotal,
        employeeTotal,
      ];
}

class UsersInitial extends UsersState {
  const UsersInitial() : super();
}

class UsersLoading extends UsersState {
  const UsersLoading({
    super.currentUsers,
    super.searchQuery,
    super.onlyActive,
    super.currentPage,
    super.totalCount,
    super.customerTotal,
    super.adminTotal,
    super.employeeTotal,
  });
}

class UsersLoaded extends UsersState {
  final List<UserEntity> users;

  const UsersLoaded({
    required this.users,
    super.searchQuery,
    super.onlyActive,
    super.currentPage,
    super.totalCount,
    super.customerTotal,
    super.adminTotal,
    super.employeeTotal,
  }) : super(currentUsers: users);

  @override
  List<Object?> get props => super.props..add(users);
}

class UsersError extends UsersState {
  final String message;

  const UsersError({
    required this.message,
    super.currentUsers,
    super.searchQuery,
    super.onlyActive,
    super.currentPage,
    super.totalCount,
    super.customerTotal,
    super.adminTotal,
    super.employeeTotal,
  });

  @override
  List<Object?> get props => super.props..add(message);
}
