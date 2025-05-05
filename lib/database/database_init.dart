import 'database_init_stub.dart'
    if (dart.library.ffi) 'database_init_native.dart'
    if (dart.library.html) 'database_init_web.dart';

void initializeDatabase() {
  initializePlatformDatabase();
}
