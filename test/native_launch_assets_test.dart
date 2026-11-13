import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NativeLaunchAssets_AreVisibleAndBothThemesReferenceLogo', () async {
    Future<void> checkPixels(
      String path,
      int size, {
      double scale = 1,
      bool masked = false,
    }) async {
      final codec = await ui.instantiateImageCodec(
        File(path).readAsBytesSync(),
      );
      final image = (await codec.getNextFrame()).image;
      expect(image.width, size, reason: path);
      expect(image.height, size, reason: path);
      final data = (await image.toByteData())!;
      var visible = 0;
      var left = size, top = size, right = 0, bottom = 0;
      var outsideSafeCircle = 0;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (data.getUint8((y * size + x) * 4 + 3) < 16) continue;
          visible++;
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
          final dx = x + 0.5 - size / 2, dy = y + 0.5 - size / 2;
          if (masked && dx * dx + dy * dy > 96 * scale * 96 * scale) {
            outsideSafeCircle++;
          }
        }
      }
      // A transparent placeholder, cropped Zz or wrong canvas fails, not
      // merely a missing file. Bounds are independently measured on logo.png.
      expect(visible, greaterThan(5000 * scale * scale), reason: path);
      final offset = masked ? 80 * scale : 0;
      expect(left, closeTo(offset + 2 * scale, 2 * scale), reason: path);
      expect(top, closeTo(offset + 16 * scale, 2 * scale), reason: path);
      expect(right, closeTo(offset + 127 * scale, 2 * scale), reason: path);
      expect(bottom, closeTo(offset + 120 * scale, 2 * scale), reason: path);
      expect(
        outsideSafeCircle,
        0,
        reason: 'Android must not mask the Zz: $path',
      );
      image.dispose();
      codec.dispose();
    }

    const ios = 'ios/Runner/Assets.xcassets';
    for (final scale in [1, 2, 3]) {
      final suffix = scale == 1 ? '' : '@${scale}x';
      await checkPixels(
        '$ios/LaunchImage.imageset/LaunchImage$suffix.png',
        128 * scale,
        scale: scale.toDouble(),
      );
    }
    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    expect(
      storyboard,
      contains('contentMode="scaleAspectFit" image="LaunchImage"'),
    );
    expect(storyboard, contains('firstAttribute="width" constant="128"'));
    expect(storyboard, contains('firstAttribute="height" constant="128"'));
    expect(storyboard, contains('secondAttribute="centerX"'));
    expect(storyboard, contains('secondAttribute="centerY"'));
    expect(storyboard, contains('name="LaunchBackground"'));
    final colors =
        jsonDecode(
              File(
                '$ios/LaunchBackground.colorset/Contents.json',
              ).readAsStringSync(),
            )['colors']
            as List;
    expect(colors[0]['color']['components'], {
      'alpha': '1.000',
      'blue': '0xF7',
      'green': '0xF2',
      'red': '0xF2',
    });
    expect(colors[1]['appearances'][0]['value'], 'dark');
    expect(colors[1]['color']['components'], {
      'alpha': '1.000',
      'blue': '0x0A',
      'green': '0x0A',
      'red': '0x0A',
    });

    const res = 'android/app/src/main/res';
    for (final density in {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    }.entries) {
      await checkPixels(
        '$res/drawable-${density.key}/launch_logo.png',
        (128 * density.value).round(),
        scale: density.value,
      );
      await checkPixels(
        '$res/drawable-${density.key}/splash_logo.png',
        (288 * density.value).round(),
        scale: density.value,
        masked: true,
      );
    }
    for (final folder in ['drawable', 'drawable-v21']) {
      final xml = File('$res/$folder/launch_background.xml').readAsStringSync();
      expect(xml, contains('@color/launch_background'));
      expect(xml, contains('android:gravity="center"'));
      expect(xml, contains('@drawable/launch_logo'));
    }
    for (final folder in [
      'values',
      'values-night',
      'values-v31',
      'values-night-v31',
    ]) {
      final xml = File('$res/$folder/styles.xml').readAsStringSync();
      expect(
        xml,
        contains(
          '<item name="android:windowBackground">@color/launch_background</item>',
        ),
      );
      if (folder.endsWith('v31')) {
        expect(
          xml,
          contains(
            '<item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_logo</item>',
          ),
        );
        expect(
          xml,
          contains(
            '<item name="android:windowSplashScreenBackground">@color/launch_background</item>',
          ),
        );
      }
    }
    expect(
      File('$res/values/colors.xml').readAsStringSync(),
      contains('#F2F2F7'),
    );
    expect(
      File('$res/values-night/colors.xml').readAsStringSync(),
      contains('#0A0A0A'),
    );
  });
}
