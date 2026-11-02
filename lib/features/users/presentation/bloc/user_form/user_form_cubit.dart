import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/users/domain/usecases/create_user_usecase.dart';
import 'package:inventory_store_app/features/users/domain/usecases/update_user_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_active_warehouses_usecase.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_form/user_form_state.dart';

@injectable
class UserFormCubit extends Cubit<UserFormState> {
  final CreateUserUseCase _createUser;
  final UpdateUserUseCase _updateUser;
  final GetActiveWarehousesUseCase _getActiveWarehouses;

  UserFormCubit(this._createUser, this._updateUser, this._getActiveWarehouses)
    : super(const UserFormInitial());

  Future<void> loadWarehouses({bool forceRefresh = false}) async {
    final hasCache = state.warehouses.isNotEmpty;
    if (!hasCache) {
      emit(
        UserFormInitial(
          warehouses: state.warehouses,
          isLoadingWarehouses: true,
        ),
      );
    }

    try {
      final whs = await _getActiveWarehouses(forceRefresh: forceRefresh);
      emit(UserFormInitial(warehouses: whs, isLoadingWarehouses: false));
    } catch (_) {
      emit(
        UserFormInitial(
          warehouses: state.warehouses,
          isLoadingWarehouses: false,
        ),
      );
    }
  }

  Future<void> saveUser({
    String? id,
    required String email,
    required String password,
    required String fullName,
    required String role,
    List<String>? roles,
    String? phone,
    required String documentType,
    String? documentNumber,
    required bool isActive,
    String? warehouseId,
  }) async {
    if (state is UserFormLoading) return;
    final currentWarehouses = state.warehouses;
    emit(UserFormLoading(warehouses: currentWarehouses));

    if (id == null) {
      // Create
      final res = await _createUser(
        email: email,
        password: password,
        role: role,
        roles: roles,
        fullName: fullName,
        phone: phone,
        documentType: documentType,
        documentNumber: documentNumber,
        warehouseId: warehouseId,
      );

      res.fold(
        (l) => emit(UserFormError(l.message, warehouses: currentWarehouses)),
        (r) => emit(const UserFormSuccess('Usuario creado exitosamente')),
      );
    } else {
      // Update
      final res = await _updateUser(
        id: id,
        fullName: fullName,
        role: role,
        roles: roles,
        phone: phone,
        documentType: documentType,
        documentNumber: documentNumber,
        isActive: isActive,
        newPassword: password,
        warehouseId: warehouseId,
      );

      res.fold(
        (l) => emit(UserFormError(l.message, warehouses: currentWarehouses)),
        (r) => emit(const UserFormSuccess('Usuario actualizado exitosamente')),
      );
    }
  }
}
