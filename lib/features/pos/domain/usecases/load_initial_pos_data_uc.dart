import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/pos_repository.dart';

class LoadInitialPosDataParams {
  final bool forceRefresh;
  const LoadInitialPosDataParams({this.forceRefresh = false});
}

/// Caso de uso para cargar los datos iniciales necesarios para arrancar el POS.
class LoadInitialPosDataUseCase extends UseCase<PosInitData, LoadInitialPosDataParams> {
  final PosRepository repository;

  LoadInitialPosDataUseCase(this.repository);

  @override
  Future<Either<Failure, PosInitData>> call(LoadInitialPosDataParams params) async {
    try {
      final data = await repository.loadInitialData(forceRefresh: params.forceRefresh);
      return right(data);
    } catch (e) {
      return left(Failure.from(e));
    }
  }
}
