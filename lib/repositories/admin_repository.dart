import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_user.dart';
import '../models/plan.dart';

/// Acesso a todos os dados do painel de superadmin.
///
/// Espelha as consultas/RPC/Edge Functions usadas pelo painel do webapp.
/// As operações de escrita dependem das policies de RLS (auth_is_superadmin)
/// e das RPCs `admin_*`.
class AdminRepository {
  SupabaseClient get _client => Supabase.instance.client;

  // ==========================================================================
  // Visão geral
  // ==========================================================================

  Future<List<Map<String, dynamic>>> fetchRecentPayments({int limit = 8}) async {
    final data = await _client
        .from('payments')
        .select('id, user_id, plan_id, amount, status, gateway, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return _asMapList(data);
  }

  Future<List<Map<String, dynamic>>> fetchRecentSignups({int limit = 8}) async {
    final data = await _client
        .from('profiles')
        .select('id, name, email, subscription_status, created_at, role')
        .order('created_at', ascending: false)
        .limit(limit);
    return _asMapList(data);
  }

  /// Dados brutos usados para montar os indicadores da visão geral.
  Future<Map<String, List<Map<String, dynamic>>>> fetchDashboardData() async {
    final results = await Future.wait([
      _client.from('profiles').select(
          'id, role, subscription_status, trial_ends_at, subscription_end_date, created_at'),
      _client
          .from('payments')
          .select('user_id, amount, created_at, status, plan_id'),
      _client.from('plans').select('id, name, price'),
      _client
          .from('subscriptions')
          .select('user_id, plan_id, status, current_period_end, created_at'),
    ]);

    return {
      'profiles': _asMapList(results[0]),
      'payments': _asMapList(results[1]),
      'plans': _asMapList(results[2]),
      'subscriptions': _asMapList(results[3]),
    };
  }

  Future<List<AdminUser>> listProfiles() async {
    final data = await _client.rpc('admin_list_profiles');
    return _asMapList(data).map(AdminUser.fromMap).toList();
  }

  /// Conta registros de uma tabela (exact count via PostgREST).
  Future<int> countRows(String table) async {
    final response =
        await _client.from(table).select('id').count(CountOption.exact);
    return response.count;
  }

  // ==========================================================================
  // Usuários
  // ==========================================================================

  Future<List<AdminUser>> listUsersWithStatus() async {
    final data = await _client.rpc('admin_list_profiles_with_status');
    return _asMapList(data).map(AdminUser.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> listSubscriptions() async {
    final data = await _client
        .from('subscriptions')
        .select('user_id, plan_id, status, current_period_end, gateway');
    return _asMapList(data);
  }

  Future<void> adminUpdateProfile({
    required String userId,
    required String name,
    required String email,
    required String subscriptionStatus,
    DateTime? trialEndsAt,
  }) {
    return _client.rpc('admin_update_profile', params: {
      'p_user_id': userId,
      'p_name': name,
      'p_email': email,
      'p_subscription_status': subscriptionStatus,
      'p_trial_ends_at': trialEndsAt?.toIso8601String(),
    });
  }

  Future<void> adminDeleteUser(String userId) {
    return _client.rpc('admin_delete_user', params: {'p_user_id': userId});
  }

  Future<void> adminUpsertSubscription({
    required String userId,
    required String? planId,
    required String status,
    DateTime? currentPeriodEnd,
    required String gateway,
  }) {
    return _client.rpc('admin_upsert_subscription', params: {
      'p_user_id': userId,
      'p_plan_id': planId,
      'p_status': status,
      'p_current_period_end': currentPeriodEnd?.toIso8601String(),
      'p_gateway': gateway,
    });
  }

  // ==========================================================================
  // Planos
  // ==========================================================================

  Future<List<Plan>> listPlans() async {
    final data = await _client
        .from('plans')
        .select(
            'id, name, price, status, recurrence, features, whatsapp_numbers_limit, stripe_product_id, is_free, allow_whatsapp_messages, max_transactions_monthly')
        .order('created_at', ascending: false);
    return _asMapList(data).map(Plan.fromMap).toList();
  }

  Future<String> createPlan(Map<String, dynamic> values) async {
    final data =
        await _client.from('plans').insert(values).select('id').single();
    return data['id'] as String;
  }

  Future<void> updatePlan(String id, Map<String, dynamic> values) async {
    await _client.from('plans').update(values).eq('id', id);
  }

  Future<void> deletePlan(String id) async {
    await _client.from('plans').delete().eq('id', id);
  }

  Future<void> syncAllPlans() {
    return _client.functions.invoke(
      'stripe-sync-plan',
      body: {'action': 'syncAll'},
    );
  }

  Future<void> syncPlan(String planId, String action) {
    return _client.functions.invoke(
      'stripe-sync-plan',
      body: {'planId': planId, 'action': action},
    );
  }

  // ==========================================================================
  // Pagamentos
  // ==========================================================================

  Future<String> fetchActiveGateway() async {
    final data = await _client
        .from('payment_settings')
        .select('active_gateway')
        .eq('id', 1)
        .maybeSingle();
    return (data?['active_gateway'] ?? 'stripe') as String;
  }

  // ==========================================================================
  // Comunicação — e-mail
  // ==========================================================================

  Future<List<Map<String, dynamic>>> listEmailTemplates() async {
    final data = await _client
        .from('email_templates')
        .select('id, key, subject, body, is_default')
        .order('created_at', ascending: true);
    return _asMapList(data);
  }

  Future<void> upsertEmailTemplate(Map<String, dynamic> values) async {
    final id = values['id'];
    if (id != null) {
      await _client.from('email_templates').update(values).eq('id', id);
    } else {
      await _client.from('email_templates').insert(values);
    }
  }

  Future<void> deleteEmailTemplate(String id) async {
    await _client.from('email_templates').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listEmailHistory() async {
    final data = await _client
        .from('email_history')
        .select('id, subject, body, recipients_count, status, error, sent_at')
        .order('created_at', ascending: false);
    return _asMapList(data);
  }

  Future<void> deleteEmailHistory(String id) async {
    await _client.from('email_history').delete().eq('id', id);
  }

  Future<void> sendEmail({
    required String subject,
    required String body,
    required List<Map<String, dynamic>> recipients,
    String? historyId,
  }) {
    return _client.functions.invoke('send-email', body: {
      'subject': subject,
      'body': body,
      'recipients': recipients,
      'history_id': historyId,
    });
  }

  Future<Map<String, dynamic>?> insertEmailHistoryReturning(
      Map<String, dynamic> values) async {
    final data =
        await _client.from('email_history').insert(values).select().single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateEmailHistory(String id, Map<String, dynamic> values) async {
    await _client.from('email_history').update(values).eq('id', id);
  }

  // ==========================================================================
  // Comunicação — notificações
  // ==========================================================================

  Future<List<Map<String, dynamic>>> listNotificationTemplates() async {
    final data = await _client
        .from('notification_templates')
        .select('id, key, title, body, is_default')
        .order('created_at', ascending: false);
    return _asMapList(data);
  }

  Future<void> upsertNotificationTemplate(Map<String, dynamic> values) async {
    final id = values['id'];
    if (id != null) {
      await _client.from('notification_templates').update(values).eq('id', id);
    } else {
      await _client.from('notification_templates').insert(values);
    }
  }

  Future<void> deleteNotificationTemplate(String id) async {
    await _client.from('notification_templates').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listNotificationHistory() async {
    final data = await _client
        .from('notification_history')
        .select('id, title, body, recipients_count, status, sent_at, views, error')
        .order('sent_at', ascending: false);
    return _asMapList(data);
  }

  Future<void> deleteNotificationHistory(String id) async {
    await _client.from('notification_history').delete().eq('id', id);
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    required List<Map<String, dynamic>> recipients,
    String? historyId,
  }) {
    return _client.functions.invoke('send-notification', body: {
      'title': title,
      'body': body,
      'recipients': recipients,
      'history_id': historyId,
    });
  }

  Future<Map<String, dynamic>?> insertNotificationHistory(
      Map<String, dynamic> values) async {
    final data =
        await _client.from('notification_history').insert(values).select().single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateNotificationHistory(
      String id, Map<String, dynamic> values) async {
    await _client.from('notification_history').update(values).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listRecipients() async {
    final data = await _client
        .from('profiles')
        .select('id, name, email, role, subscription_status')
        .neq('role', 'superadmin')
        .order('name', ascending: true);
    return _asMapList(data);
  }

  // ==========================================================================
  // Webhooks
  // ==========================================================================

  Future<Map<String, dynamic>?> fetchWebhookConfig() async {
    final data =
        await _client.from('webhook_config').select().eq('id', 1).maybeSingle();
    return data;
  }

  Future<void> saveWebhookConfig(Map<String, dynamic> values) async {
    await _client
        .from('webhook_config')
        .upsert({'id': 1, ...values, 'updated_at': DateTime.now().toIso8601String()});
  }

  Future<List<Map<String, dynamic>>> listWebhookLogs({int limit = 50}) async {
    final data = await _client
        .from('webhook_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return _asMapList(data);
  }

  Future<void> triggerBillReminders(String dueDate) {
    return _client.functions.invoke(
      'check-bill-reminders-due',
      body: {'dueDate': dueDate},
    );
  }

  Future<void> testWebhookSender({
    required String url,
    required String secret,
  }) {
    return _client.functions.invoke('webhook-sender', body: {
      'url': url,
      'event': 'test.webhook',
      'payload': {
        'id': 'test-123',
        'amount': 100,
        'type': 'income',
        'description': 'Teste de webhook',
      },
      if (secret.isNotEmpty) 'secret': secret,
    });
  }

  // ==========================================================================
  // Afiliados
  // ==========================================================================

  Future<Map<String, dynamic>?> fetchAffiliateConfig() async {
    final data =
        await _client.from('affiliate_config').select().eq('id', 1).maybeSingle();
    return data;
  }

  Future<void> saveAffiliateConfig(Map<String, dynamic> values) async {
    await _client.from('affiliate_config').upsert({
      'id': 1,
      ...values,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> fetchAffiliateStats() async {
    final referrals = await _client.from('affiliate_referrals').select('id');
    final earnings =
        await _client.from('affiliate_earnings').select('points, status');
    final withdrawals = await _client
        .from('affiliate_withdrawals')
        .select('amount_brl, status');

    final earningList = _asMapList(earnings);
    final withdrawalList = _asMapList(withdrawals);

    var activePoints = 0;
    for (final earning in earningList) {
      if (earning['status'] == 'available') {
        activePoints += ((earning['points'] ?? 0) as num).toInt();
      }
    }

    final pending = withdrawalList
        .where((withdrawal) => withdrawal['status'] == 'pending')
        .toList();
    final pendingValue = pending.fold<double>(
      0,
      (sum, withdrawal) => sum + ((withdrawal['amount_brl'] ?? 0) as num).toDouble(),
    );

    return {
      'referrals': _asMapList(referrals).length,
      'active_points': activePoints,
      'pending_withdrawals': pending.length,
      'pending_value': pendingValue,
    };
  }

  Future<List<Map<String, dynamic>>> listAffiliateReferrals({int limit = 50}) async {
    final data = await _client
        .from('affiliate_referrals')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return _asMapList(data);
  }

  Future<List<Map<String, dynamic>>> listAffiliateWithdrawals({int limit = 50}) async {
    final data = await _client
        .from('affiliate_withdrawals')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return _asMapList(data);
  }

  Future<void> approveWithdrawal({
    required String withdrawalId,
    required String status,
  }) {
    return _client.functions.invoke('affiliate-approve-withdrawal', body: {
      'withdrawalId': withdrawalId,
      'status': status,
    });
  }

  // ==========================================================================
  // Analytics
  // ==========================================================================

  Future<Map<String, dynamic>?> fetchAnalyticsSettings() async {
    final data = await _client
        .from('global_settings')
        .select('facebook_pixel_id, gtm_id, google_analytics_id')
        .eq('id', 1)
        .maybeSingle();
    return data;
  }

  Future<void> saveAnalyticsSettings({
    required String? facebookPixelId,
    required String? gtmId,
    required String? googleAnalyticsId,
  }) async {
    await _client.from('global_settings').update({
      'facebook_pixel_id': facebookPixelId,
      'gtm_id': gtmId,
      'google_analytics_id': googleAnalyticsId,
    }).eq('id', 1);
  }

  // ==========================================================================
  // Educação
  // ==========================================================================

  Future<List<Map<String, dynamic>>> listEducationContent() async {
    final data = await _client
        .from('education_content')
        .select(
            'id, title, description, type, link, status, cover_image, clicks, published_at')
        .order('published_at', ascending: false);
    return _asMapList(data);
  }

  Future<void> createEducationContent(Map<String, dynamic> values) async {
    await _client.from('education_content').insert({
      ...values,
      'published_at': DateTime.now().toIso8601String(),
      'clicks': 0,
    });
  }

  Future<void> updateEducationContent(
      String id, Map<String, dynamic> values) async {
    await _client.from('education_content').update(values).eq('id', id);
  }

  Future<void> deleteEducationContent(String id) async {
    await _client.from('education_content').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listEducationClicks(String contentId) async {
    final data = await _client
        .from('education_clicks')
        .select('id, user_id, clicked_at, user_agent')
        .eq('education_content_id', contentId)
        .order('clicked_at', ascending: false);
    return _asMapList(data);
  }

  // ==========================================================================
  // Configurações globais
  // ==========================================================================

  Future<Map<String, dynamic>?> fetchGlobalSettings() async {
    final data =
        await _client.from('global_settings').select().eq('id', 1).maybeSingle();
    return data;
  }

  Future<void> updateGlobalSettings(Map<String, dynamic> values) async {
    await _client.from('global_settings').upsert({'id': 1, ...values});
  }

  /// Zona de perigo: remove transações/metas/notificações/categorias de todos
  /// os usuários, exceto do superadmin informado.
  Future<void> clearUserData(String adminId) async {
    await Future.wait([
      _client.from('transactions').delete().neq('user_id', adminId),
      _client.from('goals').delete().neq('user_id', adminId),
      _client.from('notifications').delete().neq('user_id', adminId),
      _client.from('categories').delete().neq('user_id', adminId),
    ]);
  }

  // ==========================================================================
  // WhatsApp
  // ==========================================================================

  Future<List<Map<String, dynamic>>> listWhatsAppMessages() async {
    final data = await _client
        .from('whatsapp_messages')
        .select('id, whatsapp, type, content, direction, timestamp, media_url')
        .order('timestamp', ascending: false)
        .limit(500);
    return _asMapList(data);
  }

  Future<List<Map<String, dynamic>>> listWhatsAppContacts() async {
    final data = await _client
        .from('profiles')
        .select('id, name, email, whatsapp');
    return _asMapList(data);
  }

  Future<void> sendWhatsAppMessage({
    required String to,
    required String message,
  }) {
    return _client.functions.invoke(
      'send-whatsapp-message',
      body: {'to': to, 'message': message},
    );
  }

  Future<void> deleteWhatsAppChat(String whatsapp) async {
    await _client.from('whatsapp_messages').delete().eq('whatsapp', whatsapp);
  }

  /// Atualiza dados de contato do usuário (usado no painel de WhatsApp).
  Future<void> updateUserContact({
    required String userId,
    required String name,
    required String email,
    required String whatsapp,
  }) async {
    await _client.from('profiles').update({
      'name': name,
      'email': email,
      'whatsapp': whatsapp,
    }).eq('id', userId);
  }

  // ==========================================================================
  // Helpers
  // ==========================================================================

  List<Map<String, dynamic>> _asMapList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }
}
