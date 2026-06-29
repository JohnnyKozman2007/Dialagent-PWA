import '../models/task_model.dart';

class CalendarSyncService {
  // Call the Cloud Function to sync task to Google Calendar
  static Future<void> syncTaskToCalendar(Task task) async {
    print('Calendar sync: mocked sync for task ${task.id}');
  }

  // Delete calendar event
  static Future<void> deleteCalendarEvent(String? calendarEventId) async {
    if (calendarEventId == null) return;
    print('Calendar sync: mocked delete for event $calendarEventId');
  }
}
