import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/users/domain/usecases/create_user_usecase.dart';
import 'package:inventory_store_app/features/users/domain/usecases/update_user_usecase.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_form/user_form_state.dart';

@injectable
class UserFormCubit extends Cubit<UserFormState> {
  final CreateUserUseCase _createUser;
  final UpdateUserUseCase _updateUser;

  UserFormCubit(this._createUser, this._updateUser)
    : super(const UserFormInitial());

  Future<void> saveUser({
    String? id, // If id is provided, we update, else create
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
    required String documentType,
    String? documentNumber,
    required bool isActive,
  }) async {
    emit(const UserFormLoading());

    if (id == null) {
      // Create
      final res = await _createUser(
        email: email,
        password: password,
        role: role,
        fullName: fullName,
        phone: phone,
        documentType: documentType,
        documentNumber: documentNumber,
      );

      res.fold(
        (l) => emit(UserFormError(l.message)),
        (r) => emit(const UserFormSuccess('Usuario creado exitosamente')),
      );
    } else {
      // Update
      final res = await _updateUser(
        id: id,
        fullName: fullName,
        role: role,
        phone: phone,
        documentType: documentType,
        documentNumber: documentNumber,
        isActive: isActive,
        newPassword: password, // if not empty, it is handled inside repo
      );

      res.fold(
        (l) => emit(UserFormError(l.message)),
        (r) => emit(const UserFormSuccess('Usuario actualizado exitosamente')),
      );
    }
  }
}
