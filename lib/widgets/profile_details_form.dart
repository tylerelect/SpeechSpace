import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

/// Kid-friendly color choices for "favorite color". Chips instead of free text
/// keep the generated questions tidy ("Did you see anything blue?").
const favoriteColors = <(String, Color)>[
  ('Red', Color(0xFFE53935)),
  ('Orange', Color(0xFFFB8C00)),
  ('Yellow', Color(0xFFFDD835)),
  ('Green', Color(0xFF43A047)),
  ('Blue', Color(0xFF1E88E5)),
  ('Purple', Color(0xFF8E24AA)),
  ('Pink', Color(0xFFEC407A)),
  ('Brown', Color(0xFF6D4C41)),
  ('Black', Color(0xFF212121)),
  ('White', Color(0xFFFAFAFA)),
];

/// Optional "About me" fields. Kids ([SpaceProfile.kids], the default): age,
/// school, favorite color and interests. Adults ([SpaceProfile.adult]): age,
/// occupation, current goals and hobbies (stored as interests). Reports every
/// change through [onChanged]; the caller decides when to save. Fields of the
/// other kind are passed through unchanged. Used by the setup flow and the
/// Settings page.
class ProfileDetailsForm extends StatefulWidget {
  const ProfileDetailsForm({super.key, required this.initial, required this.onChanged, this.kind = SpaceProfile.kids});
  final ProfileDetails initial;
  final ValueChanged<ProfileDetails> onChanged;
  final String kind;

  @override
  State<ProfileDetailsForm> createState() => _ProfileDetailsFormState();
}

class _ProfileDetailsFormState extends State<ProfileDetailsForm> {
  late final TextEditingController _school = TextEditingController(text: widget.initial.school);
  late final TextEditingController _interests = TextEditingController(text: widget.initial.interests.join(', '));
  late final TextEditingController _occupation = TextEditingController(text: widget.initial.occupation);
  late final TextEditingController _goals = TextEditingController(text: widget.initial.goals.join(', '));
  late final (int, int) _ages = ProfileDetails.ageRange(widget.kind);
  // An age outside this kind's range (e.g. old data) shows as "Prefer not to say".
  late int? _age = _inRange(widget.initial.age);
  late String _color = widget.initial.favoriteColor;

  bool get _kids => widget.kind != SpaceProfile.adult;

  int? _inRange(int? age) => age != null && age >= _ages.$1 && age <= _ages.$2 ? age : null;

  @override
  void dispose() {
    _school.dispose();
    _interests.dispose();
    _occupation.dispose();
    _goals.dispose();
    super.dispose();
  }

  void _emit() {
    final initial = widget.initial;
    widget.onChanged(ProfileDetails(
      age: _age,
      school: _kids ? ProfileDetails.tidy(_school.text, ProfileDetails.maxSchool) : initial.school,
      favoriteColor: _kids ? _color : initial.favoriteColor,
      interests: ProfileDetails.parseInterests(_interests.text),
      occupation: _kids ? initial.occupation : ProfileDetails.tidy(_occupation.text, ProfileDetails.maxOccupation),
      goals: _kids ? initial.goals : ProfileDetails.parseGoals(_goals.text),
    ));
  }

  Widget _ageField() => DropdownButtonFormField<int?>(
        key: const ValueKey('details-age'),
        initialValue: _age,
        decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake_outlined)),
        items: [
          const DropdownMenuItem<int?>(child: Text('Prefer not to say')),
          for (var a = _ages.$1; a <= _ages.$2; a++) DropdownMenuItem<int?>(value: a, child: Text('$a')),
        ],
        onChanged: (v) { setState(() => _age = v); _emit(); },
      );

  @override
  Widget build(BuildContext context) => _kids ? _kidsFields(context) : _adultFields();

  Widget _adultFields() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ageField(),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('details-occupation'),
          controller: _occupation, maxLength: ProfileDetails.maxOccupation,
          inputFormatters: const [_CodePointLimit(ProfileDetails.maxOccupation)],
          onChanged: (_) => _emit(),
          decoration: const InputDecoration(labelText: 'Occupation (optional)', prefixIcon: Icon(Icons.work_outline),
              hintText: 'teacher, nurse, student, retired',
              helperText: 'A role, not an employer name.'),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('details-goals'),
          controller: _goals,
          onChanged: (_) => _emit(),
          decoration: const InputDecoration(labelText: 'Current goals or focus (optional)',
              prefixIcon: Icon(Icons.flag_outlined),
              hintText: 'run a 10k, learn Spanish',
              helperText: 'Separate with commas. Up to ${ProfileDetails.maxGoals}.'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('details-interests'),
          controller: _interests,
          onChanged: (_) => _emit(),
          decoration: const InputDecoration(labelText: 'Hobbies (optional)',
              prefixIcon: Icon(Icons.interests_outlined),
              hintText: 'cooking, cycling, guitar',
              helperText: 'Separate with commas. Up to ${ProfileDetails.maxInterests}.'),
        ),
      ]);

  Widget _kidsFields(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ageField(),
      const SizedBox(height: 14),
      TextField(
        key: const ValueKey('details-school'),
        controller: _school, maxLength: ProfileDetails.maxSchool,
          inputFormatters: const [_CodePointLimit(ProfileDetails.maxSchool)],
        onChanged: (_) => _emit(),
        decoration: const InputDecoration(labelText: 'School (optional)', prefixIcon: Icon(Icons.school_outlined),
            helperText: 'A nickname like "my school" works too.'),
      ),
      const SizedBox(height: 8),
      Text('Favorite color', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (name, swatch) in favoriteColors) ChoiceChip(
          key: ValueKey('color-$name'),
          avatar: CircleAvatar(backgroundColor: swatch, radius: 9,
              child: name == 'White' ? DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: scheme.outline))) : null),
          label: Text(name),
          selected: _color == name,
          onSelected: (on) { setState(() => _color = on ? name : ''); _emit(); },
        ),
      ]),
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey('details-interests'),
        controller: _interests,
        onChanged: (_) => _emit(),
        decoration: const InputDecoration(labelText: 'Things they love (optional)',
            prefixIcon: Icon(Icons.favorite_outline),
            hintText: 'soccer, dinosaurs, drawing',
            helperText: 'Separate with commas. Up to ${ProfileDetails.maxInterests}.'),
      ),
    ]);
  }
}

/// Caps input at [max] Unicode code points, the unit the backend's length
/// limits count. `maxLength` alone counts graphemes, so a flag emoji (two code
/// points) would let the UI accept text the server then rejects.
class _CodePointLimit extends TextInputFormatter {
  const _CodePointLimit(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.text.runes.length <= max ? newValue : oldValue;
}
