import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nikah_app/app_router.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/data/option_lists.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:nikah_app/screens/review_queue_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';

void main() {
  group('deep links', () {
    test('known screens pass', () {
      expect(safeDeepLink('/home/discovery'), '/home/discovery');
      expect(safeDeepLink('/chat/abc_123'), '/chat/abc_123');
      expect(safeDeepLink('/match/u1'), '/match/u1');
    });

    test('everything else is ignored', () {
      for (final Object? link in <Object?>[
        null, 42, '', '/', '/admin/review', '/photo/x?url=https://evil.example', 'https://evil.example',
        '/chat/../admin', '/chat/a/b', '/settings/delete', '//evil.example',
      ]) {
        expect(safeDeepLink(link), isNull, reason: '$link');
      }
    });
  });

  test('production copy makes no false supervision claims', () {
    const List<String> screens = <String>[
      'lib/screens/about_screen.dart',
      'lib/screens/photo_viewer_screen.dart',
      'lib/screens/settings_screen.dart',
    ];
    for (final String path in screens) {
      final String text = File(path).readAsStringSync().toLowerCase();
      for (final String phrase in <String>[
        'visible to both guardians', 'audit log', 'scholar-supervised', 'modesty-checked', 'within 24 hours',
      ]) {
        expect(text, isNot(contains(phrase)), reason: '$path: $phrase');
      }
    }
  });

  test('every report reason matches the server list', () {
    final String rules = File('functions/src/rules.ts').readAsStringSync();
    for (final String reason in OptionLists.reportReasons) {
      expect(rules, contains("'$reason'"));
    }
  });

  group('reports', () {
    late FakeBackend backend;
    late RemoteAppStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      backend = FakeBackend();
      store = RemoteAppStore(await SharedPreferences.getInstance(), backend);
      addTearDown(store.dispose);
    });

    test('carry their context to the server', () async {
      await store.reportProfile('a', 'Fake profile', details: 'x', context: 'conversation');
      expect(backend.calls, contains('report:a:Fake profile:conversation'));
    });

    testWidgets('reviewers can decide from the reports tab', (WidgetTester tester) async {
      backend.reports = const <ReportItem>[
        ReportItem(id: 'r1', target: 't1', name: 'Sara', reason: 'Fake profile', held: true, count: 3),
      ];
      await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const MaterialApp(home: ReviewQueueScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reports_tab')));
      await tester.pumpAndSettle();
      expect(find.text('Sara'), findsOneWidget);
      await tester.tap(find.byKey(const Key('release_t1')));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('releaseHold:t1'));
      await tester.tap(find.byKey(const Key('uphold_r1')));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('resolveReport:r1:uphold'));
    });
  });
}
