import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _dailyEnabled = false;
  TimeOfDay _dailyTime = const TimeOfDay(hour: 7, minute: 0);
  List<Map<String, dynamic>> _customReminders = [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyEnabled = prefs.getBool('daily_enabled') ?? false;
      final h = prefs.getInt('daily_hour') ?? 7;
      final m = prefs.getInt('daily_minute') ?? 0;
      _dailyTime = TimeOfDay(hour: h, minute: m);
      final raw = prefs.getString('custom_reminders');
      if (raw != null) {
        _customReminders = List<Map<String, dynamic>>.from(jsonDecode(raw));
      }
    });
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_enabled', _dailyEnabled);
    await prefs.setInt('daily_hour', _dailyTime.hour);
    await prefs.setInt('daily_minute', _dailyTime.minute);
    await prefs.setString('custom_reminders', jsonEncode(_customReminders));
  }

  // ── Toggle daily reminder ──────────────────────────────────────────────────
  Future<void> _toggleDaily(bool val) async {
    setState(() => _dailyEnabled = val);
    if (val) {
      await NotificationService().scheduleDailyNotification(
        id: 0,
        hour: _dailyTime.hour,
        minute: _dailyTime.minute,
      );
    } else {
      await NotificationService().cancelNotification(0);
    }
    await _saveReminders();
  }

  // ── Pick daily time ────────────────────────────────────────────────────────
  Future<void> _pickDailyTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.gold,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dailyTime = picked);
      if (_dailyEnabled) {
        await NotificationService().cancelNotification(0);
        await NotificationService().scheduleDailyNotification(
          id: 0,
          hour: picked.hour,
          minute: picked.minute,
        );
      }
      await _saveReminders();
    }
  }

  // ── Add custom reminder ────────────────────────────────────────────────────
  Future<void> _addCustomReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.gold,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final id = DateTime.now().millisecondsSinceEpoch % 10000 + 1;
      final reminder = {
        'id': id,
        'hour': picked.hour,
        'minute': picked.minute,
        'enabled': true,
      };
      setState(() => _customReminders.add(reminder));
      await NotificationService().scheduleDailyNotification(
        id: id,
        hour: picked.hour,
        minute: picked.minute,
      );
      await _saveReminders();
    }
  }

  // ── Toggle custom reminder ─────────────────────────────────────────────────
  Future<void> _toggleCustom(int index, bool val) async {
    setState(() => _customReminders[index]['enabled'] = val);
    final r = _customReminders[index];
    if (val) {
      await NotificationService().scheduleDailyNotification(
        id: r['id'],
        hour: r['hour'],
        minute: r['minute'],
      );
    } else {
      await NotificationService().cancelNotification(r['id']);
    }
    await _saveReminders();
  }

  // ── Delete custom reminder ─────────────────────────────────────────────────
  Future<void> _deleteCustom(int index) async {
    final id = _customReminders[index]['id'];
    await NotificationService().cancelNotification(id);
    setState(() => _customReminders.removeAt(index));
    await _saveReminders();
  }

  // ── Format time ───────────────────────────────────────────────────────────
  String _formatTime(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textSecond, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Reminders',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Daily reminder ───────────────────────────────────────────────
          _sectionTitle('Daily Reminder'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                // Toggle row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Enable Daily Reminder',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text('Once every day at a fixed time',
                            style: TextStyle(
                              color: AppColors.textSecond,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _dailyEnabled,
                        onChanged: _toggleDaily,
                        activeColor: AppColors.gold,
                      ),
                    ],
                  ),
                ),

                if (_dailyEnabled) ...[
                  Divider(color: Colors.white.withOpacity(0.05)),
                  // Time picker row
                  GestureDetector(
                    onTap: _pickDailyTime,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reminder Time',
                            style: TextStyle(
                              color: AppColors.textSecond,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _formatTime(_dailyTime.hour, _dailyTime.minute),
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.chevron_right_rounded,
                                  color: AppColors.textHint, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Custom reminders ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('Custom Reminders'),
              GestureDetector(
                onTap: _addCustomReminder,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, color: AppColors.gold, size: 16),
                      const SizedBox(width: 4),
                      Text('Add',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_customReminders.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Center(
                child: Text('No custom reminders yet.\nTap Add to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecond, fontSize: 13)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customReminders.length,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.white.withOpacity(0.05), height: 1),
                itemBuilder: (_, i) {
                  final r = _customReminders[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notifications_rounded,
                                color: AppColors.gold.withOpacity(0.6), size: 18),
                            const SizedBox(width: 12),
                            Text(
                              _formatTime(r['hour'], r['minute']),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Switch(
                              value: r['enabled'] ?? true,
                              onChanged: (val) => _toggleCustom(i, val),
                              activeColor: AppColors.gold,
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: Colors.redAccent.withOpacity(0.7),
                                  size: 20),
                              onPressed: () => _deleteCustom(i),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
      style: TextStyle(
        color: AppColors.textSecond,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }
}