import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

@injectable
class GetCurrentUserUseCase implements UseCase<UserEntity, NoParams> {
  final AuthRepository repository;
  GetCurrentUserUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(NoParams params) async {
    final result = await repository.getCurrentUser();
    
    return result.fold(
      (failure) async {
        if (failure.message.contains('inactiva')) {
          await repository.logout();
        }
        return left(failure);
      },
      (user) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_cache_full_name_', user.fullName);
          if (user.avatarUrl != null) {
            await prefs.setString('profile_cache_avatar_url_', user.avatarUrl!);
          }
        } catch (_) {}
        return right(user);
      },
    );
  }
}
