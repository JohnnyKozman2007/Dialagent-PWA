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

  // New methods used by login and 2FA screens
  static void setTwoFAVerified(bool verified) {
    setItem('2fa_verified', verified ? 'true' : 'false');
  }

  static bool isTwoFAVerified() {
    return getItem('2fa_verified') == 'true';
  }
}
