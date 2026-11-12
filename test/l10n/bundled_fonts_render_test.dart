import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:blood_pressure_app/theme/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registered fonts render script glyphs and color emoji', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.where(
      (e) => (e['family'] as String).startsWith('Noto'),
    )) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    Future<ui.Image> render(
      String text,
      ui.Locale locale, {
      String family = 'NotoSans',
      int width = 800,
    }) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
      final builder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textDirection: locale.languageCode == 'ar'
                    ? ui.TextDirection.rtl
                    : ui.TextDirection.ltr,
                fontSize: 48,
                fontFamily: family,
                locale: locale,
              ),
            )
            ..pushStyle(
              ui.TextStyle(
                color: const ui.Color(0xff102b1e),
                fontFamily: family,
                fontFamilyFallback: appFontFallbacks(locale),
              ),
            )
            ..addText(text);
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: width.toDouble() - 32));
      canvas.drawParagraph(paragraph, const ui.Offset(16, 12));
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, 100);
      paragraph.dispose();
      picture.dispose();
      return image;
    }

    for (final sample in [
      ('ع', 'ar'),
      ('本', 'ja'),
      ('語', 'ja'),
      ('中', 'zh'),
      ('文', 'zh'),
      ('體', 'zh'),
      ('·', 'en'),
    ]) {
      final glyph = await render(sample.$1, ui.Locale(sample.$2), width: 100);
      final tofu = await render('\u{10ffff}', ui.Locale(sample.$2), width: 100);
      final actual = (await glyph.toByteData())!.buffer.asUint8List();
      final missing = (await tofu.toByteData())!.buffer.asUint8List();
      expect(
        actual,
        isNot(orderedEquals(missing)),
        reason: '${sample.$2} must not render the missing-glyph box',
      );
      glyph.dispose();
      tofu.dispose();
    }
    final emoji = await render(
      '🇸🇦 🇬🇧 ☀️ 🌙 🖥️ 😀',
      const ui.Locale('en'),
      family: 'NotoColorEmoji',
    );
    final pixels = (await emoji.toByteData())!.buffer.asUint8List();
    var saturatedPixels = 0;
    for (var i = 0; i < pixels.length; i += 4) {
      if ((pixels[i] - pixels[i + 1]).abs() > 60 ||
          (pixels[i + 1] - pixels[i + 2]).abs() > 60)
        saturatedPixels++;
    }
    expect(
      saturatedPixels,
      greaterThan(200),
      reason: 'Emoji must contain color glyph pixels, not empty/tofu boxes',
    );
    if (const bool.fromEnvironment('captureBundledFonts')) {
      final directory = Directory('build/font-audit')
        ..createSync(recursive: true);
      await File('${directory.path}/emoji.png').writeAsBytes(
        (await emoji.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List(),
      );
      for (final sample in [
        ('العربية · مرحباً بك في الجنان', 'ar'),
        ('日本語 · 健康記録', 'ja'),
        ('中文 · 健康记录 · 健康記錄', 'zh'),
      ]) {
        final image = await render(sample.$1, ui.Locale(sample.$2));
        await File('${directory.path}/${sample.$2}.png').writeAsBytes(
          (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
              .asUint8List(),
        );
        image.dispose();
      }
    }
    emoji.dispose();
  });
}
