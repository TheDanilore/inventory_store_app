import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
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
    dynamic queryBuilder = _supabase
        .from('profiles')
        .select(
          'id, full_name, phone, document_number, document_type, avatar_url, is_active, wallet_balance, created_at${showOnlyWithDebt ? ', customer_credits!inner(current_debt, credit_limit)' : ''}',
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

    // Ordenar los ms recientes primero, a menos que estemos buscando (relevancia)
    if (query == null || query.isEmpty) {
      queryBuilder = queryBuilder.order('created_at', ascending: false);
    }

    final res = await queryBuilder.range(offset, offset + limit - 1);

    if (res.isEmpty) return [];

    final cIds = res.map((e) => e['id'] as String).toList();

    // Traer aggregados
    final ordersRes = await _supabase
        .from('orders')
        .select('customer_id, total_amount')
        .eq('status', 'COMPLETED')
        .inFilter('customer_id', cIds);

    final creditsRes = await _supabase
        .from('customer_credits')
        .select('profile_id, current_debt, credit_limit')
        .inFilter('profile_id', cIds);

    return res.map((json) {
      final id = json['id'] as String;

      double currentDebt = 0.0;
      double creditLimit = 0.0;

      if (showOnlyWithDebt && json['customer_credits'] != null) {
        final creditObj = (json['customer_credits'] as List).firstOrNull;
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
      );
    }).toList();
  }

  @override
  Future<CustomerEntity> getCustomerDetail(String customerId) async {
    final res =
        await _supabase.from('profiles').select().eq('id', customerId).single();
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
    String? adminProfileId;
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId != null) {
      final adminResp = await _supabase
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
            .update({'wallet_balance': currentWalletBalance + walletAdjustDelta})
            .eq('id', finalProfileId);

        await _supabase.from('wallet_movements').insert({
          'profile_id': finalProfileId,
          'points': walletAdjustDelta,
          'movement_type': walletAdjustDelta > 0 ? 'ADMIN_ADD' : 'ADMIN_SUBTRACT',
          'description': walletAdjustDelta > 0
              ? 'Ajuste manual (+$walletAdjustDelta monedas)'
              : 'Ajuste manual ($walletAdjustDelta monedas)',
        });
      }
    } else {
      // Crear
      final inserted = await _supabase
          .from('profiles')
          .insert({...profileData, 'role': 'customer'})
          .select('id')
          .single();
      finalProfileId = inserted['id'] as String;
    }

    // Creditos
    if (hasCredit) {
      if (creditExistsInDb && creditId != null) {
        await _supabase.from('customer_credits').update({
          'credit_limit': newCreditLimit,
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', creditId);
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
      await _supabase.from('customer_credits').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', creditId);
    }
  }

  @override
  Future<void> toggleCustomerStatus(String customerId, bool isActive) async {
    await _supabase
        .from('profiles')
        .update({'is_active': isActive})
        .eq('id', customerId);
  }

  @override
  Future<Map<String, dynamic>> getGlobalStats() async {
    final profilesRes = await _supabase
        .from('profiles')
        .select('id, is_active')
        .eq('role', 'customer');

    final activeCount = profilesRes.where((p) => p['is_active'] == true).length;
    final inactiveCount =
        profilesRes.where((p) => p['is_active'] == false).length;
    final totalCount = profilesRes.length;

    final ordersRes = await _supabase
        .from('orders')
        .select('customer_id, total_amount')
        .eq('status', 'COMPLETED');

    double totalRevenue = 0.0;
    for (var row in ordersRes) {
      totalRevenue += (row['total_amount'] as num?)?.toDouble() ?? 0.0;
    }

    final creditsRes = await _supabase
        .from('customer_credits')
        .select('profile_id, current_debt');
    double totalDebt = 0.0;
    for (var row in creditsRes) {
      totalDebt += (row['current_debt'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'totalCount': totalCount,
      'activeCount': activeCount,
      'inactiveCount': inactiveCount,
      'totalRevenue': totalRevenue,
      'totalDebt': totalDebt,
    };
  }

  @override
  Future<List<CustomerEntity>> getTopCustomers(int limit) async {
    final ordersRes = await _supabase
        .from('orders')
        .select('customer_id, total_amount')
        .eq('status', 'COMPLETED');

    final revMap = <String, double>{};
    for (var row in ordersRes) {
      final cid = row['customer_id'] as String?;
      if (cid != null) {
        revMap[cid] =
            (revMap[cid] ?? 0.0) +
            ((row['total_amount'] as num?)?.toDouble() ?? 0.0);
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

    return topProfilesRes.map((json) {
      return CustomerEntity(
        id: json['id'] as String,
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
        totalRevenue: revMap[json['id'] as String] ?? 0.0,
      );
    }).toList();
  }

  @override
  Future<List<RecentOrderEntity>> getCustomerRecentOrders(
    String customerId,
  ) async {
    return [];
  }

  @override
  Future<List<TopProductEntity>> getCustomerTopProducts(
    String customerId,
  ) async {
    return [];
  }
}
