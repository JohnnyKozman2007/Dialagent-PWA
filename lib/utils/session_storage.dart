// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class SessionStorage {
  static void setItem(String key, String value) {
    html.window.sessionStorage[key] = value;
  }

  static String? getItem(String key) {
    return html.window.sessionStorage[key];
  }

  static void removeItem(String key) {
    html.window.sessionStorage.remove(key);
  }

  static void clear() {
    html.window.sessionStorage.clear();
  }

  static void setTwoFAVerified(bool verified) {
    setItem('2fa_verified', verified ? 'true' : 'false');
  }

  static bool isTwoFAVerified() {
    return getItem('2fa_verified') == 'true';
  }

  static void setPasswordVerified(bool verified) {
    setItem('password_verified', verified ? 'true' : 'false');
  }

  static bool isPasswordVerified() {
    return getItem('password_verified') == 'true';
  }
}
