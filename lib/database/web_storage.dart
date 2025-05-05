// ignore: avoid_web_libraries_in_flutter
import 'dart:html' if (dart.library.io) 'web_storage_stub.dart';

class WebStorage {
  static void saveData(String key, String value) {
    window.localStorage[key] = value;
  }

  static String? getData(String key) {
    return window.localStorage[key];
  }
}
