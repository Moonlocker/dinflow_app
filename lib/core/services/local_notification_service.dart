import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Serviço de notificações locais do DinFlow.
///
/// Exibe alertas do sistema quando chegam notificações do usuário via
/// Supabase Realtime (com o app aberto ou em segundo plano).
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;
  int _nextId = 0;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'dinflow_notifications',
        'Notificações DinFlow',
        channelDescription: 'Avisos e lembretes do DinFlow',
        importance: Importance.high,
        priority: Priority.high,
      );

  static const DarwinNotificationDetails _iosDetails =
      DarwinNotificationDetails();

  /// Inicializa o plugin e solicita as permissões necessárias.
  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    try {
      await _plugin.initialize(settings: settings);
    } catch (error) {
      debugPrint('Falha ao iniciar notificações locais: $error');
      return;
    }
    _initialized = true;
    await requestPermissions();
  }

  /// Solicita a permissão de notificações (Android 13+ / iOS).
  Future<void> requestPermissions() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (error) {
      debugPrint('Falha ao solicitar permissão de notificações: $error');
    }
  }

  /// Exibe uma notificação do sistema imediatamente.
  Future<void> show({required String title, String? body}) async {
    if (!_initialized) return;
    final text = (body ?? '').trim();
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: text.isEmpty ? null : text,
        notificationDetails: const NotificationDetails(
          android: _androidDetails,
          iOS: _iosDetails,
        ),
      );
    } catch (error) {
      debugPrint('Falha ao exibir notificação: $error');
    }
  }
}
