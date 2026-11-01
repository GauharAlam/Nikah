import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
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
  late final PurchaseService _purchases = PurchaseService(context.read<AppStore>());
  List<ProductDetails>? _products;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isDemo) {
      _products = const <ProductDetails>[];
      return;
    }
    _purchases.listen(
      onError: (String m) {
        if (mounted) showAppSnack(context, m);
      },
      onDone: () {
        if (mounted) showSuccessSnack(context, 'Purchase verified.');
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
    return Scaffold(
      backgroundColor: AppTheme.ivoryWarm,
      appBar: AppBar(title: const Text('Plans')),
      body: products == null
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? const EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Plans are not available',
                  body: 'Purchases are not available in this build yet.',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    for (final ProductDetails p in products)
                      Card(
                        child: ListTile(
                          title: Text(p.title),
                          subtitle: Text(p.description),
                          trailing: FilledButton(
                            onPressed: () => unawaited(_purchases.buy(p)),
                            child: Text(p.price),
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => unawaited(_purchases.restore()),
                      child: const Text('Restore purchases'),
                    ),
                  ],
                ),
    );
  }
}
