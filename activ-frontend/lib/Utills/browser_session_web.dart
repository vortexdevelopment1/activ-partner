import 'package:web/web.dart' as web;

const isBrowserSession = true;
const _prefix = 'activ_partner.';

String? readBrowserSession(String key) {
  try {
    return web.window.sessionStorage.getItem('$_prefix$key');
  } catch (_) {
    return null;
  }
}

void writeBrowserSession(String key, String value) {
  try {
    web.window.sessionStorage.setItem('$_prefix$key', value);
  } catch (_) {
    // Storage may be unavailable in restricted browser contexts.
  }
}

void removeBrowserSession(String key) {
  try {
    web.window.sessionStorage.removeItem('$_prefix$key');
  } catch (_) {}
}

void clearBrowserSession() {
  try {
    final storage = web.window.sessionStorage;
    final keys = <String>[];
    for (var i = 0; i < storage.length; i++) {
      final key = storage.key(i);
      if (key != null && key.startsWith(_prefix)) keys.add(key);
    }
    for (final key in keys) {
      storage.removeItem(key);
    }
  } catch (_) {}
}
