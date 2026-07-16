// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:supabase_flutter/supabase_flutter.dart' as _i454;

import '../../features/app_config/data/repositories_impl/app_config_repository_impl.dart'
    as _i785;
import '../../features/app_config/domain/repositories/app_config_repository.dart'
    as _i257;
import '../../features/app_config/domain/usecases/change_connection_uc.dart'
    as _i286;
import '../../features/app_config/domain/usecases/get_app_settings_uc.dart'
    as _i506;
import '../../features/app_config/domain/usecases/get_business_info_uc.dart'
    as _i868;
import '../../features/app_config/domain/usecases/get_connection_url_uc.dart'
    as _i653;
import '../../features/app_config/domain/usecases/restore_default_connection_uc.dart'
    as _i37;
import '../../features/app_config/domain/usecases/save_business_info_uc.dart'
    as _i702;
import '../../features/app_config/domain/usecases/upload_logo_uc.dart' as _i217;
import '../../features/app_config/presentation/bloc/app_config_cubit.dart'
    as _i556;
import '../../features/auth/data/repositories_impl/auth_repository_impl.dart'
    as _i710;
import '../../features/auth/domain/repositories/auth_repository.dart' as _i787;
import '../../features/auth/domain/usecases/change_password_uc.dart' as _i832;
import '../../features/auth/domain/usecases/delete_account_uc.dart' as _i853;
import '../../features/auth/domain/usecases/get_current_user_uc.dart' as _i813;
import '../../features/auth/domain/usecases/login_with_email_uc.dart' as _i175;
import '../../features/auth/domain/usecases/logout_uc.dart' as _i72;
import '../../features/auth/domain/usecases/register_uc.dart' as _i182;
import '../../features/auth/domain/usecases/reset_password_uc.dart' as _i878;
import '../../features/auth/domain/usecases/update_profile_uc.dart' as _i282;
import '../../features/auth/presentation/bloc/auth_cubit.dart' as _i52;
import '../../features/catalog/data/repositories_impl/catalog_search_repository_impl.dart'
    as _i930;
import '../../features/catalog/data/repositories_impl/categories_repository_impl.dart'
    as _i208;
import '../../features/catalog/data/repositories_impl/ingredients_repository_impl.dart'
    as _i475;
import '../../features/catalog/data/repositories_impl/products_repository_impl.dart'
    as _i215;
import '../../features/catalog/domain/repositories/catalog_search_repository.dart'
    as _i540;
import '../../features/catalog/domain/repositories/categories_repository.dart'
    as _i1018;
import '../../features/catalog/domain/repositories/ingredients_repository.dart'
    as _i850;
import '../../features/catalog/domain/repositories/products_repository.dart'
    as _i570;
import '../../features/catalog/domain/usecases/catalog_attribute_mutations_uc.dart'
    as _i382;
import '../../features/catalog/domain/usecases/catalog_category_mutations_uc.dart'
    as _i110;
import '../../features/catalog/domain/usecases/catalog_form_mutations_uc.dart'
    as _i1067;
import '../../features/catalog/domain/usecases/catalog_image_ucs.dart'
    as _i1014;
import '../../features/catalog/domain/usecases/catalog_ingredient_mutations_uc.dart'
    as _i538;
import '../../features/catalog/domain/usecases/catalog_ingredient_ucs.dart'
    as _i597;
import '../../features/catalog/domain/usecases/catalog_variant_ucs.dart'
    as _i929;
import '../../features/catalog/domain/usecases/check_wishlist_state_usecase.dart'
    as _i44;
import '../../features/catalog/domain/usecases/create_ingredient_uc.dart'
    as _i498;
import '../../features/catalog/domain/usecases/export_catalog_pdf_usecase.dart'
    as _i961;
import '../../features/catalog/domain/usecases/export_product_pdf_usecase.dart'
    as _i967;
import '../../features/catalog/domain/usecases/get_active_products_and_variants_uc.dart'
    as _i753;
import '../../features/catalog/domain/usecases/get_admin_financial_data_usecase.dart'
    as _i713;
import '../../features/catalog/domain/usecases/get_attributes_uc.dart' as _i487;
import '../../features/catalog/domain/usecases/get_categories_uc.dart' as _i700;
import '../../features/catalog/domain/usecases/get_current_profile_id_usecase.dart'
    as _i927;
import '../../features/catalog/domain/usecases/get_product_by_id_uc.dart'
    as _i567;
import '../../features/catalog/domain/usecases/get_product_extra_data_usecase.dart'
    as _i338;
import '../../features/catalog/domain/usecases/get_product_stock_uc.dart'
    as _i958;
import '../../features/catalog/domain/usecases/get_products_uc.dart' as _i222;
import '../../features/catalog/domain/usecases/save_product_usecase.dart'
    as _i1064;
import '../../features/catalog/domain/usecases/toggle_wishlist_usecase.dart'
    as _i839;
import '../../features/catalog/presentation/bloc/admin_catalog_cubit.dart'
    as _i332;
import '../../features/catalog/presentation/bloc/attributes_cubit.dart'
    as _i919;
import '../../features/catalog/presentation/bloc/categories_cubit.dart'
    as _i778;
import '../../features/catalog/presentation/bloc/customer_catalog_cubit.dart'
    as _i162;
import '../../features/catalog/presentation/bloc/ingredients_cubit.dart'
    as _i841;
import '../../features/catalog/presentation/bloc/product_detail_cubit.dart'
    as _i711;
import '../../features/catalog/presentation/bloc/product_form_cubit.dart'
    as _i151;
import '../../features/customers/data/repositories_impl/customer_credits_repository_impl.dart'
    as _i922;
import '../../features/customers/data/repositories_impl/customer_locations_repository_impl.dart'
    as _i429;
import '../../features/customers/data/repositories_impl/customers_repository_impl.dart'
    as _i365;
import '../../features/customers/data/repositories_impl/wishlist_repository_impl.dart'
    as _i243;
import '../../features/customers/domain/repositories/customer_credits_repository.dart'
    as _i4;
import '../../features/customers/domain/repositories/customer_locations_repository.dart'
    as _i557;
import '../../features/customers/domain/repositories/customers_repository.dart'
    as _i875;
import '../../features/customers/domain/repositories/wishlist_repository.dart'
    as _i728;
import '../../features/customers/domain/usecases/customer_credit_ucs.dart'
    as _i580;
import '../../features/customers/domain/usecases/customer_location_ucs.dart'
    as _i263;
import '../../features/customers/domain/usecases/customer_ucs.dart' as _i36;
import '../../features/customers/domain/usecases/export_customers_pdf_usecase.dart'
    as _i1021;
import '../../features/customers/domain/usecases/get_customer_recent_orders_usecase.dart'
    as _i690;
