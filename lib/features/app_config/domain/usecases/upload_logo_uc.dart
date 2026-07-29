import 'package:injectable/injectable.dart';
import 'dart:typed_data';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

@lazySingleton
class UploadLogoUseCase extends UseCase<String, Uint8List> {
  final AppConfigRepository repository;

  UploadLogoUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(Uint8List params) async {
    try {
      final logoUrl = await repository.uploadBusinessLogo(params);
      return right(logoUrl);
    } catch (e) {
      return left(Failure.from(e));
    }
  }
}
