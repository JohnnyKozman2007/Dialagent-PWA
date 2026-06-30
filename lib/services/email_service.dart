import 'package:http/http.dart' as http;

class EmailService {
  // 🔗 GOOGLE APPS SCRIPT HTTP WEB APP URL
  // You will deploy a tiny Apps Script on Google Drive under kozmanjohnny82@gmail.com
  // and paste the Web App URL here. Details are in walkthrough.md!
  static const String _gatewayUrl = 'https://script.google.com/macros/s/AKfycbww8aSutJqIriVHlG4EZ38jEqlkmdOE0meQ_RQAW45WGrZiRQDvXSJew1MVZMvizeRS/exec';

  static Future<void> sendInvitation({
    required String recipientEmail,
    required String role,
  }) async {
    if (_gatewayUrl == 'YOUR_GOOGLE_SCRIPT_WEB_APP_URL_HERE' || _gatewayUrl.isEmpty) {
      throw Exception(
        'Email HTTP Gateway is not configured.\n'
        'Please deploy the Google Apps Script (see walkthrough.md) '
        'and paste the URL in "lib/services/email_service.dart".'
      );
    }

    try {
      final uri = Uri.parse(_gatewayUrl).replace(
        queryParameters: {
          'recipient': recipientEmail,
          'role': role,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Gateway returned status code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('HTTP email send error: $e');
      rethrow;
    }
  }
}
