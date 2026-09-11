import 'package:supabase_flutter/supabase_flutter.dart';

/// Dados de afiliação do usuário (tabelas `affiliate_*`).
class AffiliateRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>?> fetchConfig() async {
    final data =
        await _client.from('affiliate_config').select().eq('id', 1).maybeSingle();
    return data;
  }

  /// Estatísticas agregadas do afiliado.
  Future<Map<String, dynamic>> fetchStats(String userId) async {
    final referrals = await _client
        .from('affiliate_referrals')
        .select('status')
        .eq('affiliate_user_id', userId);
    final earnings = await _client
        .from('affiliate_earnings')
        .select('points, status')
        .eq('affiliate_user_id', userId);

    final referralList = (referrals as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final earningList = (earnings as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    var totalEarned = 0;
    var totalWithdrawn = 0;
    for (final earning in earningList) {
      final points = ((earning['points'] ?? 0) as num).toInt();
      if (points > 0) {
        totalEarned += points;
      } else {
        totalWithdrawn += points.abs();
      }
    }

    return {
      'total_referrals': referralList.length,
      'paid_referrals':
          referralList.where((r) => r['status'] == 'paid').length,
      'pending_referrals':
          referralList.where((r) => r['status'] == 'registered').length,
      'total_points': totalEarned,
      'available_points': totalEarned - totalWithdrawn,
      'withdrawn_points': totalWithdrawn,
    };
  }

  /// Indicações com dados do usuário indicado (RPC security definer).
  Future<List<Map<String, dynamic>>> fetchReferrals() async {
    final data = await _client.rpc('get_affiliate_referrals_with_users');
    return (data as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchEarnings(String userId) async {
    final data = await _client
        .from('affiliate_earnings')
        .select()
        .eq('affiliate_user_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchWithdrawals(String userId) async {
    final data = await _client
        .from('affiliate_withdrawals')
        .select()
        .eq('affiliate_user_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> requestWithdrawal({
    required int points,
    required String pixKey,
    required String pixType,
  }) {
    return _client.functions.invoke('affiliate-request-pix', body: {
      'pixDetails': {
        'points': points,
        'pixKey': pixKey,
        'pixType': pixType,
      },
    });
  }
}
