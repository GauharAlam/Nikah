// The Discover deck on the production store: refreshing and paging must never
// take cards away or leave a member stuck on the last one.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/models/match_profile.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:nikah_app/screens/discovery_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late RemoteAppStore store;

  Finder deckCard(String id) => find.byKey(Key('discovery_card_$id'));

  IntroductionPage page(List<String> ids, {int? cursor}) =>
      IntroductionPage(ids.map(card).toList(), cursor);

  Future<void> open(WidgetTester tester, List<IntroductionPage> pages) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      backend = FakeBackend();
      backend.pages = pages.isEmpty ? <IntroductionPage>[] : pages;
      store = RemoteAppStore(await SharedPreferences.getInstance(), backend);
      backend.auth.add(const AuthUser(uid: 'me', isApproved: true, phone: '+911'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      backend.account.add(const AccountState(stage: ReviewStage.approved));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    addTearDown(store.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const MaterialApp(home: DiscoveryScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> pull(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(0, 500), 1200);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Future<void> swipe(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('pulling down replaces the deck with the new page', (WidgetTester tester) async {
    await open(tester, <IntroductionPage>[page(<String>['a', 'b'])]);
    expect(deckCard('a'), findsOneWidget);

    backend.pages = <IntroductionPage>[page(<String>['c'])];
    await pull(tester);

    expect(deckCard('c'), findsOneWidget);
    expect(deckCard('a'), findsNothing);
    expect(store.discoveredProfiles.map((MatchProfile p) => p.id), <String>['c']);
  });

  testWidgets('a failed pull keeps the cards and says why', (WidgetTester tester) async {
    await open(tester, <IntroductionPage>[page(<String>['a', 'b'])]);

    backend.failOn = 'fetchIntroductions';
    await pull(tester);

    expect(deckCard('a'), findsOneWidget);
    expect(store.discoveredProfiles, hasLength(2));
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a failed next page offers a retry on the last swipe', (WidgetTester tester) async {
    await open(tester, <IntroductionPage>[page(<String>['a', 'b'], cursor: 2)]);

    backend.failOn = 'fetchIntroductions';
    await swipe(tester);
    await swipe(tester);
    expect(find.text('Try again'), findsOneWidget);

    backend.pages = <IntroductionPage>[page(<String>['c'])];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(deckCard('c'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a card holds the place of a page still loading', (WidgetTester tester) async {
    await open(tester, <IntroductionPage>[page(<String>['a', 'b'], cursor: 2)]);

    final Completer<void> gate = Completer<void>();
    backend.gate = gate;
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('deck_skeleton')), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deck_skeleton')), findsNothing);
  });
}
