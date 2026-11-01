// Every string marked for translation must have one, in both languages.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nikah_app/l10n/app_strings.dart';
import 'package:nikah_app/screens/safety_center_screen.dart';

void main() {
  final RegExp marked = RegExp(r"\b(?:tr|trArgs)\(\s*'((?:[^'\\]|\\.)*)'((?:\s*\n\s*'(?:[^'\\]|\\.)*')*)");
  final RegExp piece = RegExp(r"'((?:[^'\\]|\\.)*)'");
  final RegExp slot = RegExp(r'\{\w+\}');

  Set<String> slots(String text) => slot.allMatches(text).map((Match m) => m[0]!).toSet();

  test('every marked string has a translation', () {
    final List<String> missing = <String>[];
    final Iterable<File> files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart') && !f.path.endsWith('app_strings.dart'));
    for (final File f in files) {
      for (final RegExpMatch m in marked.allMatches(f.readAsStringSync())) {
        final String tail = piece.allMatches(m[2]!).map((Match p) => p[1]!).join();
        final String key = '${m[1]}$tail'.replaceAll(r"\'", "'").replaceAll(r'\n', '\n');
        if (key.contains(r'$')) continue;
        if (!AppStrings.table.containsKey(key)) missing.add('${f.path}: $key');
      }
    }
    expect(missing, isEmpty);
  });

  test('both languages fill the same values', () {
    AppStrings.table.forEach((String english, List<String> row) {
      expect(row, hasLength(2), reason: english);
      expect(slots(row[0]), slots(english), reason: english);
      expect(slots(row[1]), slots(english), reason: english);
    });
  });

  testWidgets('scam warnings follow a change of language', (WidgetTester tester) async {
    addTearDown(() => AppStrings.current = AppLanguage.english);
    await tester.pumpWidget(const MaterialApp(home: SafetyCenterScreen()));
    expect(find.textContaining('Never share an OTP'), findsOneWidget);

    AppStrings.current = AppLanguage.hindi;
    await tester.pumpWidget(const MaterialApp(key: ValueKey<String>('hi'), home: SafetyCenterScreen()));
    await tester.pump();
    expect(find.textContaining('OTP या बैंक'), findsOneWidget);
    expect(find.textContaining('Never share an OTP'), findsNothing);
  });

  test('values go into the sentence in any word order', () {
    addTearDown(() => AppStrings.current = AppLanguage.english);
    AppStrings.current = AppLanguage.hindi;
    expect(trArgs('Block {name}', <String, Object>{'name': 'Sara'}), 'Sara को ब्लॉक करें');
    expect(
      trArgs('{used} of {quota} sent', <String, Object>{'used': 2, 'quota': 5}),
      '5 में से 2 भेजे',
    );
  });
}
