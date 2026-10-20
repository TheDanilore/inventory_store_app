import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/di/injection_container.config.dart';
import 'package:inventory_store_app/core/localization/bloc/locale_cubit.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/features/roles/data/repositories_impl/roles_repository_impl.dart';
import 'package:inventory_store_app/features/roles/domain/repositories/roles_repository.dart';
import 'package:inventory_store_app/features/roles/presentation/bloc/roles_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
// Main DI Container Initializer
void initDI() {
  sl.init();
  if (!sl.isRegistered<LocaleCubit>()) {
    sl.registerLazySingleton<LocaleCubit>(() => LocaleCubit());
  }
  if (!sl.isRegistered<ThemeCubit>()) {
    sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit());
  }
  if (!sl.isRegistered<RolesRepository>()) {
    sl.registerLazySingleton<RolesRepository>(
      () => RolesRepositoryImpl(sl<SupabaseClient>()),
    );
  }
  if (!sl.isRegistered<RolesCubit>()) {
    sl.registerFactory<RolesCubit>(() => RolesCubit(sl<RolesRepository>()));
  }
}
