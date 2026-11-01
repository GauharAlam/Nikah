import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../providers/app_store.dart';

/// Store products. Ids must match `PLAN_DAYS` and `CREDIT_PACKS` in
/// `functions/src/index.ts`. Prices always come from the store.
class PurchaseService {
  PurchaseService(this._store);

  static const Set<String> planIds = <String>{'barkat_monthly', 'barkat_weekly'};
  static const Set<String> creditIds = <String>{
    'barkat_credit_single',
    'barkat_credits_small',
  };

  final AppStore _store;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  Future<List<ProductDetails>> loadProducts() async {
    if (!await _iap.isAvailable()) return const <ProductDetails>[];
    final ProductDetailsResponse res =
        await _iap.queryProductDetails(<String>{...planIds, ...creditIds});
    return res.productDetails;
  }

  void listen({required void Function(String) onError, required void Function() onDone}) {
    _sub = _iap.purchaseStream.listen((List<PurchaseDetails> updates) async {
      for (final PurchaseDetails p in updates) {
        if (p.status == PurchaseStatus.error) {
          onError('The purchase did not complete.');
        } else if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          try {
            // Nothing is granted here. The server verifies with the store.
            await _store.validatePurchase(
              productId: p.productID,
              platform: Platform.isAndroid ? 'android' : 'ios',
              token: p.verificationData.serverVerificationData,
            );
            onDone();
          } on Object {
            onError('We could not verify this purchase. Please contact support.');
          }
        }
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      }
    });
  }

  Future<void> buy(ProductDetails product) {
    final PurchaseParam param = PurchaseParam(productDetails: product);
    return planIds.contains(product.id)
        ? _iap.buyNonConsumable(purchaseParam: param)
        : _iap.buyConsumable(purchaseParam: param);
  }

  Future<void> restore() => _iap.restorePurchases();

  void dispose() => unawaited(_sub?.cancel());
}