import '../../features/customers/domain/usecases/get_customer_top_products_usecase.dart'
    as _i528;
import '../../features/customers/domain/usecases/wishlist_ucs.dart' as _i600;
import '../../features/customers/presentation/bloc/customer_credit_list_cubit.dart'
    as _i315;
import '../../features/customers/presentation/bloc/customer_credit_movements_cubit.dart'
    as _i1029;
import '../../features/customers/presentation/bloc/customer_credits_cubit.dart'
    as _i1001;
import '../../features/customers/presentation/bloc/customer_detail_cubit.dart'
    as _i685;
import '../../features/customers/presentation/bloc/customer_form_cubit.dart'
    as _i303;
import '../../features/customers/presentation/bloc/customer_locations_cubit.dart'
    as _i38;
import '../../features/customers/presentation/bloc/customer_wishlist_cubit.dart'
    as _i17;
import '../../features/customers/presentation/bloc/customers_cubit.dart'
    as _i482;
import '../../features/customers/presentation/bloc/customers_stats_cubit.dart'
    as _i798;
import '../../features/customers/presentation/bloc/top_customers_cubit.dart'
    as _i205;
import '../../features/dashboard/data/repositories_impl/dashboard_repository_impl.dart'
    as _i583;
import '../../features/dashboard/domain/repositories/dashboard_repository.dart'
    as _i665;
import '../../features/dashboard/domain/usecases/get_critical_batches_usecase.dart'
    as _i622;
import '../../features/dashboard/domain/usecases/get_inventory_metrics_usecase.dart'
    as _i139;
import '../../features/dashboard/domain/usecases/get_sales_metrics_usecase.dart'
    as _i407;
import '../../features/dashboard/presentation/bloc/dashboard_cubit.dart'
    as _i58;
import '../../features/financial/data/repositories_impl/account_movements_repository_impl.dart'
    as _i802;
import '../../features/financial/data/repositories_impl/financial_accounts_repository_impl.dart'
    as _i599;
import '../../features/financial/domain/repositories/account_movements_repository.dart'
    as _i561;
import '../../features/financial/domain/repositories/financial_accounts_repository.dart'
    as _i662;
import '../../features/financial/domain/usecases/get_account_movements_usecase.dart'
    as _i811;
import '../../features/financial/domain/usecases/get_financial_accounts_usecase.dart'
    as _i425;
import '../../features/financial/domain/usecases/save_account_movement_usecase.dart'
    as _i625;
import '../../features/financial/domain/usecases/save_financial_account_usecase.dart'
    as _i57;
import '../../features/financial/domain/usecases/transfer_funds_usecase.dart'
    as _i862;
import '../../features/financial/presentation/bloc/account_movements_cubit.dart'
    as _i915;
import '../../features/financial/presentation/bloc/financial_accounts_cubit.dart'
    as _i679;
import '../../features/inventory/data/repositories_impl/inventory_entries_repository_impl.dart'
    as _i176;
import '../../features/inventory/data/repositories_impl/inventory_exits_repository_impl.dart'
    as _i698;
import '../../features/inventory/data/repositories_impl/inventory_repository_impl.dart'
    as _i1035;
import '../../features/inventory/data/repositories_impl/kardex_repository_impl.dart'
    as _i192;
import '../../features/inventory/data/repositories_impl/warehouses_repository_impl.dart'
    as _i237;
import '../../features/inventory/domain/repositories/inventory_entries_repository.dart'
    as _i74;
import '../../features/inventory/domain/repositories/inventory_exits_repository.dart'
    as _i92;
import '../../features/inventory/domain/repositories/inventory_repository.dart'
    as _i422;
import '../../features/inventory/domain/repositories/kardex_repository.dart'
    as _i269;
import '../../features/inventory/domain/repositories/warehouses_repository.dart'
    as _i317;
import '../../features/inventory/domain/usecases/create_inventory_entry_usecase.dart'
    as _i419;
import '../../features/inventory/domain/usecases/create_inventory_exit_usecase.dart'
    as _i738;
import '../../features/inventory/domain/usecases/export_kardex_pdf_usecase.dart'
    as _i876;
import '../../features/inventory/domain/usecases/get_active_warehouses_exits_usecase.dart'
    as _i160;
import '../../features/inventory/domain/usecases/get_active_warehouses_usecase.dart'
    as _i945;
import '../../features/inventory/domain/usecases/get_batch_metrics_usecase.dart'
    as _i581;
import '../../features/inventory/domain/usecases/get_batches_for_variant_usecase.dart'
    as _i134;
import '../../features/inventory/domain/usecases/get_batches_paginated_usecase.dart'
    as _i544;
import '../../features/inventory/domain/usecases/get_entry_items_usecase.dart'
    as _i150;
import '../../features/inventory/domain/usecases/get_exit_items_usecase.dart'
    as _i441;
import '../../features/inventory/domain/usecases/get_general_stock_metrics_usecase.dart'
    as _i226;
import '../../features/inventory/domain/usecases/get_general_stock_paginated_usecase.dart'
    as _i285;
import '../../features/inventory/domain/usecases/get_inventory_entries_usecase.dart'
    as _i94;
import '../../features/inventory/domain/usecases/get_inventory_exits_usecase.dart'
    as _i136;
import '../../features/inventory/domain/usecases/get_kardex_movements_usecase.dart'
    as _i392;
import '../../features/inventory/domain/usecases/get_warehouses_usecase.dart'
    as _i71;
import '../../features/inventory/domain/usecases/save_warehouse_usecase.dart'
    as _i656;
import '../../features/inventory/domain/usecases/toggle_warehouse_status_usecase.dart'
    as _i275;
import '../../features/inventory/presentation/bloc/inventory_cubit.dart'
    as _i777;
import '../../features/inventory/presentation/bloc/inventory_entries_cubit.dart'
    as _i159;
import '../../features/inventory/presentation/bloc/inventory_entry_form_cubit.dart'
    as _i1033;
import '../../features/inventory/presentation/bloc/inventory_exit_form_cubit.dart'
    as _i962;
import '../../features/inventory/presentation/bloc/inventory_exits_cubit.dart'
    as _i5;
import '../../features/inventory/presentation/bloc/kardex_cubit.dart' as _i712;
import '../../features/inventory/presentation/bloc/warehouses_cubit.dart'
    as _i926;
import '../../features/loyalty/data/repositories_impl/loyalty_repository_impl.dart'
    as _i643;
import '../../features/loyalty/domain/repositories/loyalty_repository.dart'
    as _i747;
import '../../features/loyalty/domain/usecases/claim_daily_checkin_uc.dart'
    as _i380;
import '../../features/loyalty/domain/usecases/get_latest_checkin_uc.dart'
    as _i696;
