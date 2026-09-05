import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/domain/repositories/users_repository.dart';

@injectable
class ExportUsersCsvUseCase {
  final UsersRepository repository;

  ExportUsersCsvUseCase(this.repository);

  Future<Either<Failure, String>> call({
    required String role,
    required String searchQuery,
    required bool onlyActive,
  }) async {
    final result = await repository.getAllUsers(
      role: role,
      searchQuery: searchQuery,
      onlyActive: onlyActive,
    );

    return await result.match(
      (failure) async => Left(failure),
      (users) async {
        try {
          // Offload the heavy parsing and CSV generation to an Isolate
          final csvString = await compute(_generateCsvString, users);
          return Right(csvString);
        } catch (e) {
          return Left(
            ServerFailure(message: 'Error al procesar el archivo CSV: $e'),
          );
        }
      },
    );
  }
}

// Top-level function for Isolate (compute)
String _generateCsvString(List<UserEntity> users) {
  final roleLabels = {
    'customer': 'Cliente',
    'admin': 'Administrador',
    'employee': 'Empleado',
  };

  final buffer = StringBuffer();
  // BOM UTF-8 for Excel on Windows
  buffer.write('\uFEFF');
  buffer.writeln(
    'ID,Nombre Completo,Correo,Rol,Teléfono,Tipo Doc.,N° Doc.,Saldo Puntos,Estado,Fecha Registro',
  );

  for (final user in users) {
    final row = [
      _escapeCsv(user.id),
      _escapeCsv(user.fullName),
      _escapeCsv(user.email ?? ''),
      _escapeCsv(roleLabels[user.role] ?? user.role),
      _escapeCsv(user.phone ?? ''),
      _escapeCsv(user.documentType),
      _escapeCsv(user.documentNumber ?? ''),
      user.walletBalance.toString(),
      user.isActive ? 'Activo' : 'Inactivo',
      user.createdAt != null
          ? '${user.createdAt!.day.toString().padLeft(2, '0')}/${user.createdAt!.month.toString().padLeft(2, '0')}/${user.createdAt!.year}'
          : '',
    ];
    buffer.writeln(row.join(','));
  }

  return buffer.toString();
}

String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
