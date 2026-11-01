import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late RemoteAppStore store;

  Future<void> settle() async {
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    backend = FakeBackend();
    store = RemoteAppStore(await SharedPreferences.getInstance(), backend);
    addTearDown(store.dispose);
    backend.auth.add(const AuthUser(uid: 'me', isApproved: true));
    await settle();
  });

  group('premium', () {
    test('is true only while the server says so', () async {
      expect(store.isPremium, isFalse);
      backend.account.add(AccountState(premiumUntil: DateTime.now().add(const Duration(days: 1))));
      await settle();
      expect(store.isPremium, isTrue);
      backend.account.add(AccountState(premiumUntil: DateTime.now().subtract(const Duration(days: 1))));
      await settle();
      expect(store.isPremium, isFalse);
    });

    test('a purchase on the device grants nothing until the server answers', () async {
      await store.validatePurchase(productId: 'nikah_monthly', platform: 'android', token: 't');
      expect(backend.calls, contains('purchase:nikah_monthly:android'));
      expect(store.isPremium, isFalse);
    });

    test('product ids come from the server', () async {
      backend.limits.add(const AppLimits(
        subscriptionIds: <String>{'custom_plan'},
        creditIds: <String>{'custom_pack'},
      ));
      await settle();
      expect(store.subscriptionProductIds, <String>{'custom_plan'});
      expect(store.creditProductIds, <String>{'custom_pack'});
    });

    test('purchase history comes from the server', () async {
      backend.purchaseRecords.add(<PurchaseRecord>[
        PurchaseRecord(productId: 'nikah_monthly', state: 'refunded', createdAt: DateTime(2026)),
      ]);
      await settle();
      expect(store.purchases.single.state, 'refunded');
    });

    test('no price or quota appears in the purchase code', () {
      final String code = File('lib/services/purchase_service.dart').readAsStringSync();
      expect(code, isNot(contains('₹')));
      expect(code, isNot(contains('isPremium')));
    });

    test('a purchase is finished only after verification', () {
      final String code = File('lib/services/purchase_service.dart').readAsStringSync();
      final int verify = code.indexOf('validatePurchase');
      final int finish = code.indexOf('completePurchase', verify);
      final int failed = code.indexOf('on Object', verify);
      expect(verify, greaterThan(0));
      expect(finish, lessThan(failed), reason: 'completion sits inside the try, after validation');
    });
  });

  group('notification preferences', () {
    test('default to on and follow the server', () async {
      expect(store.wantsNotification('messages'), isTrue);
      backend.notificationPrefs.add(<String, bool>{'messages': false});
      await settle();
      expect(store.wantsNotification('messages'), isFalse);
      expect(store.wantsNotification('proposals'), isTrue);
    });

    test('are saved to the server', () async {
      store.setWantsNotification('family', false);
      await settle();
      expect(backend.calls, contains('pref:family:false'));
      expect(store.wantsNotification('family'), isFalse);
    });
  });
}
