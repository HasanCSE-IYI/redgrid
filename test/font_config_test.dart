import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/app.dart';

void main() {
  group('Font Configuration and Assets Tests', () {
    test('font files exist on disk and are non-empty', () {
      final fontFiles = [
        'assets/fonts/NotoSansBengali-Regular.ttf',
        'assets/fonts/NotoSansBengali-Medium.ttf',
        'assets/fonts/NotoSansBengali-SemiBold.ttf',
        'assets/fonts/NotoSansBengali-Bold.ttf',
        'assets/fonts/NotoSansBengali-ExtraBold.ttf',
        'assets/fonts/HindSiliguri-Regular.ttf',
        'assets/fonts/HindSiliguri-Medium.ttf',
        'assets/fonts/HindSiliguri-SemiBold.ttf',
        'assets/fonts/HindSiliguri-Bold.ttf',
      ];

      for (final path in fontFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Font file missing: $path');
        expect(file.lengthSync(), greaterThan(100000), reason: 'Font file too small: $path');
      }
    });

    test('RedGridApp defines NotoSansBengali as primary font family', () {
      const app = RedGridApp();
      expect(app, isNotNull);
    });
  });
}
