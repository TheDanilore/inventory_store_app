import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/users/data/models/user_model.dart';
import 'package:inventory_store_app/features/users/domain/repositories/users_repository.dart';
import 'package:inventory_store_app/features/users/domain/usecases/get_user_by_id_usecase.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_detail/user_detail_state.dart';

@injectable
class UserDetailCubit extends Cubit<UserDetailState> {
  final GetUserByIdUseCase _getUserById;
  final UsersRepository _repository;

  UserDetailCubit(this._getUserById, this._repository) : super(const UserDetailInitial());

  Future<void> fetchUser(String id) async {
    emit(const UserDetailLoading());

    final res = await _getUserById(id);

    res.fold(
      (l) => emit(UserDetailError(l.message)),
      (user) async {
        final movRes = await _repository.getRecentMovements(id);
        List<Map<String, dynamic>> movements = [];
        movRes.fold((l) => null, (r) => movements = r);
        emit(UserDetailLoaded(user: user, recentMovements: movements));
      },
    );
  }

  Future<void> adjustPoints(int amount) async {
    if (state is! UserDetailLoaded || amount == 0) return;
    
    final currentState = state as UserDetailLoaded;
    emit(currentState.copyWith(isSaving: true, successMessage: null, errorMessage: null));

    final res = await _repository.adjustPoints(
      userId: currentState.user.id,
      currentBalance: currentState.user.walletBalance,
      amount: amount,
    );

    res.fold(
      (l) {
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: l.message,
        ));
      },
      (newBalance) async {
        // Update user entity
        final updatedUser = UserModel(
          id: currentState.user.id,
          email: currentState.user.email,
          fullName: currentState.user.fullName,
          role: currentState.user.role,
          phone: currentState.user.phone,
          documentType: currentState.user.documentType,
          documentNumber: currentState.user.documentNumber,
          isActive: currentState.user.isActive,
          createdAt: currentState.user.createdAt,
          walletBalance: newBalance,
        );

        // Fetch movements again
        final movRes = await _repository.getRecentMovements(currentState.user.id);
        List<Map<String, dynamic>> movements = currentState.recentMovements;
        movRes.fold((l) => null, (r) => movements = r);

        emit(currentState.copyWith(
          isSaving: false,
          user: updatedUser,
          recentMovements: movements,
          successMessage: 'Saldo actualizado correctamente',
        ));
      },
    );
  }

  void clearMessages() {
    if (state is UserDetailLoaded) {
      final currentState = state as UserDetailLoaded;
      emit(currentState.copyWith(successMessage: null, errorMessage: null));
    }
  }
}
