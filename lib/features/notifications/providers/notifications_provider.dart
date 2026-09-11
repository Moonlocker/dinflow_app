import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/realtime/realtime_utils.dart';
import '../../../models/app_notification.dart';
import '../../../repositories/notifications_repository.dart';

/// Estado das notificações do usuário (sino do cabeçalho).
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({NotificationsRepository? repository})
      : _repository = repository ?? NotificationsRepository();

  final NotificationsRepository _repository;

  List<AppNotification> _items = const [];
  bool _loading = false;
  String? _userId;
  RealtimeChannel? _channel;
  String? _subscribedUserId;
  Timer? _debounce;

  List<AppNotification> get items => _items;
  bool get loading => _loading;
  int get unreadCount => _items.where((item) => !item.isRead).length;

  Future<void> load(String userId, {bool force = false}) async {
    if (_loading) return;
    if (!force && _userId == userId && _items.isNotEmpty) return;
    _userId = userId;
    _loading = true;
    notifyListeners();
    try {
      _items = await _repository.fetch(userId);
    } catch (_) {
      // Mantém a lista atual em caso de erro.
    }
    _loading = false;
    notifyListeners();
    _subscribe(userId);
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId, force: true);
  }

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
    await refresh();
  }

  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;
    await _repository.markAllAsRead(userId);
    await refresh();
  }

  void _subscribe(String userId) {
    if (_subscribedUserId == userId && _channel != null) return;
    _unsubscribe();
    _subscribedUserId = userId;
    _channel = Supabase.instance.client
        .channel(realtimeChannelName('notifications', userId))
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _scheduleReload(),
        )
        .subscribe();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final userId = _userId;
      if (userId != null) load(userId, force: true);
    });
  }

  void _unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
    _subscribedUserId = null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _unsubscribe();
    super.dispose();
  }
}
