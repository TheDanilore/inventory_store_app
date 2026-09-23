import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/change_password_uc.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/delete_account_uc.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/get_current_user_uc.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/login_with_email_uc.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/logout_uc.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/register_uc.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/reset_password_uc.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/update_profile_uc.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';

@lazySingleton
class AuthCubit extends Cubit<AuthState> {
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final LoginWithEmailUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final ResetPasswordUseCase resetPasswordUseCase;
  final ChangePasswordUseCase changePasswordUseCase;
  final DeleteAccountUseCase deleteAccountUseCase;
  final UpdateProfileUseCase updateProfileUseCase;

  bool _isCheckingSession = false;

  AuthCubit({
    required this.getCurrentUserUseCase,
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.resetPasswordUseCase,
    required this.changePasswordUseCase,
    required this.deleteAccountUseCase,
    required this.updateProfileUseCase,
  }) : super(const AuthState());

  void toggleMode() {
    emit(state.copyWith(isLoginMode: !state.isLoginMode));
  }

  Future<void> checkSession({bool force = false}) async {
    if (_isCheckingSession && !force) {
      LoggerService.d('Verificación de sesión omitida: ya en curso', tag: 'AuthCubit');
      return;
    }
    _isCheckingSession = true;
    LoggerService.d('Iniciando verificación de sesión de usuario...', tag: 'AuthCubit');

    try {
      final result = await getCurrentUserUseCase(const NoParams());

      result.fold(
        (failure) {
          LoggerService.w(
            'Sesión no activa o fallida: ${failure.message} (${failure.runtimeType})',
            tag: 'AuthCubit',
          );
          if (failure is NetworkFailure || failure is ServerFailure) {
            emit(
              state.copyWith(
                authStatus: AuthStatus.error,
                errorMessage: failure.message,
              ),
            );
          } else {
            emit(
              state.copyWith(
                authStatus: AuthStatus.unauthenticated,
                errorMessage: failure.message,
              ),
            );
          }
        },
        (user) {
          LoggerService.i(
            'Sesión activa detectada: ${user.fullName} (${user.role})',
            tag: 'AuthCubit',
          );
          emit(
            state.copyWith(
              authStatus: AuthStatus.authenticated,
              currentUser: user,
              clearErrorMessage: true,
            ),
          );
        },
      );
    } catch (e, st) {
      LoggerService.e(
        'Excepción no controlada al verificar sesión',
        tag: 'AuthCubit',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          authStatus: AuthStatus.unauthenticated,
          errorMessage: 'Error al verificar sesión.',
        ),
      );
    } finally {
      _isCheckingSession = false;
    }
  }

  Future<void> login(String email, String password) async {
    emit(state.copyWith(viewState: ViewState.loading, clearErrorMessage: true));

    final result = await loginUseCase(
      LoginParams(email: email, password: password),
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            viewState: ViewState.error,
            errorMessage: failure.message,
          ),
        );
      },
      (user) {
        emit(
          state.copyWith(
            viewState: ViewState.success,
            authStatus: AuthStatus.authenticated,
            currentUser: user,
          ),
        );
      },
    );
  }

  Future<void> register(String email, String password, String fullName) async {
    emit(state.copyWith(viewState: ViewState.loading, clearErrorMessage: true));

    final result = await registerUseCase(
      RegisterParams(email: email, password: password, fullName: fullName),
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            viewState: ViewState.error,
            errorMessage: failure.message,
          ),
        );
      },
      (user) {
        emit(
          state.copyWith(
            viewState: ViewState.success,
            authStatus: AuthStatus.authenticated,
            currentUser: user,
          ),
        );
      },
    );
  }

  Future<void> logout() async {
    emit(state.copyWith(viewState: ViewState.loading));
    await logoutUseCase(const NoParams());
    emit(
      const AuthState(
        authStatus: AuthStatus.unauthenticated,
        viewState: ViewState.initial,
      ),
    );
  }

  Future<String?> resetPassword(String email) async {
    emit(state.copyWith(viewState: ViewState.loading, clearErrorMessage: true));
    final result = await resetPasswordUseCase(email);
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            viewState: ViewState.error,
            errorMessage: failure.message,
          ),
        );
        return failure.message;
      },
      (_) {
        emit(state.copyWith(viewState: ViewState.initial));
        return null;
      },
    );
  }

  Future<bool> changePassword(String newPassword) async {
    emit(state.copyWith(viewState: ViewState.loading, clearErrorMessage: true));
    final result = await changePasswordUseCase(newPassword);
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            viewState: ViewState.error,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) {
        emit(state.copyWith(viewState: ViewState.success));
        return true;
      },
    );
  }

  Future<bool> deleteAccount(String password) async {
    emit(state.copyWith(viewState: ViewState.loading, clearErrorMessage: true));
    final result = await deleteAccountUseCase(password);
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            viewState: ViewState.error,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) {
        emit(const AuthState(authStatus: AuthStatus.unauthenticated));
        return true;
      },
    );
  }

  Future<bool> updateProfile(UserEntity user, {Uint8List? imageBytes}) async {
    emit(state.copyWith(viewState: ViewState.loading, clearErrorMessage: true));
    final result = await updateProfileUseCase(
      UpdateProfileParams(user: user, imageBytes: imageBytes),
    );
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            viewState: ViewState.error,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (updatedUser) {
        emit(
          state.copyWith(
            viewState: ViewState.success,
            currentUser: updatedUser,
          ),
        );
        return true;
      },
    );
  }
}
