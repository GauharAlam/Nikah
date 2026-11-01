// Words that promised something the app does not do. Each was once shown to
// real members, so a return of any of them is a defect, not a style choice.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<String> banned = <String>[
    'replies within 24h', // nothing is sent to anyone
    'ships with the release',
    'ships soon',
    'guardian supervised', // no member is supervised
    'rank higher', // the server orders by approval date only
    'higher in search',
    'Move up in search',
    'trust score', // no such score exists
    'saved on this device', // the profile lives on the server
    'awaiting family approval', // the member answers, not a family
    'nikah.demo',
    'Usually reviewed', // no review time is promised
    'exchanged between both families',
    'Your Wali can see',
    'بركة', // the old brand name
  ];

  final List<File> sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .where((File f) => !f.path.endsWith('demo_app_store.dart'))
      .toList();

  for (final String phrase in banned) {
    test('no member sees "$phrase"', () {
      for (final File f in sources) {
        final String text = f.readAsStringSync().replaceAll(RegExp(r"'\s*\n\s*'"), '');
        expect(text.contains(phrase), isFalse, reason: f.path);
      }
    });
  }

  test('the app carries its own logo, not the Flutter default', () {
    for (final String name in <String>['nikah-logo', 'nikah-word-gold', 'nikah-word-green']) {
      expect(File('assets/brand/$name.png').existsSync(), isTrue, reason: name);
    }
    const String res = 'android/app/src/main/res';
    final String icon = File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(icon, contains('ic_launcher_foreground'));
    for (final String d in <String>['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(File('$res/mipmap-$d/ic_launcher_foreground.png').existsSync(), isTrue, reason: d);
    }
    expect(File('$res/drawable/launch_background.xml').readAsStringSync(), contains('launch_logo'));
  });

  test('fonts are bundled, not fetched while a member waits', () {
    expect(File('pubspec.yaml').readAsStringSync().contains('google_fonts'), isFalse);
    for (final File f in sources) {
      expect(f.readAsStringSync().contains('GoogleFonts'), isFalse, reason: f.path);
    }
    for (final String w in <String>['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      expect(File('assets/fonts/PlusJakartaSans-$w.ttf').existsSync(), isTrue);
    }
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
  });
}