import '../../features/loyalty/domain/usecases/get_loyalty_profile_uc.dart'
    as _i589;
import '../../features/loyalty/domain/usecases/get_today_checkin_uc.dart'
    as _i893;
import '../../features/loyalty/domain/usecases/get_today_mini_games_uc.dart'
    as _i231;
import '../../features/loyalty/domain/usecases/get_top_customers_uc.dart'
    as _i34;
import '../../features/loyalty/domain/usecases/get_wallet_balance_uc.dart'
    as _i631;
import '../../features/loyalty/domain/usecases/get_wallet_movements_uc.dart'
    as _i829;
import '../../features/loyalty/domain/usecases/record_mini_game_uc.dart'
    as _i626;
import '../../features/loyalty/presentation/bloc/points_cubit.dart' as _i742;
import '../../features/loyalty/presentation/bloc/top_customers_cubit.dart'
    as _i478;
import '../../features/loyalty/presentation/bloc/wallet_cubit.dart' as _i1028;
import '../../features/orders/data/repositories_impl/checkout_repository_impl.dart'
    as _i161;
import '../../features/orders/data/repositories_impl/orders_repository_impl.dart'
    as _i647;
import '../../features/orders/domain/repositories/checkout_repository.dart'
    as _i760;
import '../../features/orders/domain/repositories/orders_repository.dart'
    as _i992;
import '../../features/orders/domain/usecases/cancel_order_uc.dart' as _i534;
import '../../features/orders/domain/usecases/get_customer_orders_uc.dart'
    as _i857;
import '../../features/orders/domain/usecases/get_default_address_uc.dart'
    as _i828;
import '../../features/orders/domain/usecases/get_filtered_orders_uc.dart'
    as _i617;
import '../../features/orders/domain/usecases/get_order_details_uc.dart'
    as _i93;
import '../../features/orders/domain/usecases/get_order_items_uc.dart' as _i812;
import '../../features/orders/domain/usecases/process_checkout_uc.dart'
    as _i446;
import '../../features/orders/domain/usecases/save_order_changes_uc.dart'
    as _i904;
import '../../features/orders/domain/usecases/verify_stock_uc.dart' as _i714;
import '../../features/orders/presentation/bloc/checkout_cubit.dart' as _i602;
import '../../features/orders/presentation/bloc/customer_orders_cubit.dart'
    as _i565;
import '../../features/orders/presentation/bloc/order_detail_cubit.dart'
    as _i39;
import '../../features/purchases/domain/usecases/get_active_suppliers_uc.dart'
    as _i664;
