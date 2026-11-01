import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../providers/app_store.dart';

/// Talks to the store. Product ids come from the server. Prices come from the
/// store. Nothing is granted here: the server checks every purchase with the
/// store first, and a purchase is finished only after that succeeds, so a
/// failed check is retried rather than lost.
class PurchaseService {
  PurchaseService(this._store);

  final AppStore _store;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  Future<List<ProductDetails>> loadProducts() async {
    if (!await _iap.isAvailable()) return const <ProductDetails>[];
    final ProductDetailsResponse res = await _iap.queryProductDetails(
      <String>{..._store.subscriptionProductIds, ..._store.creditProductIds},
    );
    return res.productDetails;
  }

  void listen({
    required void Function(String) onError,
    required void Function() onDone,
    void Function()? onPending,
  }) {
    _sub = _iap.purchaseStream.listen((List<PurchaseDetails> updates) async {
      for (final PurchaseDetails p in updates) {
        switch (p.status) {
          case PurchaseStatus.pending:
            onPending?.call();
          case PurchaseStatus.error:
            onError('The purchase did not complete.');
            if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          case PurchaseStatus.canceled:
            if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            try {
              await _store.validatePurchase(
                productId: p.productID,
                platform: Platform.isAndroid ? 'android' : 'ios',
                // Google identifies a purchase by its token, Apple by its transaction.
                token: Platform.isAndroid
                    ? p.verificationData.serverVerificationData
                    : p.purchaseID ?? '',
              );
              if (p.pendingCompletePurchase) await _iap.completePurchase(p);
              onDone();
            } on Object {
              onError('We could not verify this purchase. It will be checked again.');
            }
        }
      }
    });
  }

  Future<void> buy(ProductDetails product) {
    final PurchaseParam param = PurchaseParam(productDetails: product);
    return _store.subscriptionProductIds.contains(product.id)
        ? _iap.buyNonConsumable(purchaseParam: param)
        : _iap.buyConsumable(purchaseParam: param);
  }

  Future<void> restore() => _iap.restorePurchases();

  void dispose() => unawaited(_sub?.cancel());
}
