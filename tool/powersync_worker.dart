// Compile against the app's lockfile, matching Hisab's web build. Downloading
// a precompiled worker can mismatch the app's sqlite_async protocol version.
import 'package:powersync/web_worker.dart' as worker;

void main() => worker.main();
