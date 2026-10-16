part of 'create_account_screen.dart';

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTheme.ts(10.5, FontWeight.w700, color: AppTheme.slate500, letterSpacing: 1.1),
    );
  }
}

class _GenderPicker extends StatelessWidget {
  const _GenderPicker({required this.selected, required this.onChanged});

  final Gender selected;
  final ValueChanged<Gender> onChanged;

  Widget _button(Gender g) {
    final bool active = g == selected;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(g),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? AppTheme.emerald : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppTheme.emerald : AppTheme.slate300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                g == Gender.male ? Icons.man_outlined : Icons.woman_outlined,
                size: 19, color: active ? Colors.white : AppTheme.slate600,
              ),
              const SizedBox(width: 7),
              Text(
                g.label,
                style: AppTheme.ts(
                  13, active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? Colors.white : AppTheme.slate800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _button(Gender.male)),
        const SizedBox(width: 8),
        Expanded(child: _button(Gender.female)),
      ],
    );
  }
}

class _DobField extends StatelessWidget {
  const _DobField({
    required this.controller,
    required this.onTap,
    required this.age,
    required this.validator,
  });

  final TextEditingController controller;
  final int? age;
  final VoidCallback onTap;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: _FieldLabel('Date of birth')),
            Text(
              age == null ? '18+ required' : 'Age: $age years',
              style: AppTheme.ts(10.5, FontWeight.w700,
                  color: age == null ? AppTheme.slate500 : AppTheme.green),
            ),
          ],
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          validator: validator,
          autovalidateMode: AutovalidateMode.disabled,
          style: AppTheme.ts(14.5, FontWeight.w600, color: AppTheme.slate900),
          decoration: InputDecoration(
            hintText: 'Select date of birth',
            prefixIcon: const Icon(Icons.cake_outlined, size: 18, color: AppTheme.slate400),
            suffixIcon: IconButton(
              tooltip: 'Pick date',
              icon: const Icon(Icons.calendar_month_outlined, size: 18, color: AppTheme.slate400),
              onPressed: onTap,
            ),
          ),
        ),
      ],
    );
  }
}

class _PledgeRow extends StatelessWidget {
  const _PledgeRow({
    required this.text,
    required this.checked,
    required this.onChanged,
  });

  final String text;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 20, color: checked ? AppTheme.green : AppTheme.slate400,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: AppTheme.ts(12.5, FontWeight.w500, color: AppTheme.slate700, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.score});

  final int score;

  String get _label => switch (score) {
    1 => 'Too short',
    2 => 'Getting there',
    3 => 'Strong',
    4 => 'Very strong',
    _ => 'Enter a password',
  };

  Color get _color => switch (score) {
    1 => AppTheme.danger,
    2 => AppTheme.warning,
    3 => AppTheme.green,
    4 => AppTheme.success,
    _ => AppTheme.slate500,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: List<Widget>.generate(4, (int i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < score ? _color : AppTheme.slate200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(child: Text(_label, style: AppTheme.ts(10.5, FontWeight.w700, color: _color))),
            Text('Min. 8 characters', style: AppTheme.ts(10.5, FontWeight.w600, color: AppTheme.slate500)),
          ],
        ),
      ],
    );
  }
}
