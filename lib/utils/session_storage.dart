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

  static void clearAll() {
    try {
      // Clear sessionStorage completely (wipes 2FA verification states)
      html.window.sessionStorage.clear();

      // Clear localStorage selectively, preserving the theme configuration
      final keys = html.window.localStorage.keys.toList();
      for (final key in keys) {
        if (key != 'flutter.theme_preference' && key != 'flutter.darkMode') {
          html.window.localStorage.remove(key);
        }
      }
    } catch (_) {}
  }

  static bool isAuthCallback() {
    try {
      final href = html.window.location.href;
      final hash = html.window.location.hash;
      return hash.contains('access_token=') || href.contains('code=') || href.contains('error=');
    } catch (_) {
      return false;
    }
  }

  // ADD THESE:
  static void setTwoFAVerified(bool verified) {
    setItem('2fa_verified', verified ? 'true' : 'false');
  }

  static bool isTwoFAVerified() {
    return getItem('2fa_verified') == 'true';
  }
}
