import 'dart:io';

import 'package:archive/archive.dart';
import 'package:blood_pressure_app/core/database/health_database.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/storage/file_settings_loader.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:safaeh/safaeh.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

/// A static location to report errors to and disrupt the program flow in case
/// there is the risk of data loss when continuing.
class ErrorReporting {
  ErrorReporting._create();

  /// Whether there is already an critical error displayed.
  static bool isErrorState = false;

  /// Replaces the application with an ErrorScreen.
  ///
  /// This method can be used to avoid running any further code in your current function, by awaiting
  static Future<void> reportCriticalError(String title, String text) async {
    if (isErrorState) throw Exception('Tried to report another error:\n title = $title,\n text = $text');
    isErrorState = true;
    try {
      Log.severe('$title: $text');
    } catch (_) {}
    runApp(ErrorScreen(
      title: title,
      text: text,
      debugInfo: await _carefullyCollectDebugInfo(),
    ),);
    return Future.delayed(const Duration(days: 30,));
  }

  static Future<PackageInfo> _carefullyCollectDebugInfo() async {
    PackageInfo packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      packageInfo = PackageInfo(appName: 'err', packageName: 'err', version: 'err', buildNumber: 'err');
    }

    return packageInfo;
  }
}

/// A full [MaterialApp] that is especially safe against throwing errors and
/// allows for debugging and data extraction.
class ErrorScreen extends StatelessWidget {
  
  const ErrorScreen({super.key, required this.title, required this.text, required this.debugInfo});

  final String title;
  final String text;
  final PackageInfo debugInfo;

  // This screen can replace the app before localization has initialized.
  String _label(String key, String fallback) {
    try {
      final value = key.tr();
      return value == key ? fallback : value;
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      title: _label('criticalError', 'Unable to continue'),
      locale: localeFromLanguageKey(Intl.getCurrentLocale().replaceAll('_', '-')) ?? const Locale('en'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => SafaehFeedbackHost(
        itemWidthBuilder: toastItemWidth,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(_label('criticalError', 'Unable to continue')),
          backgroundColor: Colors.red,
        ),
        body: Builder(
          builder: (context) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20,),
                  Text(_label('criticalErrorHelp', 'Copy the error details to report the problem, or save a copy of your data below.')),
                  const SizedBox(height: 20),
                  Text(_label('versionOf', 'Version: {version}').replaceAll('{version}', debugInfo.version)),
                  Text(_label('buildNumberOf', 'Build number: {buildNumber}').replaceAll('{buildNumber}', debugInfo.buildNumber)),
                  const Divider(),
                  Text(title, style: const TextStyle(fontSize: 20, ), ),
                  Text(text),
                  const Divider(),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Error:\nBuild number:${debugInfo.buildNumber}\n-----\n$title:\n---\n$text\n',
                      ),);
                      context.showSuccess(_label('copiedToClipboard', 'Copied to clipboard'));
                    },
                    child: Text(_label('copyError', 'Copy error details')),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        final url = Uri.parse('https://github.com/Zyzto/blood-pressure-monitor-fl/issues');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } else if (context.mounted) {
                          context.showError(_label('errCantOpenURL', 'Cannot open: {url}').replaceAll('{url}', url.toString()));
                        }
                      } catch (e) {
                        if (context.mounted) context.showError('ERR: $e');
                      }
                    },
                    child: Text(_label('reportIssue', 'Report a problem')),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await FileSettingsLoader.flushWrites();
                        final loader = await FileSettingsLoader.load();
                        final archive = await loader.createArchive();
                        await FilePicker.saveFile(
                          type: FileType.any, // application/zip
                          fileName: 'bloodPressureSettings.zip',
                          bytes: ZipEncoder().encodeBytes(archive!),
                        );
                      } catch(e) {
                        if (context.mounted) context.showError('ERR: $e');
                      }
                    },
                    child: Text(_label('rescueSettings', 'Save settings backup')),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        final dir = await getDatabasesPath();
                        assert(dir != inMemoryDatabasePath);
                        final candidates = [
                          join(dir, HealthDatabase.fileName),
                          join(dir, HealthDatabase.legacyBackupName),
                          join(dir, HealthDatabase.legacyFileName),
                        ];
                        final path = candidates
                            .where((p) => File(p).existsSync())
                            .firstOrNull;
                        if (path == null) {
                          if (context.mounted) {
                            context.showError(_label('noDatabaseFile', 'No database file found.'));
                          }
                          return;
                        }
                        await FilePicker.saveFile(
                          fileName: basename(path),
                          bytes: File(path).readAsBytesSync(),
                          type: FileType.any, // application/vnd.sqlite3
                        );
                      } catch(e) {
                        if (context.mounted) context.showError('ERR: $e');
                      }
                    },
                    child: Text(_label('rescueDatabase', 'Save database backup')),
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  
}
