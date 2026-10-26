import 'package:flutter/material.dart';

/// Opens a launch destination above Home without inventing parent screens
/// from the URL segments (for example, two copies of the medication tabs).
List<Route<dynamic>> initialRouteStack(
  String initialRoute,
  Map<String, WidgetBuilder> routes,
) => [
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: Navigator.defaultRouteName),
    builder: routes[Navigator.defaultRouteName]!,
  ),
  if (initialRoute != Navigator.defaultRouteName &&
      routes[initialRoute] != null)
    MaterialPageRoute<void>(
      settings: RouteSettings(name: initialRoute),
      builder: routes[initialRoute]!,
    ),
];
