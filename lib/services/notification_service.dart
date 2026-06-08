import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyReminderId = 1001;
  static const int _budgetWarningId = 2001;
  static const String _budgetWarningPrefix = "budget_warning_sent";

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation("Asia/Ho_Chi_Minh"));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings: settings);
    await requestPermission();
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final macGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return androidGranted ?? iosGranted ?? macGranted ?? true;
  }

  Future<void> scheduleDailyReminder({
    required bool enabled,
    required String timeText,
  }) async {
    await initialize();
    await _plugin.cancel(id: _dailyReminderId);
    if (!enabled) return;

    final time = _parseTime(timeText);
    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: "Nhắc nhập giao dịch",
      body: "Bạn hãy cập nhật thu chi hôm nay để báo cáo chính xác hơn.",
      scheduledDate: _nextOccurrence(time.hour, time.minute),
      notificationDetails: _reminderDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showBudgetWarning({
    required String userId,
    required int year,
    required int month,
    required String key,
    required String title,
    required String body,
  }) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final sentKey = "$_budgetWarningPrefix:$userId:$year:$month:$key";
    final today = _dateKey(DateTime.now());
    final sentValue = prefs.get(sentKey);
    if (sentValue == true) {
      await prefs.remove(sentKey);
    } else if (sentValue == today) {
      return;
    }

    await _plugin.show(
      id: _budgetWarningId + key.hashCode.abs() % 1000,
      title: title,
      body: body,
      notificationDetails: _warningDetails(),
    );
    await prefs.setString(sentKey, today);
    await prefs.setString(
      "$sentKey:lastAlertAt",
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> resetBudgetWarning({
    required String userId,
    required int year,
    required int month,
    required String keyPrefix,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final suffix in ["80", "low", "100"]) {
      final key = "$_budgetWarningPrefix:$userId:$year:$month:$keyPrefix:$suffix";
      await prefs.remove(key);
      await prefs.remove("$key:lastAlertAt");
    }
  }

  NotificationDetails _reminderDetails() {
    const android = AndroidNotificationDetails(
      "daily_transaction_reminder",
      "Nhắc nhập giao dịch",
      channelDescription: "Nhắc người dùng nhập giao dịch hằng ngày",
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const darwin = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: darwin);
  }

  NotificationDetails _warningDetails() {
    const android = AndroidNotificationDetails(
      "budget_warning",
      "Cảnh báo ngân sách",
      channelDescription: "Cảnh báo khi chi tiêu vượt ngân sách",
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwin = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: darwin);
  }

  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  ({int hour, int minute}) _parseTime(String value) {
    final parts = value.split(":");
    final hour = int.tryParse(parts.first) ?? 22;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, "0");
    final day = date.day.toString().padLeft(2, "0");
    return "${date.year}-$month-$day";
  }
}
