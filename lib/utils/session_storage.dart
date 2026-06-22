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
}
