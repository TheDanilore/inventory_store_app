import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';

enum AuthStatus { initial, unauthenticated, authenticated, error }

class AuthState extends Equatable {
  final AuthStatus authStatus;
  final ViewState viewState;
  final UserEntity? currentUser;
  final String? errorMessage;
  final bool isLoginMode;

  const AuthState({
    this.authStatus = AuthStatus.initial,
    this.viewState = ViewState.initial,
    this.currentUser,
    this.errorMessage,
    this.isLoginMode = true,
  });

  AuthState copyWith({
    AuthStatus? authStatus,
    ViewState? viewState,
    UserEntity? currentUser,
    String? errorMessage,
    bool? isLoginMode,
    bool clearErrorMessage = false,
  }) {
    return AuthState(
      authStatus: authStatus ?? this.authStatus,
      viewState: viewState ?? this.viewState,
      currentUser: currentUser ?? this.currentUser,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isLoginMode: isLoginMode ?? this.isLoginMode,
    );
  }

  @override
  List<Object?> get props => [
    authStatus,
    viewState,
    currentUser,
    errorMessage,
    isLoginMode,
  ];
}
