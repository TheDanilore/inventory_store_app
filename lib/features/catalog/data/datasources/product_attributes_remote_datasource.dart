import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';

class ProductAttributesRemoteDataSource {
  final SupabaseClient _supabase;

  ProductAttributesRemoteDataSource(this._supabase);

  Future<AttributeEntity> createAttribute(
    String name, {
    String? description,
  }) async {
    final payload = {
      'name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    };
    final res =
        await _supabase
            .from('attributes')
            .insert(payload)
            .select('id, name, description')
            .single();
    return AttributeEntity(
      id: res['id'],
      name: res['name'],
      description: res['description'] as String?,
    );
  }

  Future<void> updateAttribute(
    String id,
    String name, {
    String? description,
  }) async {
    final payload = {
      'name': name.trim(),
      'description':
          (description != null && description.trim().isNotEmpty)
              ? description.trim()
              : null,
    };
    await _supabase.from('attributes').update(payload).eq('id', id);
  }

  Future<bool> hasAttributeValuesAssigned(String attributeId) async {
    final valuesRes = await _supabase
        .from('attribute_values')
        .select('id')
        .eq('attribute_id', attributeId);
    final valueIds = (valuesRes as List).map((v) => v['id'] as String).toList();

    if (valueIds.isNotEmpty) {
      final usageCheck = await _supabase
          .from('variant_attribute_values')
          .select('variant_id')
          .inFilter('attribute_value_id', valueIds)
          .limit(1);

      return (usageCheck as List).isNotEmpty;
    }
    return false;
  }

  Future<void> deleteAttribute(String id) async {
    await _supabase.from('attributes').delete().eq('id', id);
  }

  Future<AttributeValueEntity> createAttributeValue(
    String attributeId,
    String value,
  ) async {
    final res =
        await _supabase
            .from('attribute_values')
            .insert({'attribute_id': attributeId, 'value': value.trim()})
            .select('id, attribute_id, value')
            .single();
    return AttributeValueEntity(
      id: res['id'],
      attributeId: res['attribute_id'],
      value: res['value'],
    );
  }

  Future<void> updateAttributeValue(String valueId, String value) async {
    await _supabase
        .from('attribute_values')
        .update({'value': value.trim()})
        .eq('id', valueId);
  }

  Future<void> deleteAttributeValue(String valueId) async {
    await _supabase.from('attribute_values').delete().eq('id', valueId);
  }

  Future<List<Map<String, dynamic>>> searchAttributes(String term) async {
    var query = _supabase.from('attributes').select('id, name');
    if (term.trim().isNotEmpty) {
      query = query.ilike('name', '%${term.trim()}%');
    }
    final res = await query.order('name').limit(15);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> searchAttributeValues(
    String attributeId,
    String term,
  ) async {
    var query = _supabase
        .from('attribute_values')
        .select('id, value')
        .eq('attribute_id', attributeId);
    if (term.trim().isNotEmpty) {
      query = query.ilike('value', '%${term.trim()}%');
    }
    final res = await query.order('value').limit(15);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> getOrCreateAttribute(String name) async {
    final exist =
        await _supabase
            .from('attributes')
            .select('id, name')
            .ilike('name', name.trim())
            .maybeSingle();
    if (exist != null) return exist;

    final res =
        await _supabase
            .from('attributes')
            .insert({'name': name.trim()})
            .select('id, name')
            .single();
    return res;
  }

  Future<Map<String, dynamic>> getOrCreateAttributeValue(
    String attributeId,
    String value,
  ) async {
    final exist =
        await _supabase
            .from('attribute_values')
            .select('id, value')
            .eq('attribute_id', attributeId)
            .ilike('value', value.trim())
            .maybeSingle();
    if (exist != null) return exist;

    final res =
        await _supabase
            .from('attribute_values')
            .insert({'attribute_id': attributeId, 'value': value.trim()})
            .select('id, value')
            .single();
    return res;
  }

  Future<List<AttributeEntity>> getAttributes() async {
    final res = await _supabase
        .from('attributes')
        .select('id, name, description, attribute_values(id, value)')
        .order('name');
    final list = res as List<dynamic>;
    return list.map((item) {
      final values =
          (item['attribute_values'] as List<dynamic>?)
              ?.map(
                (v) => AttributeValueEntity(
                  id: v['id'],
                  attributeId: item['id'],
                  value: v['value'],
                ),
              )
              .toList() ??
          [];
      return AttributeEntity(
        id: item['id'],
        name: item['name'],
        description: item['description'],
        values: values,
      );
    }).toList();
  }
}
