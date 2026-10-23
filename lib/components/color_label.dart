import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Human-readable names for the standard palette, with a custom-color fallback.
String colorLabel(Color color) {
  if (color.a == 0) return 'noColor'.tr();
  const names = <int, String>{
    0xFFFFFFFF: 'colorWhite',
    0xFF000000: 'colorBlack',
    0xFFF44336: 'colorRed',
    0xFFE91E63: 'colorPink',
    0xFF9C27B0: 'colorPurple',
    0xFF673AB7: 'colorDeepPurple',
    0xFF3F51B5: 'colorIndigo',
    0xFF2196F3: 'colorBlue',
    0xFF03A9F4: 'colorLightBlue',
    0xFF00BCD4: 'colorCyan',
    0xFF009688: 'colorTeal',
    0xFF4CAF50: 'colorGreen',
    0xFF8BC34A: 'colorLightGreen',
    0xFFCDDC39: 'colorLime',
    0xFFFFEB3B: 'colorYellow',
    0xFFFFC107: 'colorAmber',
    0xFFFF9800: 'colorOrange',
    0xFFFF5722: 'colorDeepOrange',
    0xFF795548: 'colorBrown',
    0xFF9E9E9E: 'colorGrey',
    0xFF607D8B: 'colorBlueGrey',
  };
  return (names[color.toARGB32()] ?? 'colorCustom').tr();
}
