import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/data/models/customer_credit_models.dart';
import 'package:inventory_store_app/features/customers/data/models/customer_credit_movement_model.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/i_customer_credits_repository.dart';

@LazySingleton(as: ICustomerCreditsRepository)
class CustomerCreditsRepositoryImpl implements ICustomerCreditsRepository {
  final SupabaseClient _supabase;

  CustomerCreditsRepositoryImpl() : _supabase = Supabase.instance.client;

  @override
  Future<List<CustomerCreditEntity>> getCreditAccounts({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) async {
    var queryBuilder = _supabase.from('customer_credits_summary').select();

    if (query != null && query.isNotEmpty) {
      queryBuilder = queryBuilder.or(
          'partner_name.ilike.%$query%,partner_document.ilike.%$query%,partner_phone.ilike.%$query%');
    }

    if (showOnlyWithDebt) {
      queryBuilder = queryBuilder.gt('current_debt', 0);
    }

    final response = await queryBuilder.range(offset, offset + limit - 1);

    return (response as List)
        .map((e) => CreditAccountModel.fromView(e).toEntity())
        .toList();
  }

  @override
  Future<CustomerCreditEntity?> getCreditAccountByCustomer(
      String customerId) async {
    final resp = await _supabase
        .from('customer_credits_summary')
        .select()
        .eq('profile_id', customerId)
        .maybeSingle();

    if (resp != null) {
      return CreditAccountModel.fromView(resp).toEntity();
    }
    return null;
  }

  @override
  Future<CustomerCreditEntity> createCreditAccount({
    required String customerId,
    required double creditLimit,
  }) async {
    // Check if exists
    final exist = await _supabase
        .from('customer_credits')
        .select('id')
        .eq('profile_id', customerId)
        .maybeSingle();

    if (exist != null) {
      // Activar y actualizar
      await _supabase
          .from('customer_credits')
          .update({'is_active': true, 'credit_limit': creditLimit})
          .eq('profile_id', customerId);
    } else {
      await _supabase.from('customer_credits').insert({
        'profile_id': customerId,
        'credit_limit': creditLimit,
      });
    }

    final resp = await _supabase
        .from('customer_credits_summary')
        .select()
        .eq('profile_id', customerId)
        .single();
    return CreditAccountModel.fromView(resp).toEntity();
  }

  @override
  Future<CustomerCreditEntity> updateCreditLimit({
    required String creditId,
    required double newLimit,
  }) async {
    await _supabase
        .from('customer_credits')
        .update({'credit_limit': newLimit})
        .eq('id', creditId);

    final resp = await _supabase
        .from('customer_credits_summary')
        .select()
        .eq('credit_id', creditId)
        .single();
    return CreditAccountModel.fromView(resp).toEntity();
  }

  @override
  Future<void> toggleCreditStatus(String creditId, bool isActive) async {
    await _supabase
        .from('customer_credits')
        .update({'is_active': isActive})
        .eq('id', creditId);
  }

  @override
  Future<List<CreditMovementEntity>> getCreditMovements({
    required String creditId,
    required int limit,
    required int offset,
  }) async {
    final response = await _supabase
        .from('customer_credit_movements_summary')
        .select()
        .eq('customer_credit_id', creditId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((e) => CustomerCreditMovementModel.fromJson(e).toEntity())
        .toList();
  }

  @override
  Future<CreditMovementEntity> registerPayment({
    required String creditId,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    // Este mtodo simple abstrae el registro de pago. 
    // Dado que el sistema original tiene 'registerPayment' que actualiza mltiples tablas de Orders y Finanzas, 
    // lo simplificaremos o usaremos el servicio existente que el CU puede orquestar.
    
    // Por ahora, registramos solo el movimiento y deducimos la deuda
    final credit = await _supabase
        .from('customer_credits')
        .select('current_debt')
        .eq('id', creditId)
        .single();
        
    final newDebt = ((credit['current_debt'] as num).toDouble() - amount)
        .clamp(0.0, double.infinity);

    await _supabase
        .from('customer_credits')
        .update({'current_debt': newDebt})
        .eq('id', creditId);

    final res = await _supabase.from('customer_credit_movements').insert({
      'customer_credit_id': creditId,
      'movement_type': 'PAYMENT',
      'amount': amount,
      'payment_method': paymentMethod,
      'notes': notes,
    }).select().single();

    return CreditMovementEntity(
      id: res['id'],
      customerCreditId: res['customer_credit_id'],
      movementType: res['movement_type'],
      amount: (res['amount'] as num).toDouble(),
      paymentMethod: res['payment_method'],
      notes: res['notes'],
    );
  }
}
