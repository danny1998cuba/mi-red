import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'assets/branding';
  const res = 'android/app/src/main/res';
  test('all six supplied sources retain their exact original bytes', () async {
    const hashes = {
      'mi_red_logo_master':
          '35738ed50d57d8ad421b9936c91f62b4f9a6fbc50c3315a5cafe5b1c6d501c9b',
      'mi_red_adaptive_foreground':
          'f6f00eec8cd22803fb23f77781e0bb662fbb8a00a82c9cd8881895b4f502c643',
      'mi_red_adaptive_monochrome':
          'ffb60d65f0e77590d1c1947e419ef7a762f3663bbb3c37a482f5b9f93f476cae',
      'mi_red_legacy_icon':
          'ea9df393fdd1b131f5eb7f8aab59efae5932ae729c01d408145196624c5bf5eb',
      'mi_red_splash_mark':
          '1defe67c72da6e0384ea090c37a0c5b5778702ecf5a9160d0b3a3c0c2d43bd4d',
      'mi_red_assets_preview':
          '7aac334042e83b0a676080f834868081e6afd7e5f0467d96b8d8d83c19c243ea',
    };
    for (final entry in hashes.entries) {
      final hash = await Sha256().hash(
        await File('$source/${entry.key}.png').readAsBytes(),
      );
      expect(
        hash.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('master stays transparent and the preview is not a Flutter production asset', () async {
    final image = await decode('$source/mi_red_logo_master.png');
    addTearDown(image.dispose);
    expect(image.width, 1254);
    expect(image.height, 1254);
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    expect(rgba.getUint8(3), 0);
    expect(rgba.getUint8((image.width - 1) * 4 + 3), 0);
    final pubspec = await File('pubspec.yaml').readAsString();
    expect(pubspec, contains('assets/branding/mi_red_logo_master.png'));
    expect(pubspec, isNot(contains('mi_red_assets_preview')));
    expect(pubspec, isNot(contains('- assets/branding/\n')));
  });

  test('Android density resources have correct dimensions and adaptive marks stay inside safe circle', () async {
    for (final entry in {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    }.entries) {
      for (final kind in [
        'ic_launcher',
        'ic_launcher_foreground',
        'ic_launcher_monochrome',
      ]) {
        final image = await decode('$res/mipmap-${entry.key}/$kind.png');
        try {
          final adaptive = kind != 'ic_launcher';
          expect(image.width, ((adaptive ? 108 : 48) * entry.value).round());
          expect(image.height, image.width);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!;
          if (adaptive) {
            expect(bytes.getUint8(3), 0);
            var count = 0;
            for (var y = 0; y < image.height; y++) {
              for (var x = 0; x < image.width; x++) {
                final offset = (y * image.width + x) * 4;
                if (bytes.getUint8(offset + 3) <= 8) continue;
                count++;
                final radius = math.sqrt(
                  math.pow(x + .5 - image.width / 2, 2) +
                      math.pow(y + .5 - image.height / 2, 2),
                );
                expect(
                  radius / entry.value,
                  lessThanOrEqualTo(33),
                  reason: '$kind ${entry.key}',
                );
                if (kind == 'ic_launcher_monochrome') {
                  // Straight-alpha decoding may round white by one channel unit.
                  expect(bytes.getUint8(offset), greaterThanOrEqualTo(253));
                  expect(bytes.getUint8(offset + 1), bytes.getUint8(offset));
                  expect(bytes.getUint8(offset + 2), bytes.getUint8(offset));
                }
              }
            }
            expect(count, greaterThan(100));
          } else {
            expect(bytes.getUint8(3), 255);
          }
        } finally {
          image.dispose();
        }
      }
      final mark = await decode(
        '$res/drawable-${entry.key}/mi_red_splash_mark.png',
      );
      expect(mark.width, (288 * entry.value).round());
      expect(mark.height, mark.width);
      mark.dispose();
    }
  });

  test('native API31 uses actual icon/background/branding and retains separate notification resource', () async {
    final style = await File('$res/values-v31/styles.xml').readAsString();
    expect(style, contains('android:windowSplashScreenBackground'));
    expect(style, contains('android:windowSplashScreenAnimatedIcon'));
    expect(style, contains('android:windowSplashScreenBrandingImage'));
    expect(
      await File('$res/values/branding_colors.xml').readAsString(),
      contains('#F8FAFC'),
    );
    expect(
      await File('$res/values-night/branding_colors.xml').readAsString(),
      contains('#0B1220'),
    );
    expect(
      await File('$res/mipmap-anydpi-v33/ic_launcher.xml').readAsString(),
      contains('<monochrome android:drawable="@mipmap/ic_launcher_monochrome"'),
    );
    expect(
      await File('$res/drawable/ic_notification.xml').readAsString(),
      contains('<vector'),
    );
    expect(
      await File('$res/raw/keep.xml').readAsString(),
      contains('@drawable/ic_notification'),
    );
    final manifest = await File('android/app/src/main/AndroidManifest.xml')
        .readAsString();
    expect(manifest, contains('android:label="Mi Red"'));
    expect(manifest, isNot(contains('EnableImpeller')));
    expect(manifest, isNot(contains('enable-impeller')));
  });
}
