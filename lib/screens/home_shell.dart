import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_store.dart';
import '../theme/app_theme.dart';

/// Bottom-navigation shell hosting the six Barkat tabs:
/// Discover · Proposals · Matches · Activities · Premium · Profile.
///
/// The Proposals tab carries a red badge with the pending contact-request
/// count, mirroring the reference app.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final int pending = store.pendingRequestCount;
    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppTheme.slate200.withValues(alpha: 0.7)),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppTheme.slate900.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: shell.currentIndex,
          onTap: (int index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: pending > 0,
                label: Text('$pending'),
                backgroundColor: AppTheme.danger,
                textColor: Colors.white,
                child: const Icon(Icons.favorite_outline_rounded),
              ),
              activeIcon: Badge(
                isLabelVisible: pending > 0,
                label: Text('$pending'),
                backgroundColor: AppTheme.danger,
                textColor: Colors.white,
                child: const Icon(Icons.favorite_rounded),
              ),
              label: 'Proposals',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Matches',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome_rounded),
              label: 'Activities',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.diamond_outlined),
              activeIcon: Icon(Icons.diamond_rounded),
              label: 'Premium',
            ),
            BottomNavigationBarItem(
              icon: _ProfileAvatar(
                name: store.profile?.displayName ?? 'Amina Al-Mansoor',
                active: false,
              ),
              activeIcon: _ProfileAvatar(
                name: store.profile?.displayName ?? 'Amina Al-Mansoor',
                active: true,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Initials avatar for the Profile tab, mirroring Barkat's photo avatar.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, required this.active});

  final String name;
  final bool active;

  String get _initials {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppTheme.green,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppTheme.emeraldDeep : Colors.white,
          width: 1.6,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: AppTheme.ts(9, FontWeight.w800, color: Colors.white),
      ),
    );
  }
}
