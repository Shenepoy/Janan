import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initializeNativeDatabaseFactory() {
  if (!Platform.isAndroid && !Platform.isIOS) {
    databaseFactory = databaseFactoryFfi;
  }
}
