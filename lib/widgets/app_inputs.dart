import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Consistent TextField wrapper; validator + icon support.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.maxLength,
    this.inputFormatters,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: AppTheme.ts(10.5, FontWeight.w700, color: AppTheme.slate500, letterSpacing: 1.1)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          textInputAction: textInputAction,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          autovalidateMode: AutovalidateMode.disabled,
          style: AppTheme.ts(14.5, FontWeight.w600, color: AppTheme.slate900),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon, size: 18, color: AppTheme.slate400),
            errorStyle: AppTheme.ts(11.5, FontWeight.w600, color: AppTheme.danger),
          ),
        ),
      ],
    );
  }
}

/// Password field with built-in visibility toggle (extracted from the
/// three duplicated implementations).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.hint,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String? hint;
  final TextInputAction? textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.label.toUpperCase(),
            style: AppTheme.ts(10.5, FontWeight.w700, color: AppTheme.slate500, letterSpacing: 1.1)),
        const SizedBox(height: 7),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          validator: widget.validator,
          textInputAction: widget.textInputAction,
          autovalidateMode: AutovalidateMode.disabled,
          style: AppTheme.ts(14.5, FontWeight.w600, color: AppTheme.slate900),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.slate400),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 19,
                color: AppTheme.slate400,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      ],
    );
  }
}

/// One entry of the region prefill list (mock — no intl packages required).
class CountryOption {
  const CountryOption(this.code, this.flag);
  final String code;
  final String flag;
}

const List<CountryOption> kCountries = <CountryOption>[
  CountryOption('+44', '🇬🇧'),
  CountryOption('+1', '🇺🇸'),
  CountryOption('+92', '🇵🇰'),
  CountryOption('+966', '🇸🇦'),
  CountryOption('+971', '🇦🇪'),
  CountryOption('+60', '🇲🇾'),
];

/// Styled dropdown for country dial codes (single shared implementation).
class AppCountryField extends StatelessWidget {
  const AppCountryField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(width: 10),
          const Icon(Icons.public_outlined, size: 17, color: AppTheme.slate400),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<String>(
                value: value,
                isDense: true,
                borderRadius: BorderRadius.circular(12),
                items: kCountries
                    .map<DropdownMenuItem<String>>(
                      (CountryOption c) => DropdownMenuItem<String>(
                        value: c.code,
                        child: Text(
                          '${c.flag} ${c.code}',
                          style: AppTheme.ts(13.5, FontWeight.w700, color: AppTheme.slate900),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (String? v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 6-digit SMS passcode entry — the guardian portal used to render a
/// static text; this replaces it with a real, focus-chained input.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.autofocusFirst = false,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final bool autofocusFirst;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      widget.length,
      (int i) {
        final TextEditingController c =
            TextEditingController(text: widget.controller.text.isEmpty ? '' : widget.controller.text[i]);
        c.addListener(() => _sync());
        return c;
      },
      growable: false,
    );
    _focusNodes = List<FocusNode>.generate(
      widget.length,
      (int i) => FocusNode(),
      growable: false,
    );
  }

  void _sync() {
    final String joined = _controllers.map((c) => c.text).join();
    if (joined != widget.controller.text) {
      widget.controller.text = joined;
      if (widget.onCompleted != null && joined.length == widget.length) {
        widget.onCompleted!(joined);
      }
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers) {
      c.dispose();
    }
    for (final FocusNode n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List<Widget>.generate(widget.length, (int i) {
        return SizedBox(
          width: 46,
          child: TextField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            autofocus: widget.autofocusFirst && i == 0,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: AppTheme.ts(18, FontWeight.w800, color: AppTheme.slate900),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.slate300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.green, width: 1.6),
              ),
            ),
            onChanged: (String v) {
              if (v.isNotEmpty && i < widget.length - 1) {
                _focusNodes[i + 1].requestFocus();
              }
              if (v.isEmpty && i > 0) {
                _focusNodes[i - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }
}

/// Hand-built phone/email style segmented control shared by landing and
/// sign-in screens.
class AppSegmentedToggle<T> extends StatelessWidget {
  const AppSegmentedToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceIvory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        children: options.map<Widget>((SegmentedOption<T> option) {
          final bool active = option.value == selected;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => onChanged(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: active ? AppTheme.slate200 : Colors.transparent,
                    ),
                    boxShadow: active
                        ? <BoxShadow>[
                            BoxShadow(
                              color: AppTheme.slate900.withValues(alpha: 0.07),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        option.icon,
                        size: 17,
                        color: active ? AppTheme.green : AppTheme.slate500,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTheme.ts(
                            13,
                            active ? FontWeight.w700 : FontWeight.w600,
                            color:
                                active ? AppTheme.slate800 : AppTheme.slate500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SegmentedOption<T> {
  const SegmentedOption({required this.value, required this.label, required this.icon});
  final T value;
  final String label;
  final IconData icon;
}
