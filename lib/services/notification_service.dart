import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Inicialització de timezones
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint("Error setting local timezone: $e. Falling back to Europe/Madrid.");
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
      } catch (ex) {
        // Fallback a UTC si tot falla
      }
    }

    // Configurar icona genèrica de notificació
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);

    try {
      final platform = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (platform != null) {
        final enabled = await platform.areNotificationsEnabled() ?? false;
        debugPrint("DIAGNOSTICS: Notifications enabled = $enabled");
      }
    } catch (e) {
      debugPrint("Error running notification diagnostics: $e");
    }
  }

  Future<bool> requestNotificationPermission() async {
    final platform = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (platform != null) {
      final granted = await platform.requestNotificationsPermission();
      return granted ?? false;
    }
    final iosPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlatform != null) {
      final granted = await iosPlatform.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  Future<bool> requestExactAlarmsPermission() async {
    final platform = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (platform != null) {
      final granted = await platform.requestExactAlarmsPermission();
      return granted ?? false;
    }
    return false;
  }

  Future<void> scheduleExposureNotifications({
    required int vitDSeconds,
    required int maxDoseSeconds,
    required String lang,
    required String Function(String lang, String key) textGetter,
  }) async {
    try {
      final platform = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (platform != null) {
        final enabled = await platform.areNotificationsEnabled() ?? false;
        debugPrint("DIAGNOSTICS: scheduleExposureNotifications called. areNotificationsEnabled = $enabled");
      }
    } catch (e) {
      debugPrint("DIAGNOSTICS: Error checking permission: $e");
    }

    // Primer cancel·lem les existents per evitar duplicitats o col·lisions
    await cancelAllExposureNotifications();

    // 1. Notificació de Vitamina D
    if (vitDSeconds > 0) {
      final String title = textGetter(lang, 'vitamin_d');
      final String body = textGetter(lang, 'vit_d_100_percent');
      await _scheduleSingleNotification(
        id: 1,
        title: title,
        body: body,
        secondsFromNow: vitDSeconds,
      );
      debugPrint("Notificació de Vitamina D programada en $vitDSeconds segons.");
    }

    // 2. Notificació de Dosi Solar Màxima
    if (maxDoseSeconds > 0) {
      final String title = textGetter(lang, 'solar_dose_pct');
      final String body = textGetter(lang, 'safe_exposure_finished_body');
      await _scheduleSingleNotification(
        id: 2,
        title: title,
        body: body,
        secondsFromNow: maxDoseSeconds,
      );
      debugPrint("Notificació de Dosi Solar Màxima programada en $maxDoseSeconds segons.");
    }
  }

  Future<void> _scheduleSingleNotification({
    required int id,
    required String title,
    required String body,
    required int secondsFromNow,
  }) async {
    final tz.TZDateTime tzScheduledTime =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow));

    debugPrint("DIAGNOSTICS: Scheduling notification ID $id at $tzScheduledTime. Device clock is ${DateTime.now()}. Timezone local is ${tz.local}");

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sun_exposure_channel',
      'Alertes d\'Exposició Solar',
      channelDescription: 'Notificacions quan s\'assoleix la Vitamina D o el límit de radiació solar.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzScheduledTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelAllExposureNotifications() async {
    await _notificationsPlugin.cancel(id: 1);
    await _notificationsPlugin.cancel(id: 2);
    debugPrint("Notificacions de l'exposició cancel·lades.");
  }
}
