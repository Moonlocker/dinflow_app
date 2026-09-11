import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plan.dart';

/// Planos e gestão de assinatura (checkout/portal/cancelamento via Stripe).
class SubscriptionRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Plan>> fetchActivePlans() async {
    final data = await _client
        .from('plans')
        .select(
            'id, name, price, status, recurrence, features, whatsapp_numbers_limit, stripe_product_id')
        .eq('status', 'Ativo')
        .order('price', ascending: true);
    return (data as List)
        .map((row) => Plan.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<String> fetchActiveGateway() async {
    final data = await _client
        .from('payment_settings')
        .select('active_gateway')
        .eq('id', 1)
        .maybeSingle();
    return (data?['active_gateway'] ?? 'stripe') as String;
  }

  Future<String?> createCheckout(String planId) async {
    final response = await _client.functions.invoke(
      'stripe-create-checkout',
      body: {'planId': planId},
    );
    return _extractUrl(response.data);
  }

  Future<String?> openCustomerPortal() async {
    final response = await _client.functions.invoke(
      'stripe-customer-portal',
      body: const {},
    );
    return _extractUrl(response.data);
  }

  Future<void> cancelSubscription(String reason) {
    return _client.functions.invoke(
      'stripe-cancel-subscription',
      body: {'reason': reason},
    );
  }

  Future<List<Map<String, dynamic>>> fetchPayments(String userId) async {
    final data = await _client
        .from('payments')
        .select('id, plan_id, amount, status, gateway, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  String? _extractUrl(dynamic data) {
    if (data is Map) {
      final url = data['url'] ?? data['checkout_url'] ?? data['session_url'];
      return url?.toString();
    }
    return null;
  }
}
