import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/open_finance.dart';

/// Acesso ao módulo Open Finance.
///
/// Leituras vão direto às tabelas `open_finance_*` (protegidas por RLS).
/// Ações sensíveis (token, sincronizar, desconectar) passam SEMPRE por Edge
/// Functions — o app nunca fala com a Pluggy nem vê credenciais.
class OpenFinanceRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<OpenFinanceConnection>> fetchConnections(String userId) async {
    final data = await _client
        .from('open_finance_connections')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: true);
    return (data as List)
        .map((row) => OpenFinanceConnection.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<OpenFinanceAccount>> fetchAccounts(String userId) async {
    final data = await _client
        .from('open_finance_accounts')
        .select()
        .eq('user_id', userId);
    return (data as List)
        .map((row) => OpenFinanceAccount.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<OpenFinanceCard>> fetchCards(String userId) async {
    final data = await _client
        .from('open_finance_cards')
        .select()
        .eq('user_id', userId);
    return (data as List)
        .map((row) => OpenFinanceCard.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<OpenFinanceBill>> fetchBills(String userId) async {
    final data = await _client
        .from('open_finance_bills')
        .select()
        .eq('user_id', userId)
        .order('due_date', ascending: false);
    return (data as List)
        .map((row) => OpenFinanceBill.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<OpenFinanceTransaction>> fetchTransactions(String userId) async {
    final data = await _client
        .from('open_finance_transactions')
        .select()
        .eq('user_id', userId)
        .order('transaction_date', ascending: false)
        .limit(200);
    return (data as List)
        .map((row) =>
            OpenFinanceTransaction.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<ConnectAuthorization> createConnectionAuthorization({
    String? itemId,
    String? institutionId,
    String? institutionName,
    String? document,
    String? companyDocument,
  }) async {
    final body = <String, dynamic>{};
    if (itemId != null) body['itemId'] = itemId;
    if (institutionId != null) body['institutionId'] = institutionId;
    if (institutionName != null) body['institutionName'] = institutionName;
    if (document != null) body['document'] = document;
    if (companyDocument != null) body['companyDocument'] = companyDocument;

    final response = await _client.functions.invoke(
      'open-finance-connect-token',
      body: body,
    );
    final data = response.data;
    if (data is! Map) {
      throw Exception('Não foi possível iniciar a conexão.');
    }
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return ConnectAuthorization.fromMap(Map<String, dynamic>.from(data));
  }

  Future<List<OpenFinanceInstitution>> listInstitutions() async {
    final response = await _client.functions.invoke(
      'open-finance-institutions',
      body: <String, dynamic>{},
    );
    final data = response.data;
    if (data is! Map || data['error'] != null) {
      throw Exception('Não foi possível carregar os bancos.');
    }
    final list = (data['institutions'] as List?) ?? const [];
    return list
        .map((row) =>
            OpenFinanceInstitution.fromMap(Map<String, dynamic>.from(row)))
        .where((institution) => institution.id.isNotEmpty)
        .toList();
  }

  Future<void> sync({String? connectionId}) async {
    final response = await _client.functions.invoke(
      'open-finance-sync',
      body: connectionId != null
          ? {'connectionId': connectionId}
          : <String, dynamic>{},
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }

  Future<void> disconnect(String connectionId) async {
    final response = await _client.functions.invoke(
      'open-finance-disconnect',
      body: {'connectionId': connectionId},
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }
}
