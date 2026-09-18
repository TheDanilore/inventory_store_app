import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/recent_order_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customers_repository.dart';

@LazySingleton(as: CustomersRepository)
class CustomersRepositoryImpl implements CustomersRepository {
  final SupabaseClient _supabase;

  CustomersRepositoryImpl() : _supabase = Supabase.instance.client;

  @override
  Future<List<CustomerEntity>> getCustomers({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) async {
    try {
      dynamic queryBuilder = _supabase
          .from('profiles')
          .select(
            'id, full_name, phone, document_number, document_type, avatar_url, is_active, wallet_balance, created_at${showOnlyWithDebt ? ', customer_credits:customer_credits!customer_credits_profile_id_fkey!inner(current_debt, credit_limit)' : ''}',
          );

      queryBuilder = queryBuilder.eq('role', 'customer');

      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'full_name.ilike.%$query%,document_number.ilike.%$query%,phone.ilike.%$query%',
        );
      }

      if (showOnlyWithDebt) {
        queryBuilder = queryBuilder.gt('customer_credits.current_debt', 0);
      }

      // Ordenar los más recientes primero, a menos que estemos buscando (relevancia)
      if (query == null || query.isEmpty) {
        queryBuilder = queryBuilder.order('created_at', ascending: false);
      }

      final res = await queryBuilder.range(offset, offset + limit - 1);

      if (res.isEmpty) return [];

      final cIds = res.map((e) => e['id'] as String).toList();

      // Traer agregados
      final ordersRes = await _supabase
          .from('orders')
          .select('customer_id, total_amount')
          .eq('status', 'COMPLETED')
          .inFilter('customer_id', cIds);

      final creditsRes = await _supabase
          .from('customer_credits')
          .select('profile_id, current_debt, credit_limit')
          .inFilter('profile_id', cIds);

      return res.map<CustomerEntity>((json) {
        final id = json['id'] as String;

        double currentDebt = 0.0;
        double creditLimit = 0.0;

        if (showOnlyWithDebt && json['customer_credits'] != null) {
          final creditData = json['customer_credits'];
          Map<String, dynamic>? creditObj;
          if (creditData is Map<String, dynamic>) {
            creditObj = creditData;
          } else if (creditData is List && creditData.isNotEmpty) {
            creditObj = creditData.first as Map<String, dynamic>?;
          }
          if (creditObj != null) {
            currentDebt = (creditObj['current_debt'] as num?)?.toDouble() ?? 0.0;
            creditLimit = (creditObj['credit_limit'] as num?)?.toDouble() ?? 0.0;
          }
        } else {
          // Viene del query separado
          final creditRowMatch = creditsRes.where((c) => c['profile_id'] == id);
          final creditRow =
              creditRowMatch.isNotEmpty ? creditRowMatch.first : null;
          if (creditRow != null) {
            currentDebt = (creditRow['current_debt'] as num?)?.toDouble() ?? 0.0;
            creditLimit = (creditRow['credit_limit'] as num?)?.toDouble() ?? 0.0;
          }
        }

        final customerOrders =
            ordersRes.where((o) => o['customer_id'] == id).toList();
        double totalSpent = 0.0;
        for (var o in customerOrders) {
          totalSpent += (o['total_amount'] as num?)?.toDouble() ?? 0.0;
        }

        return CustomerEntity(
          id: id,
          fullName: json['full_name'] as String? ?? 'Cliente',
          phone: json['phone'] as String?,
          documentNumber: json['document_number'] as String?,
          documentType: json['document_type'] as String?,
          avatarUrl: json['avatar_url'] as String?,
          walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
          isActive: json['is_active'] as bool? ?? true,
          createdAt:
              json['created_at'] != null
                  ? DateTime.parse(json['created_at'])
                  : null,
          currentDebt: currentDebt,
          creditLimit: creditLimit,
          totalRevenue: totalSpent,
          orderCount: customerOrders.length,
        );
      }).toList();
    } catch (e, stack) {
      LoggerService.e('Error en getCustomers', error: e, stackTrace: stack);
      throw AppException(
        message: 'Error al cargar la lista de clientes',
        originalError: e,
      );
    }
  }

  @override
  Future<CustomerEntity> getCustomerDetail(String customerId) async {
    try {
      final res =
          await _supabase.from('profiles').select().eq('id', customerId).single();

      final ordersRes = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('customer_id', customerId)
          .eq('status', 'COMPLETED');

      final creditRes =
          await _supabase
              .from('customer_credits')
              .select('current_debt, credit_limit')
              .eq('profile_id', customerId)
              .maybeSingle();

      double totalSpent = 0.0;
      for (var row in ordersRes) {
        totalSpent += (row['total_amount'] as num?)?.toDouble() ?? 0.0;
      }

      double currentDebt = 0.0;
      double creditLimit = 0.0;
      if (creditRes != null) {
        currentDebt = (creditRes['current_debt'] as num?)?.toDouble() ?? 0.0;
        creditLimit = (creditRes['credit_limit'] as num?)?.toDouble() ?? 0.0;
      }

      return CustomerEntity(
        id: res['id'] as String,
        fullName: res['full_name'] as String? ?? 'Cliente',
        phone: res['phone'] as String?,
        documentNumber: res['document_number'] as String?,
        documentType: res['document_type'] as String?,
        avatarUrl: res['avatar_url'] as String?,
        walletBalance: (res['wallet_balance'] as num?)?.toDouble() ?? 0.0,
        isActive: res['is_active'] as bool? ?? true,
        createdAt:
            res['created_at'] != null ? DateTime.parse(res['created_at']) : null,
        currentDebt: currentDebt,
        creditLimit: creditLimit,
        totalRevenue: totalSpent,
        orderCount: ordersRes.length,
      );
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error fetching customer detail for $customerId',
        error: e,
        stackTrace: stackTrace,
      );
      throw AppException(
        message: 'Error al obtener detalle del cliente: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<CustomerEntity> createCustomer({
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
  }) async {
    final Map<String, dynamic> data = {
      'full_name': fullName,
      'role': 'customer',
      'is_active': true,
    };
    if (phone != null && phone.isNotEmpty) data['phone'] = phone;
    if (documentNumber != null && documentNumber.isNotEmpty) {
      data['document_number'] = documentNumber;
    }
    if (documentType != null) data['document_type'] = documentType;

    final res = await _supabase.from('profiles').insert(data).select().single();
    return CustomerEntity(
      id: res['id'] as String,
      fullName: res['full_name'] as String? ?? 'Cliente',
      phone: res['phone'] as String?,
      documentNumber: res['document_number'] as String?,
      documentType: res['document_type'] as String?,
      avatarUrl: res['avatar_url'] as String?,
      walletBalance: (res['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      isActive: res['is_active'] as bool? ?? true,
      createdAt:
          res['created_at'] != null ? DateTime.parse(res['created_at']) : null,
    );
  }

  @override
  Future<CustomerEntity> updateCustomer({
    required String customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    bool? isActive,
  }) async {
    final Map<String, dynamic> data = {'full_name': fullName};
    if (phone != null) data['phone'] = phone.isEmpty ? null : phone;
    if (documentNumber != null) {
      data['document_number'] = documentNumber.isEmpty ? null : documentNumber;
    }
    if (documentType != null) data['document_type'] = documentType;
    if (isActive != null) data['is_active'] = isActive;

    final res =
        await _supabase
            .from('profiles')
            .update(data)
            .eq('id', customerId)
            .select()
            .single();
    return CustomerEntity(
      id: res['id'] as String,
      fullName: res['full_name'] as String? ?? 'Cliente',
      phone: res['phone'] as String?,
      documentNumber: res['document_number'] as String?,
      documentType: res['document_type'] as String?,
      avatarUrl: res['avatar_url'] as String?,
      walletBalance: (res['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      isActive: res['is_active'] as bool? ?? true,
      createdAt:
          res['created_at'] != null ? DateTime.parse(res['created_at']) : null,
    );
  }

  @override
  Future<void> saveCustomerFullProfile({
    String? customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    required bool isActive,
    required int walletAdjustDelta,
    required double currentWalletBalance,
    required bool hasCredit,
    required bool creditExistsInDb,
    String? creditId,
    required bool creditIsActive,
    required double newCreditLimit,
  }) async {
    try {
      String? adminProfileId;
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId != null) {
        final adminResp =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        if (adminResp != null) adminProfileId = adminResp['id'] as String;
      }

      final profileData = {
        'full_name': fullName,
        'phone': phone,
        'document_type': documentType,
        'document_number': documentNumber,
        'is_active': isActive,
      };

      String finalProfileId;

      if (customerId != null) {
        // Editar
        await _supabase.from('profiles').update(profileData).eq('id', customerId);
        finalProfileId = customerId;

        if (walletAdjustDelta != 0) {
          await _supabase
              .from('profiles')
              .update({
                'wallet_balance': currentWalletBalance + walletAdjustDelta,
              })
              .eq('id', finalProfileId);

          await _supabase.from('wallet_movements').insert({
            'profile_id': finalProfileId,
            'points': walletAdjustDelta,
            'movement_type':
                walletAdjustDelta > 0 ? 'ADMIN_ADD' : 'ADMIN_SUBTRACT',
            'description':
                walletAdjustDelta > 0
                    ? 'Ajuste manual (+$walletAdjustDelta monedas)'
                    : 'Ajuste manual ($walletAdjustDelta monedas)',
          });
        }
      } else {
        // Crear
        final inserted =
            await _supabase
                .from('profiles')
                .insert({...profileData, 'role': 'customer'})
                .select('id')
                .single();
        finalProfileId = inserted['id'] as String;
      }

      // Creditos
      if (hasCredit) {
        if (creditExistsInDb && creditId != null) {
          await _supabase
              .from('customer_credits')
              .update({
                'credit_limit': newCreditLimit,
                'is_active': true,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', creditId);
        } else {
          await _supabase.from('customer_credits').insert({
            'profile_id': finalProfileId,
            'credit_limit': newCreditLimit,
            'current_debt': 0.0,
            'is_active': true,
            'created_by': adminProfileId,
          });
        }
      } else if (creditExistsInDb && creditId != null && creditIsActive) {
        await _supabase
            .from('customer_credits')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', creditId);
      }
    } catch (e, stack) {
      LoggerService.e(
        'Error en saveCustomerFullProfile',
        error: e,
        stackTrace: stack,
      );
      throw AppException(
        message: 'Error al guardar el perfil del cliente',
        originalError: e,
      );
    }
  }

  @override
  Future<void> toggleCustomerStatus(String customerId, bool isActive) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_active': isActive})
          .eq('id', customerId);
    } catch (e, stack) {
      LoggerService.e(
        'Error en toggleCustomerStatus para $customerId',
        error: e,
        stackTrace: stack,
      );
      throw AppException(
        message: 'Error al cambiar estado del cliente',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getGlobalStats() async {
    try {
      final res = await _supabase.rpc('get_customers_global_stats_rpc');
      if (res != null && res is Map) {
        final totalCustomers = (res['totalCustomersCount'] ??
                res['total_customers_count'] ??
                res['total_count'] ??
                res['totalCount'] as num?)
            ?.toInt() ??
            0;
        final activeCustomers = (res['activeCustomersCount'] ??
                res['active_customers_count'] ??
                res['active_count'] ??
                res['activeCount'] as num?)
            ?.toInt() ??
            0;
        final inactiveCustomers = (res['inactiveCustomersCount'] ??
                res['inactive_customers_count'] ??
                res['inactive_count'] ??
                res['inactiveCount'] as num?)
            ?.toInt() ??
            0;
        final totalRevenue = (res['totalRevenue'] ??
                res['total_revenue'] as num?)
            ?.toDouble() ??
            0.0;
        final totalDebt = (res['totalDebt'] ??
                res['total_debt'] as num?)
            ?.toDouble() ??
            0.0;
        final debtCustomers = (res['debtCustomersCount'] ??
                res['debt_customers_count'] as num?)
            ?.toInt() ??
            0;

        return {
          'totalCount': totalCustomers,
          'totalCustomersCount': totalCustomers,
          'activeCount': activeCustomers,
          'activeCustomersCount': activeCustomers,
          'inactiveCount': inactiveCustomers,
          'totalRevenue': totalRevenue,
          'totalDebt': totalDebt,
          'debtCustomersCount': debtCustomers,
        };
      }
    } catch (rpcErr) {
      LoggerService.w(
        'RPC get_customers_global_stats_rpc no disponible o falló, usando fallback cliente: $rpcErr',
      );
    }

    try {
      final profilesRes = await _supabase
          .from('profiles')
          .select('is_active')
          .eq('role', 'customer');

      final activeCount =
          profilesRes.where((p) => p['is_active'] == true).length;
      final inactiveCount =
          profilesRes.where((p) => p['is_active'] == false).length;
      final totalCount = profilesRes.length;

      final ordersRes = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('status', 'COMPLETED');

      double totalRevenue = 0.0;
      for (var row in ordersRes) {
        totalRevenue += (row['total_amount'] as num?)?.toDouble() ?? 0.0;
      }

      final creditsRes = await _supabase
          .from('customer_credits')
          .select('current_debt');
      double totalDebt = 0.0;
      int debtCustomersCount = 0;
      for (var row in creditsRes) {
        final debt = (row['current_debt'] as num?)?.toDouble() ?? 0.0;
        totalDebt += debt;
        if (debt > 0) {
          debtCustomersCount++;
        }
      }

      return {
        'totalCount': totalCount,
        'totalCustomersCount': totalCount,
        'activeCount': activeCount,
        'activeCustomersCount': activeCount,
        'inactiveCount': inactiveCount,
        'totalRevenue': totalRevenue,
        'totalDebt': totalDebt,
        'debtCustomersCount': debtCustomersCount,
      };
    } catch (e, stack) {
      LoggerService.e(
        'Error en getGlobalStats fallback',
        error: e,
        stackTrace: stack,
      );
      throw AppException(
        message: 'Error al cargar estadísticas globales de clientes',
        originalError: e,
      );
    }
  }

  @override
  Future<List<CustomerEntity>> getTopCustomers(int limit) async {
    try {
      final res = await _supabase.rpc(
        'get_top_customers_rpc',
        params: {'p_limit': limit},
      );
      if (res != null && res is List) {
        return res.map<CustomerEntity>((row) {
          final totalRev = (row['total_revenue'] ??
                  row['totalRevenue'] ??
                  row['total_spent'] as num?)
              ?.toDouble() ??
              0.0;
          final orderCount = (row['order_count'] ??
                  row['orderCount'] as num?)
              ?.toInt() ??
              0;
          return CustomerEntity(
            id: row['id'] as String,
            fullName: row['full_name'] as String? ?? 'Cliente',
            phone: row['phone'] as String?,
            documentNumber: row['document_number'] as String?,
            documentType: row['document_type'] as String?,
            avatarUrl: row['avatar_url'] as String?,
            walletBalance: (row['wallet_balance'] as num?)?.toDouble() ?? 0.0,
            isActive: row['is_active'] as bool? ?? true,
            createdAt:
                row['created_at'] != null
                    ? DateTime.tryParse(row['created_at'].toString())
                    : null,
            totalRevenue: totalRev,
            orderCount: orderCount,
          );
        }).toList();
      }
    } catch (rpcErr) {
      LoggerService.w(
        'RPC get_top_customers_rpc no disponible o falló, usando fallback cliente: $rpcErr',
      );
    }

    try {
      final ordersRes = await _supabase
          .from('orders')
          .select('customer_id, total_amount')
          .eq('status', 'COMPLETED');

      final revMap = <String, double>{};
      final countMap = <String, int>{};
      for (var row in ordersRes) {
        final cid = row['customer_id'] as String?;
        if (cid != null) {
          revMap[cid] =
              (revMap[cid] ?? 0.0) +
              ((row['total_amount'] as num?)?.toDouble() ?? 0.0);
          countMap[cid] = (countMap[cid] ?? 0) + 1;
        }
      }

      var sortedEntries =
          revMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topIds = sortedEntries.take(limit).map((e) => e.key).toList();

      if (topIds.isEmpty) return [];

      final topProfilesRes = await _supabase
          .from('profiles')
          .select()
          .inFilter('id', topIds);

      final list =
          topProfilesRes.map<CustomerEntity>((json) {
            final cid = json['id'] as String;
            return CustomerEntity(
              id: cid,
              fullName: json['full_name'] as String? ?? 'Cliente',
              phone: json['phone'] as String?,
              documentNumber: json['document_number'] as String?,
              documentType: json['document_type'] as String?,
              avatarUrl: json['avatar_url'] as String?,
              walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
              isActive: json['is_active'] as bool? ?? true,
              createdAt:
                  json['created_at'] != null
                      ? DateTime.parse(json['created_at'])
                      : null,
              totalRevenue: revMap[cid] ?? 0.0,
              orderCount: countMap[cid] ?? 0,
            );
          }).toList();

      list.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
      return list;
    } catch (e, stack) {
      LoggerService.e(
        'Error en getTopCustomers fallback',
        error: e,
        stackTrace: stack,
      );
      throw AppException(
        message: 'Error al obtener clientes destacados',
        originalError: e,
      );
    }
  }

  @override
  Future<List<RecentOrderEntity>> getCustomerRecentOrders(
    String customerId,
  ) async {
    try {
      final res = await _supabase
          .from('orders')
          .select(
            'id, created_at, total_amount, amount_paid, discount_amount, status, payment_status, payment_method, points_earned, points_used, due_date',
          )
          .eq('customer_id', customerId)
          .order('created_at', ascending: false)
          .limit(10);

      return res.map<RecentOrderEntity>((json) {
        return RecentOrderEntity(
          id: json['id'] as String,
          createdAt: DateTime.parse(json['created_at']),
          totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
          amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
          discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
          status: json['status'] as String? ?? 'COMPLETED',
          paymentStatus: json['payment_status'] as String? ?? 'PAID',
          paymentMethod: json['payment_method'] as String? ?? 'EFECTIVO',
          pointsEarned: (json['points_earned'] as num?)?.toInt() ?? 0,
          pointsUsed: (json['points_used'] as num?)?.toInt() ?? 0,
          dueDate:
              json['due_date'] != null
                  ? DateTime.tryParse(json['due_date'])
                  : null,
        );
      }).toList();
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error fetching customer recent orders for $customerId',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  @override
  Future<List<TopProductEntity>> getCustomerTopProducts(
    String customerId,
  ) async {
    try {
      final res = await _supabase
          .from('order_items')
          .select(
            'quantity, applied_price, products(name), order:orders!inner(customer_id, status)',
          )
          .eq('order.customer_id', customerId)
          .eq('order.status', 'COMPLETED')
          .limit(200);

      final productMap = <String, ({int qty, double spent})>{};
      for (var row in res) {
        final productsObj = row['products'] as Map<String, dynamic>?;
        final pname = productsObj?['name'] as String? ?? 'Producto';
        final qty = (row['quantity'] as num?)?.toInt() ?? 0;
        final price = (row['applied_price'] as num?)?.toDouble() ?? 0.0;
        final current = productMap[pname] ?? (qty: 0, spent: 0.0);
        productMap[pname] = (
          qty: current.qty + qty,
          spent: current.spent + (qty * price),
        );
      }

      final sorted =
          productMap.entries.toList()
            ..sort((a, b) => b.value.spent.compareTo(a.value.spent));

      return sorted.take(5).map((e) {
        return TopProductEntity(
          productName: e.key,
          totalQuantity: e.value.qty,
          totalSpent: e.value.spent,
        );
      }).toList();
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error fetching customer top products for $customerId',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
}
