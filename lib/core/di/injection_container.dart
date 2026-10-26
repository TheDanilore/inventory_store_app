import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/di/injection_container.config.dart';
import 'package:inventory_store_app/core/localization/bloc/locale_cubit.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/system_diagnostics_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/data/datasources/inventory_alert_source_impl.dart';
import 'package:inventory_store_app/features/main_navigation/domain/entities/inventory_alert_rules.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_cubit.dart';
import 'package:inventory_store_app/features/roles/data/repositories_impl/roles_repository_impl.dart';
import 'package:inventory_store_app/features/roles/domain/repositories/roles_repository.dart';
import 'package:inventory_store_app/features/roles/presentation/bloc/roles_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
// Main DI Container Initializer
void initDI([SharedPreferences? prefs]) {
  sl.init();
  if (prefs != null && !sl.isRegistered<SharedPreferences>()) {
    sl.registerSingleton<SharedPreferences>(prefs);
  }
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
  if (!sl.isRegistered<InventoryAlertSource>()) {
    sl.registerLazySingleton<InventoryAlertSource>(
      () => InventoryAlertSourceImpl(sl<SupabaseClient>()),
    );
  }
  if (!sl.isRegistered<NotificationsCubit>()) {
    sl.registerFactory<NotificationsCubit>(
      () => NotificationsCubit(
        source: sl<InventoryAlertSource>(),
        prefs:
            sl.isRegistered<SharedPreferences>()
                ? sl<SharedPreferences>()
                : null,
      ),
    );
  }
  if (!sl.isRegistered<SystemDiagnosticsCubit>()) {
    sl.registerLazySingleton<SystemDiagnosticsCubit>(
      () => SystemDiagnosticsCubit(),
    );
  }
}
