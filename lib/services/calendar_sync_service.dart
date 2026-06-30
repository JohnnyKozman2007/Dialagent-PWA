import 'package:my_restaurant_app/models/task_model.dart';

class CalendarSyncService {
  // Call the Cloud Function to sync task to Google Calendar
  static Future<void> syncTaskToCalendar(Task task) async {
    try {
      // Mocked for Supabase migration
      print('Mocked: Sync task to calendar: ${task.id}');
    } catch (e) {
      print('Error syncing to calendar: $e');
    }
  }

  // Delete calendar event
  static Future<void> deleteCalendarEvent(String? calendarEventId) async {
    if (calendarEventId == null) return;
    try {
      // Mocked for Supabase migration
      print('Mocked: Delete calendar event: $calendarEventId');
    } catch (e) {
      print('Error deleting calendar event: $e');
    }
  }
}
