import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';

abstract class UserDetailState extends Equatable {
  const UserDetailState();

  @override
  List<Object?> get props => [];
}

class UserDetailInitial extends UserDetailState {
  const UserDetailInitial();
}

class UserDetailLoading extends UserDetailState {
  const UserDetailLoading();
}

class UserDetailLoaded extends UserDetailState {
  final UserEntity user;
  final List<Map<String, dynamic>> recentMovements;
  final bool isSaving;
  final String? successMessage;
  final String? errorMessage;

  const UserDetailLoaded({
    required this.user,
    this.recentMovements = const [],
    this.isSaving = false,
    this.successMessage,
    this.errorMessage,
  });

  UserDetailLoaded copyWith({
    UserEntity? user,
    List<Map<String, dynamic>>? recentMovements,
    bool? isSaving,
    String? successMessage,
    String? errorMessage,
  }) {
    return UserDetailLoaded(
      user: user ?? this.user,
      recentMovements: recentMovements ?? this.recentMovements,
      isSaving: isSaving ?? this.isSaving,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        user,
        recentMovements,
        isSaving,
        successMessage,
        errorMessage,
      ];
}

class UserDetailError extends UserDetailState {
  final String message;

  const UserDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
