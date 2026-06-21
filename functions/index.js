// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();

// Service account key – set environment variable GOOGLE_APPLICATION_CREDENTIALS
const auth = new google.auth.GoogleAuth({
  keyFile: './service-account-key.json', // or use environment variable
  scopes: ['https://www.googleapis.com/auth/calendar'],
});

const calendar = google.calendar({ version: 'v3', auth });
const CALENDAR_ID = 'your-restaurant-calendar@group.calendar.google.com'; // Replace!

exports.syncTaskToCalendar = functions.https.onCall(async (data, context) => {
  const { taskId, task } = data;
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');

  const docRef = admin.firestore().collection('tasks').doc(taskId);
  const doc = await docRef.get();
  if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Task not found');

  const taskData = doc.data();
  const event = {
    summary: taskData.title,
    description: taskData.description,
    start: { dateTime: taskData.dueDate?.toDate?.()?.toISOString() || new Date().toISOString() },
    end: { dateTime: taskData.dueDate?.toDate?.()?.toISOString() || new Date().toISOString() },
    attendees: taskData.assignedTo ? [{ email: taskData.assignedTo + '@yourdomain.com' }] : [], // need actual emails
    status: 'confirmed',
  };

  try {
    let response;
    if (taskData.calendarEventId) {
      // Update existing event
      response = await calendar.events.update({
        calendarId: CALENDAR_ID,
        eventId: taskData.calendarEventId,
        resource: event,
      });
    } else {
      // Create new event
      response = await calendar.events.insert({
        calendarId: CALENDAR_ID,
        resource: event,
      });
      // Save event ID back to Firestore
      await docRef.update({ calendarEventId: response.data.id, syncedToCalendar: true });
    }
    return { success: true, eventId: response.data.id };
  } catch (error) {
    console.error('Calendar sync error:', error);
    throw new functions.https.HttpsError('internal', 'Calendar sync failed');
  }
});

exports.deleteCalendarEvent = functions.https.onCall(async (data, context) => {
  const { calendarEventId } = data;
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  if (!calendarEventId) throw new functions.https.HttpsError('invalid-argument', 'Missing event ID');

  try {
    await calendar.events.delete({
      calendarId: CALENDAR_ID,
      eventId: calendarEventId,
    });
    return { success: true };
  } catch (error) {
    console.error('Delete calendar event error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to delete event');
  }
});
