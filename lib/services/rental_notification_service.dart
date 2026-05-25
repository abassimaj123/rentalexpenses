import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class RentalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const _channelId = 'rental_monthly_reminder';
  static const _notifId = 200;

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin
        .initialize(const InitializationSettings(android: androidSettings));
  }

  /// Schedule on the 28th of each month at 10:00 AM — reminds before month-end.
  static Future<void> scheduleMonthlyReminder(bool isSpanish) async {
    await _plugin.cancel(_notifId);
    final now = tz.TZDateTime.now(tz.local);
    // next 28th at 10:00
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, 28, 10, 0);
    if (scheduled.isBefore(now)) {
      scheduled =
          tz.TZDateTime(tz.local, now.year, now.month + 1, 28, 10, 0);
    }
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Monthly Expense Reminder',
      channelDescription:
          'Reminds you to log your monthly rental expenses',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.zonedSchedule(
      _notifId,
      isSpanish
          ? '¡Registra tus gastos de renta!'
          : 'Log your rental expenses!',
      isSpanish
          ? 'Registra tus gastos de ${_monthNameEs(now.month)} antes de fin de mes.'
          : 'Log your ${_monthNameEn(now.month)} expenses before month end.',
      scheduled,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static String _monthNameEn(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month - 1];

  static String _monthNameEs(int month) => const [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ][month - 1];

  static Future<void> cancel() async => _plugin.cancel(_notifId);
}
