import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../config/app_config.dart';
import '../data/backend.dart';
import '../data/option_lists.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_snacks.dart';

/// Phone number entry, then the SMS code. The router moves on once signed in.
class PhoneSignInScreen extends StatefulWidget {
  const PhoneSignInScreen({super.key, this.linking = false});

  /// Adds a number to the signed-in account, then returns.
  final bool linking;

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  static const int _resendSeconds = 30;

  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  Timer? _timer;
  String _dial = '+91';
  String? _verificationId;
  int _cooldown = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _e164 => '$_dial${_phone.text.trim()}';

  bool get _phoneValid {
    final int length = _phone.text.trim().length;
    return _dial == '+91' ? length == 10 : length >= 7 && length <= 13;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
        final String? id = await context.read<AppStore>().sendOtp(_e164);
        if (!mounted) return;
        if (id == null) {
          // The device verified the number by itself.
          if (widget.linking) context.pop();
          return;
        }
        setState(() {
          _verificationId = id;
          _cooldown = _resendSeconds;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
          if (_cooldown <= 1) t.cancel();
          if (mounted) setState(() => _cooldown--);
        });
        if (AppConfig.isDemo) {
          showAppSnack(context, 'Demo build: use code ${AppConfig.demoOtp}.');
        }
      });

  Future<void> _verify() => _run(() async {
        await context.read<AppStore>().confirmOtp(_verificationId!, _code.text.trim());
        if (widget.linking && mounted) context.pop();
      });

  @override
  Widget build(BuildContext context) {
    final bool codeStep = _verificationId != null;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: <Widget>[
            Text(
              codeStep ? tr('Enter the code') : tr('Your phone number'),
              style: AppTheme.ts(24, FontWeight.w800, color: AppTheme.slate900),
            ),
            const SizedBox(height: 8),
            Text(
              codeStep
                  ? 'We sent a 6-digit code to $_e164.'
                  : tr('We will text you a code to confirm it is you.'),
              style: AppTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            if (!codeStep)
              Row(
                children: <Widget>[
                  DropdownButton<String>(
                    value: _dial,
                    underline: const SizedBox.shrink(),
                    items: <DropdownMenuItem<String>>[
                      for (final MapEntry<String, String> c
                          in OptionLists.countryCodes.entries)
                        DropdownMenuItem<String>(
                          value: c.key,
                          child: Text('${c.value} ${c.key}'),
                        ),
                    ],
                    onChanged: (String? v) => setState(() => _dial = v ?? _dial),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('phone_input'),
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
                      ],
                      decoration: InputDecoration(hintText: tr('Mobile number')),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              )
            else
              TextField(
                key: const Key('otp_input'),
                controller: _code,
                keyboardType: TextInputType.number,
                autofocus: true,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(hintText: tr('6-digit code')),
                onChanged: (_) => setState(() {}),
              ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('auth_error'),
                style: AppTheme.ts(13, FontWeight.w600, color: AppTheme.danger),
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(
              key: const Key('auth_submit'),
              label: _busy ? tr('Please wait…') : (codeStep ? tr('Verify') : tr('Send code')),
              onPressed: _busy
                  ? null
                  : codeStep
                      ? (_code.text.trim().length == 6 ? _verify : null)
                      : (_phoneValid ? _send : null),
            ),
            if (codeStep) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _cooldown > 0 || _busy ? null : _send,
                child: Text(_cooldown > 0 ? 'Resend in ${_cooldown}s' : tr('Resend code')),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _verificationId = null;
                          _code.clear();
                          _error = null;
                        }),
                child: Text(tr('Change number')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
