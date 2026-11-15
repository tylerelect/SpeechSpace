import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_controller.dart';
import '../services/sound_service.dart';
import '../theme/space_themes.dart';
import '../widgets/commander_video.dart';
import '../widgets/profile_details_form.dart';

/// Opens the setup flow as a full-screen page. Resolves to the new profile, or
/// null if the user backed out.
Future<SpaceProfile?> openProfileSetup(BuildContext context, AppController controller) =>
    Navigator.of(context).push<SpaceProfile>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProfileSetupPage(controller: controller),
    ));

/// Step-by-step profile creation: who → about (optional) → look → commander
/// (Kids only).
/// The page previews the chosen theme live while you configure it.
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _name = TextEditingController();
  String _kind = SpaceProfile.kids;
  String _themeId = 'space';
  String _voice = 'f';
  ProfileDetails _details = ProfileDetails.empty;
  int _step = 0;
  bool _saving = false;
  String? _error;

  SoundService get _sound => widget.controller.sound;
  bool get _kids => _kind == SpaceProfile.kids;
  int get _lastStep => _kids ? 3 : 2;
  bool get _nameValid => _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    // Restore the sound service for the active profile. Deferred because these
    // calls notify listeners, which is not allowed while the tree is unmounting.
    final sound = _sound;
    final controller = widget.controller;
    Future.microtask(() {
      sound.stopBriefing();
      sound.selectVoice(controller.voice);
      if (!controller.isKids) sound.stopMusic();
    });
    super.dispose();
  }

  void _setKind(String kind) => setState(() {
        // Details are kind-specific (e.g. the age range), so start over.
        if (kind != _kind) _details = ProfileDetails.empty;
        _kind = kind;
        _themeId = themesFor(kind).first.id;
        if (kind == SpaceProfile.adult) _sound.stopMusic();
      });

  Future<void> _preview(String voice) async {
    setState(() => _voice = voice);
    await showCommanderBriefing(context, _sound, voice: voice);
  }

  Future<void> _finish() async {
    setState(() { _saving = true; _error = null; });
    try {
      await _sound.stopBriefing();
      final created = await widget.controller.addProfile(_name.text, _kind,
          themeId: _themeId, voice: _kids ? _voice : null, details: _details);
      if (mounted) Navigator.of(context).pop(created);
    } on ProfileSetupIncomplete catch (e) {
      // The profile exists, so retrying here would create a duplicate: go on
      // with it and say what's missing.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      Navigator.of(context).pop(e.profile);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = '$e'; });
    }
  }

  void _next() {
    if (_step == 0 && !_nameValid) return;
    if (_step < _lastStep) { setState(() => _step++); } else { _finish(); }
  }

  @override
  Widget build(BuildContext context) {
    final spaceTheme = resolveTheme(_themeId, _kind);
    return Theme(
      data: buildTheme(spaceTheme),
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: const Text('New profile'),
            leading: IconButton(tooltip: 'Cancel', icon: const Icon(Icons.close),
                onPressed: _saving ? null : () => Navigator.of(context).pop()),
          ),
          body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _StepDots(count: _lastStep + 1, current: _step),
              const SizedBox(height: 20),
              ...switch ((_step, _kids)) {
                (0, _) => _whoStep(theme),
                (1, _) => _aboutStep(theme),
                (2, _) => _lookStep(theme),
                _ => _commanderStep(theme),
              },
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
              const SizedBox(height: 28),
              Row(children: [
                if (_step > 0) TextButton.icon(onPressed: _saving ? null : () => setState(() => _step--),
                    icon: const Icon(Icons.arrow_back), label: const Text('Back')),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving || (_step == 0 && !_nameValid) ? null : _next,
                  icon: Icon(_step == _lastStep ? Icons.check : Icons.arrow_forward),
                  label: Text(_saving ? 'Creating…' : _step == _lastStep ? (_kids ? 'Blast off!' : 'Create profile') : 'Next'),
                ),
              ]),
            ],
          ))),
        );
      }),
    );
  }

  List<Widget> _whoStep(ThemeData theme) => [
        Text('Who is this profile for?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(
          controller: _name, maxLength: 40, autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _next(),
          decoration: const InputDecoration(labelText: 'Name or nickname (required)',
              helperText: 'Use a nickname or fictional name in this prototype.'),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _KindCard(
            icon: Icons.rocket_launch_rounded, title: 'Kids',
            subtitle: 'Big buttons, simple prompts, space commander and music',
            selected: _kids, onTap: () => _setKind(SpaceProfile.kids),
          )),
          const SizedBox(width: 12),
          Expanded(child: _KindCard(
            icon: Icons.person_outline, title: 'Adult',
            subtitle: 'Neutral wording and a productivity-focused layout',
            selected: !_kids, onTap: () => _setKind(SpaceProfile.adult),
          )),
        ]),
      ];

  List<Widget> _aboutStep(ThemeData theme) => [
        Text('About ${_name.text.trim()}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(_kids
            ? 'Optional. These details help SpeechSpace ask fun questions like "How was school today?" '
                'or "Did you see anything blue?". You can skip this or change it later in Settings.'
            : 'Optional. These details help SpeechSpace ask practical questions like "How did work go today?" '
                'or "Any progress on your goal?". Use made-up details in this prototype. '
                'You can skip this or change it later in Settings.'),
        const SizedBox(height: 16),
        ProfileDetailsForm(key: ValueKey('details-form-$_kind'), kind: _kind, initial: _details,
            onChanged: (d) => _details = d),
      ];

  List<Widget> _lookStep(ThemeData theme) => [
        Text('Pick a look', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('You can change this later in Settings.'),
        const SizedBox(height: 16),
        for (final t in themesFor(_kind)) Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            color: t.background,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: _themeId == t.id ? t.seed : Colors.transparent, width: 2.5)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(backgroundColor: t.seed, child: Icon(t.icon, color: Colors.white, size: 20)),
              title: Text(t.label, style: TextStyle(fontWeight: FontWeight.w700,
                  color: t.brightness == Brightness.dark ? Colors.white : Colors.black87)),
              trailing: _themeId == t.id ? Icon(Icons.check_circle, color: t.seed) : null,
              onTap: () => setState(() => _themeId = t.id),
            ),
          ),
        ),
      ];

  List<Widget> _commanderStep(ThemeData theme) => [
        Text('Choose your commander', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('The commander gives a video mission briefing on the Today screen.'),
        const SizedBox(height: 16),
        ListenableBuilder(listenable: _sound, builder: (context, _) => Column(children: [
          for (final v in const [('f', 'Commander (female)'), ('m', 'Commander (male)')]) Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: _voice == v.$1 ? theme.colorScheme.primary : Colors.transparent, width: 2.5)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Icon(_voice == v.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: theme.colorScheme.primary),
              title: Text(v.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: IconButton.filledTonal(
                tooltip: 'Watch preview',
                icon: const Icon(Icons.smart_display_outlined),
                onPressed: () => _preview(v.$1),
              ),
              onTap: () => setState(() => _voice = v.$1),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Play space music'),
            subtitle: const Text('Pauses automatically while recording.'),
            value: _sound.musicOn,
            onChanged: (_) => _sound.toggleMusic(),
          ),
          if (_sound.musicOn) Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < SoundService.tracks.length; i++) ChoiceChip(
              label: Text('Track ${i + 1}'),
              selected: _sound.trackIndex == i,
              onSelected: (_) => _sound.selectTrack(i),
            ),
          ])),
          if (_sound.error != null) Padding(padding: const EdgeInsets.only(top: 10),
              child: Text(_sound.error!, style: TextStyle(color: theme.colorScheme.error))),
        ])),
      ];
}

class _KindCard extends StatelessWidget {
  const _KindCard({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2.5 : 1)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 36, color: scheme.primary),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle),
        ])),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      for (var i = 0; i < count; i++) AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        width: i == current ? 28 : 10, height: 10,
        decoration: BoxDecoration(
          color: i <= current ? scheme.primary : scheme.outlineVariant,
          borderRadius: BorderRadius.circular(5)),
      ),
      const SizedBox(width: 6),
      Text('Step ${current + 1} of $count', style: TextStyle(color: scheme.onSurfaceVariant)),
    ]);
  }
}
