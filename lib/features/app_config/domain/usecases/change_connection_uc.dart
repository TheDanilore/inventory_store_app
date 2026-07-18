import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

class ChangeConnectionParams {
  final String url;
  final String key;
  const ChangeConnectionParams({required this.url, required this.key});
}

@injectable
class ChangeConnectionUseCase implements UseCase<void, ChangeConnectionParams> {
  final AppConfigRepository repository;
  ChangeConnectionUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ChangeConnectionParams params) async {
    try {
      await repository.changeConnection(params.url, params.key);
      return right(null);
    } catch (e) {
      return left(Failure.from(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
