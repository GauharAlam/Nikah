import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/backend.dart';
import '../l10n/app_strings.dart';
import '../providers/app_store.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snacks.dart';
import '../widgets/empty_state.dart';

/// Membership plans and credit packs, with prices from the store.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late final PurchaseService _purchases;
  List<ProductDetails>? _products;

  @override
  void initState() {
    super.initState();
    _purchases = PurchaseService(context.read<AppStore>());
    if (AppConfig.isDemo) {
      _products = const <ProductDetails>[];
      return;
    }
    _purchases.listen(
      onError: (String m) {
        if (mounted) showAppSnack(context, m);
      },
      onDone: () {
        if (mounted) showSuccessSnack(context, tr('Purchase verified.'));
      },
      onPending: () {
        if (mounted) showAppSnack(context, 'Waiting for the store to confirm your payment.');
      },
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final List<ProductDetails> products = await _purchases.loadProducts();
      if (mounted) setState(() => _products = products);
    } on Object {
      if (mounted) setState(() => _products = const <ProductDetails>[]);
    }
  }

  @override
  void dispose() {
    _purchases.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ProductDetails>? products = _products;
    final List<PurchaseRecord> history = context.watch<AppStore>().purchases;
    return Scaffold(
      backgroundColor: AppTheme.ivoryWarm,
      appBar: AppBar(title: Text(tr('Plans'))),
      body: products == null
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? EmptyState(
                  icon: Icons.storefront_outlined,
                  title: tr('Plans are not available'),
                  body: tr('Purchases are not available in this build yet.'),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    for (final ProductDetails p in products)
                      Card(
                        child: ListTile(
                          key: Key('plan_${p.id}'),
                          title: Text(p.title),
                          subtitle: Text(p.description),
                          trailing: FilledButton(
                            onPressed: () => unawaited(_purchases.buy(p)),
                            child: Text(p.price),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        tr('Subscriptions renew automatically at the price shown until you cancel in your store account, at least 24 hours before the renewal date. Prices are set by the store and include any local tax it applies.'),
                        key: const Key('renewal_terms'),
                        style: AppTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => unawaited(_purchases.restore()),
                      child: Text(tr('Restore purchases')),
                    ),
                    if (history.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(tr('Purchase history'),
                          style: AppTheme.ts(15, FontWeight.w800, color: AppTheme.slate900)),
                      for (final PurchaseRecord r in history)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(r.productId),
                          subtitle: Text(<String>[
                            AppStore.fmtDate(r.createdAt),
                            if (r.state == 'refunded') tr('Refunded'),
                            if (r.expiresAt != null) '${tr('Until')} ${AppStore.fmtDate(r.expiresAt!)}',
                          ].join(' · ')),
                        ),
                    ],
                  ],
                ),
    );
  }
}