import '../network/network_cubit.dart' as _i11;
import 'register_module.dart' as _i291;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.factory<_i961.ExportCatalogPdfUseCase>(
      () => _i961.ExportCatalogPdfUseCase(),
    );
    gh.factory<_i967.ExportProductPdfUseCase>(
      () => _i967.ExportProductPdfUseCase(),
    );
    gh.lazySingleton<_i454.SupabaseClient>(() => registerModule.supabase);
    gh.lazySingleton<_i11.NetworkCubit>(() => _i11.NetworkCubit());
    gh.lazySingleton<_i1021.ExportCustomersPdfUseCase>(
      () => _i1021.ExportCustomersPdfUseCase(),
    );
    gh.lazySingleton<_i728.WishlistRepository>(
      () => _i243.WishlistRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i269.KardexRepository>(
      () => _i192.KardexRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i787.AuthRepository>(
      () => _i710.AuthRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i662.FinancialAccountsRepository>(
      () => _i599.FinancialAccountsRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i850.IngredientsRepository>(
      () => _i475.IngredientsRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i422.InventoryRepository>(
      () => _i1035.InventoryRepositoryImpl(),
    );
    gh.lazySingleton<_i540.CatalogSearchRepository>(
      () => _i930.CatalogSearchRepositoryImpl(),
    );
    gh.lazySingleton<_i74.InventoryEntriesRepository>(
      () => _i176.InventoryEntriesRepositoryImpl(),
    );
    gh.lazySingleton<_i665.DashboardRepository>(
      () => _i583.DashboardRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i561.AccountMovementsRepository>(
      () => _i802.AccountMovementsRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.factory<_i862.TransferFundsUseCase>(
      () => _i862.TransferFundsUseCase(
        gh<_i561.AccountMovementsRepository>(),
        gh<_i662.FinancialAccountsRepository>(),
      ),
    );
    gh.lazySingleton<_i92.InventoryExitsRepository>(
      () => _i698.InventoryExitsRepositoryImpl(),
    );
    gh.lazySingleton<_i317.WarehousesRepository>(
      () => _i237.WarehousesRepositoryImpl(),
    );
    gh.lazySingleton<_i1018.CategoriesRepository>(
      () => _i208.CategoriesRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i110.DeleteCategoryUC>(
      () => _i110.DeleteCategoryUC(gh<_i1018.CategoriesRepository>()),
    );
    gh.lazySingleton<_i700.GetCategoriesUC>(
      () => _i700.GetCategoriesUC(gh<_i1018.CategoriesRepository>()),
    );
    gh.lazySingleton<_i992.OrdersRepository>(
      () => _i647.OrdersRepositoryImpl(),
    );
    gh.factory<_i753.GetActiveProductsAndVariantsUseCase>(
      () =>
          _i753.GetActiveProductsAndVariantsUseCase(gh<_i454.SupabaseClient>()),
    );
    gh.factory<_i664.GetActiveSuppliersUseCase>(
      () => _i664.GetActiveSuppliersUseCase(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i747.LoyaltyRepository>(
      () => _i643.LoyaltyRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.factory<_i160.GetActiveWarehousesExitsUseCase>(
      () => _i160.GetActiveWarehousesExitsUseCase(
        gh<_i317.WarehousesRepository>(),
      ),
    );
    gh.factory<_i945.GetActiveWarehousesUseCase>(
      () => _i945.GetActiveWarehousesUseCase(gh<_i317.WarehousesRepository>()),
    );
    gh.factory<_i71.GetWarehousesUseCase>(
      () => _i71.GetWarehousesUseCase(gh<_i317.WarehousesRepository>()),
    );
    gh.factory<_i656.SaveWarehouseUseCase>(
      () => _i656.SaveWarehouseUseCase(gh<_i317.WarehousesRepository>()),
    );
    gh.factory<_i275.ToggleWarehouseStatusUseCase>(
      () =>
          _i275.ToggleWarehouseStatusUseCase(gh<_i317.WarehousesRepository>()),
    );
    gh.lazySingleton<_i760.CheckoutRepository>(
      () => _i161.CheckoutRepositoryImpl(),
    );
    gh.lazySingleton<_i557.CustomerLocationsRepository>(
      () => _i429.CustomerLocationsRepositoryImpl(),
    );
    gh.lazySingleton<_i538.UpdateIngredientUC>(
      () => _i538.UpdateIngredientUC(gh<_i850.IngredientsRepository>()),
    );
    gh.lazySingleton<_i538.DeleteIngredientUC>(
      () => _i538.DeleteIngredientUC(gh<_i850.IngredientsRepository>()),
    );
    gh.lazySingleton<_i538.GetIngredientsUC>(
      () => _i538.GetIngredientsUC(gh<_i850.IngredientsRepository>()),
    );
    gh.lazySingleton<_i597.GetProductIngredientsUC>(
      () => _i597.GetProductIngredientsUC(gh<_i850.IngredientsRepository>()),
    );
    gh.lazySingleton<_i597.SearchIngredientsUC>(
      () => _i597.SearchIngredientsUC(gh<_i850.IngredientsRepository>()),
    );
    gh.lazySingleton<_i597.CreateIngredientUC>(
      () => _i597.CreateIngredientUC(gh<_i850.IngredientsRepository>()),
    );
    gh.lazySingleton<_i597.ClearProductIngredientsUC>(
      () => _i597.ClearProductIngredientsUC(gh<_i850.IngredientsRepository>()),
    );
    gh.lazySingleton<_i597.InsertProductIngredientUC>(
      () => _i597.InsertProductIngredientUC(gh<_i850.IngredientsRepository>()),
    );
    gh.lazySingleton<_i498.CreateIngredientUC>(
      () => _i498.CreateIngredientUC(gh<_i850.IngredientsRepository>()),
    );
    gh.lazySingleton<_i570.ProductsRepository>(
      () => _i215.ProductsRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i4.CustomerCreditsRepository>(
      () => _i922.CustomerCreditsRepositoryImpl(),
    );
    gh.lazySingleton<_i875.CustomersRepository>(
      () => _i365.CustomersRepositoryImpl(),
    );
    gh.lazySingleton<_i257.AppConfigRepository>(
      () => _i785.AppConfigRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.factory<_i926.WarehousesCubit>(
      () => _i926.WarehousesCubit(
        getWarehousesUseCase: gh<_i71.GetWarehousesUseCase>(),
        saveWarehouseUseCase: gh<_i656.SaveWarehouseUseCase>(),
        toggleWarehouseStatusUseCase: gh<_i275.ToggleWarehouseStatusUseCase>(),
      ),
    );
    gh.lazySingleton<_i622.GetCriticalBatchesUseCase>(
      () => _i622.GetCriticalBatchesUseCase(gh<_i665.DashboardRepository>()),
    );
    gh.lazySingleton<_i139.GetInventoryMetricsUseCase>(
      () => _i139.GetInventoryMetricsUseCase(gh<_i665.DashboardRepository>()),
    );
    gh.lazySingleton<_i407.GetSalesMetricsUseCase>(
      () => _i407.GetSalesMetricsUseCase(gh<_i665.DashboardRepository>()),
    );
    gh.lazySingleton<_i36.GetCustomersUseCase>(
      () => _i36.GetCustomersUseCase(gh<_i875.CustomersRepository>()),
    );
    gh.lazySingleton<_i36.GetCustomerDetailUseCase>(
      () => _i36.GetCustomerDetailUseCase(gh<_i875.CustomersRepository>()),
    );
    gh.lazySingleton<_i36.GetGlobalStatsUseCase>(
      () => _i36.GetGlobalStatsUseCase(gh<_i875.CustomersRepository>()),
    );
    gh.lazySingleton<_i36.GetTopCustomersUseCase>(
      () => _i36.GetTopCustomersUseCase(gh<_i875.CustomersRepository>()),
    );
    gh.lazySingleton<_i36.CreateCustomerUseCase>(
      () => _i36.CreateCustomerUseCase(gh<_i875.CustomersRepository>()),
    );
    gh.lazySingleton<_i36.UpdateCustomerUseCase>(
      () => _i36.UpdateCustomerUseCase(gh<_i875.CustomersRepository>()),
    );
    gh.lazySingleton<_i36.ToggleCustomerStatusUseCase>(
      () => _i36.ToggleCustomerStatusUseCase(gh<_i875.CustomersRepository>()),
    );
    gh.lazySingleton<_i36.SaveCustomerFullProfileUseCase>(
      () =>
          _i36.SaveCustomerFullProfileUseCase(gh<_i875.CustomersRepository>()),
    );
    gh.lazySingleton<_i690.GetCustomerRecentOrdersUseCase>(
      () =>
          _i690.GetCustomerRecentOrdersUseCase(gh<_i875.CustomersRepository>()),
    );
    gh.lazySingleton<_i528.GetCustomerTopProductsUseCase>(
      () =>
          _i528.GetCustomerTopProductsUseCase(gh<_i875.CustomersRepository>()),
    );
    gh.factory<_i419.CreateInventoryEntryUseCase>(
      () => _i419.CreateInventoryEntryUseCase(
        gh<_i74.InventoryEntriesRepository>(),
      ),
    );
    gh.factory<_i150.GetEntryItemsUseCase>(
      () => _i150.GetEntryItemsUseCase(gh<_i74.InventoryEntriesRepository>()),
    );
    gh.factory<_i94.GetInventoryEntriesUseCase>(
      () => _i94.GetInventoryEntriesUseCase(
        gh<_i74.InventoryEntriesRepository>(),
      ),
    );
    gh.lazySingleton<_i1064.SaveProductUseCase>(
      () => _i1064.SaveProductUseCase(
        gh<_i570.ProductsRepository>(),
        gh<_i850.IngredientsRepository>(),
      ),
    );
    gh.factory<_i876.ExportKardexPdfUseCase>(
      () => _i876.ExportKardexPdfUseCase(gh<_i269.KardexRepository>()),
    );
    gh.factory<_i392.GetKardexMovementsUseCase>(
      () => _i392.GetKardexMovementsUseCase(gh<_i269.KardexRepository>()),
    );
    gh.factory<_i205.TopCustomersCubit>(
      () => _i205.TopCustomersCubit(gh<_i36.GetTopCustomersUseCase>()),
    );
    gh.lazySingleton<_i600.GetWishlistUseCase>(
      () => _i600.GetWishlistUseCase(gh<_i728.WishlistRepository>()),
    );
    gh.lazySingleton<_i600.RemoveFromWishlistUseCase>(
      () => _i600.RemoveFromWishlistUseCase(gh<_i728.WishlistRepository>()),
    );
    gh.factory<_i58.DashboardCubit>(
      () => _i58.DashboardCubit(
        getInventoryMetrics: gh<_i139.GetInventoryMetricsUseCase>(),
        getSalesMetrics: gh<_i407.GetSalesMetricsUseCase>(),
        getCriticalBatches: gh<_i622.GetCriticalBatchesUseCase>(),
      ),
    );
    gh.factory<_i159.InventoryEntriesCubit>(
      () => _i159.InventoryEntriesCubit(
        getInventoryEntries: gh<_i94.GetInventoryEntriesUseCase>(),
        getActiveWarehouses: gh<_i945.GetActiveWarehousesUseCase>(),
      ),
    );
    gh.factory<_i425.GetFinancialAccountsUseCase>(
      () => _i425.GetFinancialAccountsUseCase(
        gh<_i662.FinancialAccountsRepository>(),
      ),
    );
    gh.factory<_i57.SaveFinancialAccountUseCase>(
      () => _i57.SaveFinancialAccountUseCase(
        gh<_i662.FinancialAccountsRepository>(),
      ),
    );
    gh.lazySingleton<_i580.GetCreditAccountsUseCase>(
      () => _i580.GetCreditAccountsUseCase(gh<_i4.CustomerCreditsRepository>()),
    );
    gh.lazySingleton<_i580.GetCreditAccountByCustomerUseCase>(
      () => _i580.GetCreditAccountByCustomerUseCase(
        gh<_i4.CustomerCreditsRepository>(),
      ),
    );
    gh.lazySingleton<_i580.CreateCreditAccountUseCase>(
      () =>
          _i580.CreateCreditAccountUseCase(gh<_i4.CustomerCreditsRepository>()),
    );
    gh.lazySingleton<_i580.UpdateCreditLimitUseCase>(
      () => _i580.UpdateCreditLimitUseCase(gh<_i4.CustomerCreditsRepository>()),
    );
    gh.lazySingleton<_i580.ToggleCreditStatusUseCase>(
      () =>
          _i580.ToggleCreditStatusUseCase(gh<_i4.CustomerCreditsRepository>()),
    );
    gh.lazySingleton<_i580.GetCreditMovementsUseCase>(
      () =>
          _i580.GetCreditMovementsUseCase(gh<_i4.CustomerCreditsRepository>()),
    );
    gh.lazySingleton<_i580.RegisterCreditPaymentUseCase>(
      () => _i580.RegisterCreditPaymentUseCase(
        gh<_i4.CustomerCreditsRepository>(),
      ),
    );
    gh.lazySingleton<_i263.GetCustomerLocationsUseCase>(
      () => _i263.GetCustomerLocationsUseCase(
        gh<_i557.CustomerLocationsRepository>(),
      ),
    );
    gh.lazySingleton<_i263.AddCustomerLocationUseCase>(
      () => _i263.AddCustomerLocationUseCase(
        gh<_i557.CustomerLocationsRepository>(),
      ),
    );
    gh.lazySingleton<_i263.UpdateCustomerLocationUseCase>(
      () => _i263.UpdateCustomerLocationUseCase(
        gh<_i557.CustomerLocationsRepository>(),
      ),
    );
    gh.lazySingleton<_i263.DeleteCustomerLocationUseCase>(
      () => _i263.DeleteCustomerLocationUseCase(
        gh<_i557.CustomerLocationsRepository>(),
      ),
    );
    gh.lazySingleton<_i263.SetDefaultCustomerLocationUseCase>(
      () => _i263.SetDefaultCustomerLocationUseCase(
        gh<_i557.CustomerLocationsRepository>(),
      ),
    );
    gh.factory<_i841.IngredientsCubit>(
      () => _i841.IngredientsCubit(
        getIngredientsUC: gh<_i538.GetIngredientsUC>(),
        createIngredientUC: gh<_i498.CreateIngredientUC>(),
        updateIngredientUC: gh<_i538.UpdateIngredientUC>(),
        deleteIngredientUC: gh<_i538.DeleteIngredientUC>(),
      ),
    );
    gh.lazySingleton<_i506.GetAppSettingsUseCase>(
      () => _i506.GetAppSettingsUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.lazySingleton<_i868.GetBusinessInfoUseCase>(
      () => _i868.GetBusinessInfoUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.lazySingleton<_i653.GetConnectionUrlUseCase>(
      () => _i653.GetConnectionUrlUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.lazySingleton<_i702.SaveBusinessInfoUseCase>(
      () => _i702.SaveBusinessInfoUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.lazySingleton<_i217.UploadLogoUseCase>(
      () => _i217.UploadLogoUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.factory<_i286.ChangeConnectionUseCase>(
      () => _i286.ChangeConnectionUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.factory<_i37.RestoreDefaultConnectionUseCase>(
      () =>
          _i37.RestoreDefaultConnectionUseCase(gh<_i257.AppConfigRepository>()),
    );
    gh.factory<_i303.CustomerFormCubit>(
      () => _i303.CustomerFormCubit(
        gh<_i36.SaveCustomerFullProfileUseCase>(),
        gh<_i580.GetCreditAccountByCustomerUseCase>(),
      ),
    );
    gh.factory<_i832.ChangePasswordUseCase>(
      () => _i832.ChangePasswordUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i853.DeleteAccountUseCase>(
      () => _i853.DeleteAccountUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i813.GetCurrentUserUseCase>(
      () => _i813.GetCurrentUserUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i175.LoginWithEmailUseCase>(
      () => _i175.LoginWithEmailUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i72.LogoutUseCase>(
      () => _i72.LogoutUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i182.RegisterUseCase>(
      () => _i182.RegisterUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i878.ResetPasswordUseCase>(
      () => _i878.ResetPasswordUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i282.UpdateProfileUseCase>(
      () => _i282.UpdateProfileUseCase(gh<_i787.AuthRepository>()),
    );
    gh.factory<_i1029.CustomerCreditMovementsCubit>(
      () => _i1029.CustomerCreditMovementsCubit(
        gh<_i580.GetCreditMovementsUseCase>(),
      ),
    );
    gh.factory<_i738.CreateInventoryExitUseCase>(
      () =>
          _i738.CreateInventoryExitUseCase(gh<_i92.InventoryExitsRepository>()),
    );
    gh.factory<_i134.GetBatchesForVariantUseCase>(
      () => _i134.GetBatchesForVariantUseCase(
        gh<_i92.InventoryExitsRepository>(),
      ),
    );
    gh.factory<_i441.GetExitItemsUseCase>(
      () => _i441.GetExitItemsUseCase(gh<_i92.InventoryExitsRepository>()),
    );
    gh.factory<_i136.GetInventoryExitsUseCase>(
      () => _i136.GetInventoryExitsUseCase(gh<_i92.InventoryExitsRepository>()),
    );
    gh.factory<_i798.CustomersStatsCubit>(
      () => _i798.CustomersStatsCubit(gh<_i36.GetGlobalStatsUseCase>()),
    );
    gh.factory<_i581.GetBatchMetricsUseCase>(
      () => _i581.GetBatchMetricsUseCase(gh<_i422.InventoryRepository>()),
    );
    gh.factory<_i544.GetBatchesPaginatedUseCase>(
      () => _i544.GetBatchesPaginatedUseCase(gh<_i422.InventoryRepository>()),
    );
    gh.factory<_i226.GetGeneralStockMetricsUseCase>(
      () =>
          _i226.GetGeneralStockMetricsUseCase(gh<_i422.InventoryRepository>()),
    );
    gh.factory<_i285.GetGeneralStockPaginatedUseCase>(
      () => _i285.GetGeneralStockPaginatedUseCase(
        gh<_i422.InventoryRepository>(),
      ),
    );
    gh.lazySingleton<_i380.ClaimDailyCheckinUC>(
      () => _i380.ClaimDailyCheckinUC(gh<_i747.LoyaltyRepository>()),
    );
    gh.lazySingleton<_i696.GetLatestCheckinUC>(
      () => _i696.GetLatestCheckinUC(gh<_i747.LoyaltyRepository>()),
    );
    gh.lazySingleton<_i589.GetLoyaltyProfileUC>(
      () => _i589.GetLoyaltyProfileUC(gh<_i747.LoyaltyRepository>()),
    );
    gh.lazySingleton<_i893.GetTodayCheckinUC>(
      () => _i893.GetTodayCheckinUC(gh<_i747.LoyaltyRepository>()),
    );
    gh.lazySingleton<_i231.GetTodayMiniGamesUC>(
      () => _i231.GetTodayMiniGamesUC(gh<_i747.LoyaltyRepository>()),
    );
    gh.lazySingleton<_i34.GetTopCustomersUC>(
      () => _i34.GetTopCustomersUC(gh<_i747.LoyaltyRepository>()),
    );
    gh.lazySingleton<_i631.GetWalletBalanceUC>(
      () => _i631.GetWalletBalanceUC(gh<_i747.LoyaltyRepository>()),
    );
    gh.lazySingleton<_i829.GetWalletMovementsUC>(
      () => _i829.GetWalletMovementsUC(gh<_i747.LoyaltyRepository>()),
    );
    gh.lazySingleton<_i626.RecordMiniGameUC>(
      () => _i626.RecordMiniGameUC(gh<_i747.LoyaltyRepository>()),
    );
    gh.factory<_i1001.CustomerCreditsCubit>(
      () => _i1001.CustomerCreditsCubit(
        gh<_i580.GetCreditAccountByCustomerUseCase>(),
        gh<_i580.GetCreditMovementsUseCase>(),
        gh<_i580.CreateCreditAccountUseCase>(),
        gh<_i580.RegisterCreditPaymentUseCase>(),
      ),
    );
    gh.factory<_i811.GetAccountMovementsUseCase>(
      () => _i811.GetAccountMovementsUseCase(
        gh<_i561.AccountMovementsRepository>(),
      ),
    );
    gh.factory<_i625.SaveAccountMovementUseCase>(
      () => _i625.SaveAccountMovementUseCase(
        gh<_i561.AccountMovementsRepository>(),
      ),
    );
    gh.factory<_i962.InventoryExitFormCubit>(
      () => _i962.InventoryExitFormCubit(
        getActiveWarehousesUseCase: gh<_i160.GetActiveWarehousesExitsUseCase>(),
        getActiveProductsAndVariantsUseCase:
            gh<_i753.GetActiveProductsAndVariantsUseCase>(),
        createInventoryExitUseCase: gh<_i738.CreateInventoryExitUseCase>(),
      ),
    );
    gh.factory<_i685.CustomerDetailCubit>(
      () => _i685.CustomerDetailCubit(
        gh<_i36.GetCustomerDetailUseCase>(),
        gh<_i36.UpdateCustomerUseCase>(),
        gh<_i690.GetCustomerRecentOrdersUseCase>(),
        gh<_i528.GetCustomerTopProductsUseCase>(),
        gh<_i263.AddCustomerLocationUseCase>(),
        gh<_i263.UpdateCustomerLocationUseCase>(),
        gh<_i263.DeleteCustomerLocationUseCase>(),
      ),
    );
    gh.factory<_i915.AccountMovementsCubit>(
      () => _i915.AccountMovementsCubit(
        getMovements: gh<_i811.GetAccountMovementsUseCase>(),
        saveMovement: gh<_i625.SaveAccountMovementUseCase>(),
        transferFunds: gh<_i862.TransferFundsUseCase>(),
        getCurrentUser: gh<_i813.GetCurrentUserUseCase>(),
      ),
    );
    gh.factory<_i712.KardexCubit>(
      () => _i712.KardexCubit(
        getKardexMovements: gh<_i392.GetKardexMovementsUseCase>(),
        exportKardexPdf: gh<_i876.ExportKardexPdfUseCase>(),
      ),
    );
    gh.lazySingleton<_i382.CreateAttributeUC>(
      () => _i382.CreateAttributeUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i382.UpdateAttributeUC>(
      () => _i382.UpdateAttributeUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i382.DeleteAttributeUC>(
      () => _i382.DeleteAttributeUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i382.CreateAttributeValueUC>(
      () => _i382.CreateAttributeValueUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i382.UpdateAttributeValueUC>(
      () => _i382.UpdateAttributeValueUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i382.DeleteAttributeValueUC>(
      () => _i382.DeleteAttributeValueUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i1067.SaveProductMasterUC>(
      () => _i1067.SaveProductMasterUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i1067.SaveVariantAttributesUC>(
      () => _i1067.SaveVariantAttributesUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i1067.GetFirstVariantIdUC>(
      () => _i1067.GetFirstVariantIdUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i1067.SetProductActiveUC>(
      () => _i1067.SetProductActiveUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i1067.ClearCatalogCacheUC>(
      () => _i1067.ClearCatalogCacheUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i1014.GetProductImagesUC>(
      () => _i1014.GetProductImagesUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i1014.UploadImageToStorageUC>(
      () => _i1014.UploadImageToStorageUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i1014.DeleteProductImageUC>(
      () => _i1014.DeleteProductImageUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i1014.SyncProductImagesUC>(
      () => _i1014.SyncProductImagesUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i1014.ClearVariantImagesUC>(
      () => _i1014.ClearVariantImagesUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i929.GetVariantByIdUC>(
      () => _i929.GetVariantByIdUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i929.GetStockByVariantUC>(
      () => _i929.GetStockByVariantUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i929.GetVariantsDraftsUC>(
      () => _i929.GetVariantsDraftsUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i929.DeleteVariantUC>(
      () => _i929.DeleteVariantUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i929.DeactivateVariantUC>(
      () => _i929.DeactivateVariantUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i929.HasVariantSalesUC>(
      () => _i929.HasVariantSalesUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i44.CheckWishlistStateUseCase>(
      () => _i44.CheckWishlistStateUseCase(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i713.GetAdminFinancialDataUseCase>(
      () => _i713.GetAdminFinancialDataUseCase(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i487.GetAttributesUC>(
      () => _i487.GetAttributesUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i567.GetProductByIdUC>(
      () => _i567.GetProductByIdUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i338.GetProductExtraDataUseCase>(
      () => _i338.GetProductExtraDataUseCase(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i958.GetProductStockUC>(
      () => _i958.GetProductStockUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i222.GetProductsUC>(
      () => _i222.GetProductsUC(gh<_i570.ProductsRepository>()),
    );
    gh.lazySingleton<_i839.ToggleWishlistUseCase>(
      () => _i839.ToggleWishlistUseCase(gh<_i570.ProductsRepository>()),
    );
    gh.factory<_i828.GetDefaultAddressUc>(
      () => _i828.GetDefaultAddressUc(gh<_i760.CheckoutRepository>()),
    );
    gh.factory<_i446.ProcessCheckoutUc>(
      () => _i446.ProcessCheckoutUc(gh<_i760.CheckoutRepository>()),
    );
    gh.factory<_i714.VerifyStockUc>(
      () => _i714.VerifyStockUc(gh<_i760.CheckoutRepository>()),
    );
    gh.factory<_i556.AppConfigCubit>(
      () => _i556.AppConfigCubit(
        getAppSettingsUseCase: gh<_i506.GetAppSettingsUseCase>(),
        getBusinessInfoUseCase: gh<_i868.GetBusinessInfoUseCase>(),
        saveBusinessInfoUseCase: gh<_i702.SaveBusinessInfoUseCase>(),
        uploadLogoUseCase: gh<_i217.UploadLogoUseCase>(),
        changeConnectionUseCase: gh<_i286.ChangeConnectionUseCase>(),
        restoreDefaultConnectionUseCase:
            gh<_i37.RestoreDefaultConnectionUseCase>(),
        getConnectionUrlUseCase: gh<_i653.GetConnectionUrlUseCase>(),
      ),
    );
    gh.factory<_i857.GetCustomerOrdersUc>(
      () => _i857.GetCustomerOrdersUc(gh<_i992.OrdersRepository>()),
    );
    gh.factory<_i93.GetOrderDetailsUc>(
      () => _i93.GetOrderDetailsUc(gh<_i992.OrdersRepository>()),
    );
    gh.lazySingleton<_i534.CancelOrderUc>(
      () => _i534.CancelOrderUc(gh<_i992.OrdersRepository>()),
    );
    gh.lazySingleton<_i617.GetFilteredOrdersUc>(
      () => _i617.GetFilteredOrdersUc(gh<_i992.OrdersRepository>()),
    );
    gh.lazySingleton<_i812.GetOrderItemsUc>(
      () => _i812.GetOrderItemsUc(gh<_i992.OrdersRepository>()),
    );
    gh.lazySingleton<_i904.SaveOrderChangesUc>(
      () => _i904.SaveOrderChangesUc(gh<_i992.OrdersRepository>()),
    );
    gh.factory<_i679.FinancialAccountsCubit>(
      () => _i679.FinancialAccountsCubit(
        getAccounts: gh<_i425.GetFinancialAccountsUseCase>(),
        saveAccount: gh<_i57.SaveFinancialAccountUseCase>(),
      ),
    );
    gh.factory<_i38.CustomerLocationsCubit>(
      () => _i38.CustomerLocationsCubit(
        gh<_i263.GetCustomerLocationsUseCase>(),
        gh<_i263.AddCustomerLocationUseCase>(),
        gh<_i263.UpdateCustomerLocationUseCase>(),
        gh<_i263.DeleteCustomerLocationUseCase>(),
        gh<_i263.SetDefaultCustomerLocationUseCase>(),
      ),
    );
    gh.factory<_i315.CustomerCreditListCubit>(
      () => _i315.CustomerCreditListCubit(gh<_i580.GetCreditAccountsUseCase>()),
    );
    gh.factory<_i332.AdminCatalogCubit>(
      () => _i332.AdminCatalogCubit(
        getCategoriesUC: gh<_i700.GetCategoriesUC>(),
        getProductsUC: gh<_i222.GetProductsUC>(),
        setProductActiveUC: gh<_i1067.SetProductActiveUC>(),
        clearCatalogCacheUC: gh<_i1067.ClearCatalogCacheUC>(),
        exportCatalogPdfUC: gh<_i961.ExportCatalogPdfUseCase>(),
        getProductStockUC: gh<_i958.GetProductStockUC>(),
      ),
    );
    gh.factory<_i482.CustomersCubit>(
      () => _i482.CustomersCubit(
        gh<_i36.GetCustomersUseCase>(),
        gh<_i1021.ExportCustomersPdfUseCase>(),
      ),
    );
    gh.factory<_i52.AuthCubit>(
      () => _i52.AuthCubit(
        getCurrentUserUseCase: gh<_i813.GetCurrentUserUseCase>(),
        loginUseCase: gh<_i175.LoginWithEmailUseCase>(),
        registerUseCase: gh<_i182.RegisterUseCase>(),
        logoutUseCase: gh<_i72.LogoutUseCase>(),
        resetPasswordUseCase: gh<_i878.ResetPasswordUseCase>(),
        changePasswordUseCase: gh<_i832.ChangePasswordUseCase>(),
        deleteAccountUseCase: gh<_i853.DeleteAccountUseCase>(),
        updateProfileUseCase: gh<_i282.UpdateProfileUseCase>(),
      ),
    );
    gh.lazySingleton<_i927.GetCurrentProfileIdUseCase>(
      () => _i927.GetCurrentProfileIdUseCase(gh<_i813.GetCurrentUserUseCase>()),
    );
    gh.factory<_i478.TopCustomersCubit>(
      () => _i478.TopCustomersCubit(
        getTopCustomersUC: gh<_i34.GetTopCustomersUC>(),
      ),
    );
    gh.factory<_i1028.WalletCubit>(
      () => _i1028.WalletCubit(
        getWalletBalanceUC: gh<_i631.GetWalletBalanceUC>(),
        supabase: gh<_i454.SupabaseClient>(),
      ),
    );
    gh.factory<_i1033.InventoryEntryFormCubit>(
      () => _i1033.InventoryEntryFormCubit(
        getActiveWarehouses: gh<_i945.GetActiveWarehousesUseCase>(),
        getActiveSuppliers: gh<_i664.GetActiveSuppliersUseCase>(),
        getActiveAccounts: gh<_i425.GetFinancialAccountsUseCase>(),
        createInventoryEntry: gh<_i419.CreateInventoryEntryUseCase>(),
      ),
    );
    gh.lazySingleton<_i110.CreateCategoryUC>(
      () => _i110.CreateCategoryUC(
        gh<_i1018.CategoriesRepository>(),
        gh<_i927.GetCurrentProfileIdUseCase>(),
      ),
    );
    gh.lazySingleton<_i110.UpdateCategoryUC>(
      () => _i110.UpdateCategoryUC(
        gh<_i1018.CategoriesRepository>(),
        gh<_i927.GetCurrentProfileIdUseCase>(),
      ),
    );
    gh.factory<_i777.InventoryCubit>(
      () => _i777.InventoryCubit(
        getGeneralStockMetrics: gh<_i226.GetGeneralStockMetricsUseCase>(),
        getCategories: gh<_i700.GetCategoriesUC>(),
        getGeneralStockPaginated: gh<_i285.GetGeneralStockPaginatedUseCase>(),
        getBatchMetrics: gh<_i581.GetBatchMetricsUseCase>(),
        getBatchesPaginated: gh<_i544.GetBatchesPaginatedUseCase>(),
      ),
    );
    gh.factory<_i742.PointsCubit>(
      () => _i742.PointsCubit(
        getLoyaltyProfileUC: gh<_i589.GetLoyaltyProfileUC>(),
        getTodayCheckinUC: gh<_i893.GetTodayCheckinUC>(),
        getLatestCheckinUC: gh<_i696.GetLatestCheckinUC>(),
        getTodayMiniGamesUC: gh<_i231.GetTodayMiniGamesUC>(),
        getWalletMovementsUC: gh<_i829.GetWalletMovementsUC>(),
        claimDailyCheckinUC: gh<_i380.ClaimDailyCheckinUC>(),
        recordMiniGameUC: gh<_i626.RecordMiniGameUC>(),
        supabase: gh<_i454.SupabaseClient>(),
      ),
    );
    gh.factory<_i5.InventoryExitsCubit>(
      () => _i5.InventoryExitsCubit(
        getExitsUseCase: gh<_i136.GetInventoryExitsUseCase>(),
      ),
    );
    gh.factory<_i919.AttributesCubit>(
      () => _i919.AttributesCubit(
        getAttributesUC: gh<_i487.GetAttributesUC>(),
        createAttributeUC: gh<_i382.CreateAttributeUC>(),
        updateAttributeUC: gh<_i382.UpdateAttributeUC>(),
        deleteAttributeUC: gh<_i382.DeleteAttributeUC>(),
        createAttributeValueUC: gh<_i382.CreateAttributeValueUC>(),
        updateAttributeValueUC: gh<_i382.UpdateAttributeValueUC>(),
        deleteAttributeValueUC: gh<_i382.DeleteAttributeValueUC>(),
      ),
    );
    gh.factory<_i778.CategoriesCubit>(
      () => _i778.CategoriesCubit(
        getCategoriesUC: gh<_i700.GetCategoriesUC>(),
        createCategoryUC: gh<_i110.CreateCategoryUC>(),
        updateCategoryUC: gh<_i110.UpdateCategoryUC>(),
        deleteCategoryUC: gh<_i110.DeleteCategoryUC>(),
      ),
    );
    gh.factory<_i39.OrderDetailCubit>(
      () => _i39.OrderDetailCubit(
        getOrderDetailsUc: gh<_i93.GetOrderDetailsUc>(),
        saveOrderChangesUc: gh<_i904.SaveOrderChangesUc>(),
      ),
    );
    gh.lazySingleton<_i1067.CatalogFormMutationsUC>(
      () => _i1067.CatalogFormMutationsUC(
        gh<_i570.ProductsRepository>(),
        gh<_i927.GetCurrentProfileIdUseCase>(),
      ),
    );
    gh.lazySingleton<_i1067.SaveVariantUC>(
      () => _i1067.SaveVariantUC(
        gh<_i570.ProductsRepository>(),
        gh<_i927.GetCurrentProfileIdUseCase>(),
      ),
    );
    gh.factory<_i162.CustomerCatalogCubit>(
      () => _i162.CustomerCatalogCubit(
        getCategoriesUC: gh<_i700.GetCategoriesUC>(),
        getProductsUC: gh<_i222.GetProductsUC>(),
        getProductStockUC: gh<_i958.GetProductStockUC>(),
        catalogRepository: gh<_i540.CatalogSearchRepository>(),
      ),
    );
    gh.factory<_i602.CheckoutCubit>(
      () => _i602.CheckoutCubit(
        getDefaultAddressUc: gh<_i828.GetDefaultAddressUc>(),
        verifyStockUc: gh<_i714.VerifyStockUc>(),
        processCheckoutUc: gh<_i446.ProcessCheckoutUc>(),
      ),
    );
    gh.factory<_i17.CustomerWishlistCubit>(
      () => _i17.CustomerWishlistCubit(
        gh<_i927.GetCurrentProfileIdUseCase>(),
        gh<_i600.GetWishlistUseCase>(),
        gh<_i600.RemoveFromWishlistUseCase>(),
      ),
    );
    gh.factory<_i565.CustomerOrdersCubit>(
      () => _i565.CustomerOrdersCubit(
        getCustomerOrdersUc: gh<_i857.GetCustomerOrdersUc>(),
      ),
    );
    gh.factory<_i711.ProductDetailCubit>(
      () => _i711.ProductDetailCubit(
        getExtraData: gh<_i338.GetProductExtraDataUseCase>(),
        getAdminData: gh<_i713.GetAdminFinancialDataUseCase>(),
        checkWishlist: gh<_i44.CheckWishlistStateUseCase>(),
        toggleWishlist: gh<_i839.ToggleWishlistUseCase>(),
        getProfileId: gh<_i927.GetCurrentProfileIdUseCase>(),
        exportProductPdf: gh<_i967.ExportProductPdfUseCase>(),
      ),
    );
    gh.factory<_i151.ProductFormCubit>(
      () => _i151.ProductFormCubit(
        gh<_i700.GetCategoriesUC>(),
        gh<_i1014.GetProductImagesUC>(),
        gh<_i597.GetProductIngredientsUC>(),
        gh<_i929.GetVariantsDraftsUC>(),
        gh<_i1014.DeleteProductImageUC>(),
        gh<_i929.DeleteVariantUC>(),
        gh<_i929.HasVariantSalesUC>(),
        gh<_i927.GetCurrentProfileIdUseCase>(),
        gh<_i1064.SaveProductUseCase>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i291.RegisterModule {}
