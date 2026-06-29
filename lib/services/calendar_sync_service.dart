import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';   // <-- changed
import 'package:my_restaurant_app/models/task_model.dart';

class CalendarSyncService {
  static final FirebaseFunctions functions = FirebaseFunctions.instance;

  // Call the Cloud Function to sync task to Google Calendar
  static Future<void> syncTaskToCalendar(Task task) async {
    try {
      final callable = functions.httpsCallable('syncTaskToCalendar');
      await callable.call({
        'taskId': task.id,
        'task': task.toMap(),
      });
    } catch (e) {
      print('Error syncing to calendar: $e');
    }
  }

  // Delete calendar event
  static Future<void> deleteCalendarEvent(String? calendarEventId) async {
    if (calendarEventId == null) return;
    try {
      final callable = functions.httpsCallable('deleteCalendarEvent');
      await callable.call({'calendarEventId': calendarEventId});
    } catch (e) {
      print('Error deleting calendar event: $e');
    }
  }
}
