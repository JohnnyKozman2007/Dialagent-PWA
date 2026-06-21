import 'dart:html' as html;

class SessionStorage {
  static const String _twoFAVerifiedKey = 'twoFAVerified';

  static bool isTwoFAVerified() {
    final value = html.window.sessionStorage[_twoFAVerifiedKey];
    return value == 'true';
  }

  static void setTwoFAVerified(bool value) {
    html.window.sessionStorage[_twoFAVerifiedKey] = value.toString();
  }

  static void clear() {
    html.window.sessionStorage.remove(_twoFAVerifiedKey);
  }
}
