import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ward_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/how_to_use_sheet.dart';

/// The member's number and how it is shared.
class ContactDetailsScreen extends StatelessWidget {
  const ContactDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final WardProfile? p = store.profile;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Contact Details'),
        actions: <Widget>[
          IconButton(
            tooltip: 'How to use',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showHowToUseSheet(context, store),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Contact number'),
            subtitle: Text(p?.e164Phone.isEmpty ?? true ? 'Not added' : p!.e164Phone),
          ),
          const ListTile(
            leading: Icon(Icons.swap_horiz_rounded),
            title: Text('Sharing preference'),
            subtitle: Text(
              'Manual approval. Your number is shared only when you accept a request.',
            ),
          ),
        ],
      ),
    );
  }
}
