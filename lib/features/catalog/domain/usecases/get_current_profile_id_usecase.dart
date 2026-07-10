import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/get_current_user_uc.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';

@lazySingleton
class GetCurrentProfileIdUseCase {
  final GetCurrentUserUseCase getCurrentUserUC;

  GetCurrentProfileIdUseCase(this.getCurrentUserUC);

  Future<Either<Failure, String?>> call() async {
    final result = await getCurrentUserUC(NoParams());
    return result.map((user) => user.id);
  }
}
