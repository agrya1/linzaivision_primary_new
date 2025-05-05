import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initializePlatformDatabase() {
  if (Platform.isWindows || Platform.isLinux) {
    // Windows/Linux 需要使用 FFI
    sqfliteFfiInit();
    // 设置数据库工厂
    databaseFactory = databaseFactoryFfi;
  } else if (Platform.isAndroid || Platform.isIOS) {
    // Android/iOS 使用默认的 databaseFactory
    // 不需要特殊初始化
  } else {
    throw UnsupportedError('Unsupported platform for SQLite database');
  }
}
