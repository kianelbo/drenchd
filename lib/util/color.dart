import 'dart:ui' as ui;
import 'package:flutter/material.dart';


final Map<String, Future<int>> _emojiColorCache = <String, Future<int>>{};

String _emojiColorKey(String emoji) => emoji
    .trim()
    .replaceAll('\uFE0F', '')
    .replaceAll('\u200D', '')
    .replaceAll(RegExp(r'\s+'), '');

int fallbackEmojiColor(String emoji) {
  final key = _emojiColorKey(emoji);
  if (key.isEmpty) return 0xFF7B68EE;

  final hue = key.runes.fold<int>(
        0,
        (sum, rune) => (sum * 31 + rune) & 0x7fffffff,
      ) %
      360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.68, 0.42).toColor().toARGB32();
}

Future<int> emojiColorFor(String emoji) {
  final key = _emojiColorKey(emoji);
  if (key.isEmpty) return Future.value(0xFF7B68EE);

  final cached = _emojiColorCache[key];
  if (cached != null) return cached;

  final color = _resolveEmojiColor(key);
  _emojiColorCache[key] = color;
  return color;
}

Future<int> _resolveEmojiColor(String emoji) async {
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 128, 128));
    final textStyle = TextStyle(
      fontSize: 88,
      fontFamilyFallback: const [
        'Apple Color Emoji',
        'Segoe UI Emoji',
        'Noto Color Emoji',
        'EmojiOne Color',
        'Android Emoji',
      ],
    );
    final painter = TextPainter(
      text: TextSpan(text: emoji, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 128);

    final dx = (128 - painter.width) / 2;
    final dy = (128 - painter.height) / 2;
    canvas.drawColor(const Color(0x00000000), BlendMode.src);
    painter.paint(canvas, Offset(dx, dy));

    final picture = recorder.endRecording();
    final image = await picture.toImage(128, 128);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return fallbackEmojiColor(emoji);

    var totalWeight = 0.0;
    var rSum = 0.0;
    var gSum = 0.0;
    var bSum = 0.0;

    for (var i = 0; i < bytes.lengthInBytes; i += 4) {
      final alpha = bytes.getUint8(i + 3);
      if (alpha < 24) continue;

      final r = bytes.getUint8(i);
      final g = bytes.getUint8(i + 1);
      final b = bytes.getUint8(i + 2);

      final maxChannel = [r, g, b].reduce((a, b) => a > b ? a : b).toDouble();
      final minChannel = [r, g, b].reduce((a, b) => a < b ? a : b).toDouble();
      final luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      final saturation = maxChannel == 0 && minChannel == 0
          ? 0.0
          : (maxChannel - minChannel) / maxChannel;

      // Ignore near-white/neutral pixels since they usually represent the cup,
      // plate, or background, not the content/ink we actually want.
      final isNearWhite = luminance > 220 && saturation < 0.18;
      final isNearBlack = luminance < 22 && saturation < 0.16;
      if (isNearWhite || isNearBlack) continue;

      final weight = (saturation.clamp(0.0, 1.0) * 80.0) +
          (1.0 - (luminance / 255.0)).clamp(0.0, 1.0) * 28.0 +
          1.0;

      totalWeight += weight;
      rSum += r * weight;
      gSum += g * weight;
      bSum += b * weight;
    }

    if (totalWeight <= 0) return fallbackEmojiColor(emoji);

    final r = (rSum / totalWeight).round();
    final g = (gSum / totalWeight).round();
    final b = (bSum / totalWeight).round();
    return 0xFF000000 | (r << 16) | (g << 8) | b;
  } catch (_) {
    return fallbackEmojiColor(emoji);
  }
}
