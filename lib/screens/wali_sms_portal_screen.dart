// Guardian SMS verification portal — ward invite letter, real 6-digit
// passcode entry, fiduciary consent and a live resend countdown.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/wali.dart';
import '../models/ward_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';
import '../widgets/app_inputs.dart';
import '../widgets/app_snacks.dart';

class WaliSmsPortalScreen extends StatefulWidget {
  const WaliSmsPortalScreen({super.key});

  @override
  State<WaliSmsPortalScreen> createState() => _WaliSmsPortalScreenState();
}

class _WaliSmsPortalScreenState extends State<WaliSmsPortalScreen> {
  final TextEditingController _otpController = TextEditingController();
  Timer? _resendTimer;
  int _resendSeconds = 30;
  int _otpLength = 0;
  bool _fiduciary = false;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
    _startResendCountdown();
  }

  void _onOtpChanged() {
    final int length = _otpController.text.length;
    if (length == _otpLength) return;
    setState(() => _otpLength = length);
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (Timer tick) {
      if (!mounted) {
        tick.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        tick.cancel();
      }
    });
  }

  void _resendCode() {
    if (_resendSeconds > 0) return;
    final Guardian guardian = context.read<AppStore>().guardian;
    setState(() => _resendSeconds = 20);
    _startResendCountdown();
    showAppSnack(
      context,
      'New 6-digit code sent to ${guardian.phoneCode} ${guardian.phone}.',
      icon: Icons.sms_outlined,
    );
  }

  Future<void> _activate() async {
    final AppStore store = context.read<AppStore>();
    if (_otpLength < 6) {
      showAppSnack(
        context,
        'Enter the complete 6-digit code',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    if (!_fiduciary) {
      showAppSnack(
        context,
        'Confirm your lawful appointment as Wali first',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    store.verifyGuardianSms();
    if (!mounted) return;
    showWaliSnack(context, "Guardian verified — Ta'aruf protocols active.");
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) context.go(AppRoutes.waliHub);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final Guardian guardian = store.guardian;
    final WardProfile ward = store.profile ?? WardProfile.demoWard;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('Wali Verification Portal')),
      body: guardian.isVerified
          ? _VerifiedBody(name: guardian.name)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: <Widget>[
                const InfoBanner(
                  icon: Icons.lock_person_rounded,
                  variant: InfoVariant.warning,
                  text: 'Do not share this code with anyone except your '
                      'appointed Wali.',
                ),
                const SizedBox(height: 16),
                _WardCard(ward: ward),
                const SizedBox(height: 16),
                _InviteLetter(
                  guardianName: guardian.name,
                  wardName: ward.displayName.isEmpty
                      ? WardProfile.demoWard.displayName
                      : ward.displayName,
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionLabel('SMS passcode'),
                      const SizedBox(height: 6),
                      Text(
                        'Sent to ${guardian.phoneCode} ${guardian.phone}. '
                        'Demo build: any 6 digits pass.',
                        style: AppTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      OtpCodeField(
                        key: const ValueKey<String>('otp'),
                        controller: _otpController,
                        autofocusFirst: true,
                        onCompleted: (String code) => _activate(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.timer_outlined, size: 15, color: AppTheme.slate400),
                              const SizedBox(width: 5),
                              Text(
                                _resendSeconds > 0
                                    ? 'Resend code (${_resendSeconds}s)'
                                    : 'Resend code',
                                style: AppTheme.ts(
                                  11.5,
                                  FontWeight.w700,
                                  color: _resendSeconds > 0
                                      ? AppTheme.slate400
                                      : AppTheme.green,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _resendSeconds > 0 ? null : _resendCode,
                            child: Text(
                              _resendSeconds > 0 ? 'Please wait' : 'Resend',
                              style: AppTheme.ts(
                                12.5,
                                FontWeight.w700,
                                color: _resendSeconds > 0
                                    ? AppTheme.slate400
                                    : AppTheme.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Row(
                    children: <Widget>[
                      Checkbox(
                        key: const ValueKey<String>('fiduciary_box'),
                        value: _fiduciary,
                        onChanged: (bool? value) =>
                            setState(() => _fiduciary = value ?? false),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'I confirm I am lawfully appointed Wali for this '
                          'ward, with her consent and family knowledge.',
                          style: AppTheme.body,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  key: const ValueKey<String>('activate_guardian'),
                  label: 'Activate Guardian Access',
                  icon: Icons.verified_user_outlined,
                  onPressed: _fiduciary && _otpLength == 6 ? () => _activate() : null,
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.lock_outline_rounded, size: 13, color: AppTheme.slate400),
                      SizedBox(width: 5),
                      Text('Encrypted one-time passcode, valid for 10 minutes'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Green confirmation state shown when SMS verification was already
/// completed by the guardian.
class _VerifiedBody extends StatelessWidget {
  const _VerifiedBody({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: <Widget>[
        InfoBanner(
          icon: Icons.verified_user_outlined,
          variant: InfoVariant.success,
          text: '$name completed SMS verification — guardian access is '
              'already active.',
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Continue to Hub',
          icon: Icons.shield_outlined,
          onPressed: () => context.go(AppRoutes.waliHub),
        ),
      ],
    );
  }
}

/// Ward identity strip at the top of the portal.
class _WardCard extends StatelessWidget {
  const _WardCard({required this.ward});

  final WardProfile ward;

  static String _maskPhone(String phone) {
    final String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '••••••';
    return '•••• •${digits.substring(digits.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: <Widget>[
          AppAvatar(
            url: '',
            radius: 26,
            initials: ward.displayName.isEmpty
                ? 'A'
                : ward.displayName.substring(0, 1),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ward.displayName,
                  style: AppTheme.ts(15.5, FontWeight.w800, color: AppTheme.slate900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                TagChip(
                  'Daughter (Ward)',
                  color: AppTheme.gold.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 5),
                Text(
                  '${ward.phoneCode} ${_maskPhone(ward.phone)}',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold-tinted appointment letter with salutation + bismillah line.
class _InviteLetter extends StatelessWidget {
  const _InviteLetter({required this.guardianName, required this.wardName});

  final String guardianName;
  final String wardName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppTheme.gold,
      borderColor: AppTheme.goldAccent.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              style: AppTheme.ts(20, FontWeight.w700, color: AppTheme.goldInk, height: 1.5),
              textDirection: TextDirection.rtl,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'In the name of Allah, the Most Gracious, the Most Merciful',
              style: AppTheme.ts(10.5, FontWeight.w700, color: AppTheme.goldDeep),
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            color: AppTheme.goldAccent.withValues(alpha: 0.45),
            thickness: 1,
          ),
          const SizedBox(height: 12),
          Text(
            'As-salamu alaykum wa rahmatullah, $guardianName,',
            style: AppTheme.ts(14, FontWeight.w800, color: AppTheme.goldInk),
          ),
          const SizedBox(height: 6),
          Text(
            'You have been appointed by $wardName as the primary Wali for this '
            'matrimonial search — reviewing introductions, approving chaperoned '
            'chats, and accompanying every family meeting with dignity, '
            'transparency and confidentiality, in sha Allah.',
            style: AppTheme.ts(13, FontWeight.w500, color: AppTheme.goldDeep, height: 1.55),
          ),
          const SizedBox(height: 12),
          Text(
            'With gratitude and trust — sent via the Barkat Nikah '
            'guardianship protocol.',
            style: AppTheme.ts(11.5, FontWeight.w700, color: AppTheme.goldDeep),
          ),
        ],
      ),
    );
  }
}
