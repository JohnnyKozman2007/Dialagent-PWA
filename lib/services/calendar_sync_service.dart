import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_restaurant_app/models/task_model.dart';

class CalendarSyncService {
  // Call the Supabase Edge Function to sync task to Google Calendar
  static Future<void> syncTaskToCalendar(Task task) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'sync-calendar',
        body: {
          'action': 'sync',
          'taskId': task.id,
          'task': task.toSupabase(),
          'calendarEventId': task.calendarEventId,
        },
      );
    } catch (e) {
      print('Error syncing to calendar: $e');
    }
  }

  // Delete calendar event
  static Future<void> deleteCalendarEvent(String? calendarEventId) async {
    if (calendarEventId == null || calendarEventId.isEmpty) return;
    try {
      await Supabase.instance.client.functions.invoke(
        'sync-calendar',
        body: {
          'action': 'delete',
          'calendarEventId': calendarEventId,
        },
      );
    } catch (e) {
      print('Error deleting calendar event: $e');
    }
  }
}
