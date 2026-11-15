import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../services/sound_service.dart';
import '../theme/space_themes.dart';
import 'app_shell.dart' show ProfileAvatar;
import 'profile_setup_page.dart';
import '../widgets/commander_video.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  Future<void> _add(BuildContext context) => openProfileSetup(context, controller);

  Future<void> _delete(BuildContext context) async {
    final profile = controller.profile;
    if (profile == null) return;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Delete ${profile.name}\'s profile?'),
      content: Text('This permanently deletes this ${profile.isKids ? 'Kids' : 'Adult'} profile, its memories, and connections.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (yes != true || !context.mounted) return;
    try { await controller.deleteCurrentProfile(); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _setTheme(BuildContext context, String id) async {
    try { await controller.setTheme(id); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    return Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 850),
    child: ListView(padding: const EdgeInsets.all(22), children: [
      Text(controller.copy.navSettings, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      if (controller.isKids) const Padding(padding: EdgeInsets.only(top: 4),
          child: Text('These settings are for a parent or guardian.')),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Profiles', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ...controller.profiles.map((p) => ListTile(
          leading: ProfileAvatar(profile: p),
          title: Text(p.name),
          subtitle: Text(p.isKids ? 'Kids' : 'Adult'),
          trailing: p.id == controller.selectedProfileId ? const Icon(Icons.check_circle) : null,
          onTap: () => controller.selectProfile(p.id),
        )),
        Wrap(spacing: 12, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.person_add_alt_1), label: const Text('Add profile')),
          if (profile != null) OutlinedButton.icon(onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline), label: const Text('Delete selected')),
        ]),
      ]))),
      if (profile != null) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Theme for ${profile.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final t in themesFor(profile.kind)) ChoiceChip(
              avatar: CircleAvatar(backgroundColor: t.seed, child: Icon(t.icon, size: 14, color: Colors.white)),
              label: Text(t.label),
              selected: controller.spaceTheme.id == t.id,
              onSelected: (_) => _setTheme(context, t.id),
            ),
          ]),
        ]))),
      ],
      if (controller.isKids) ...[
        const SizedBox(height: 12),
        _KidsSoundCard(controller: controller),
      ],
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Integrations', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _setting(Icons.storage_outlined, 'MongoDB Atlas', controller.demo ? 'Not connected • memory-only demo' : 'Connected through backend API'),
        _setting(Icons.auto_awesome_outlined, 'Gemini Flash', 'Optional backend text analysis • configure GEMINI_API_KEY and GEMINI_MODEL'),
        _setting(Icons.mic_none_outlined, 'Voice transcription', 'Model undecided • configure STT_ENDPOINT_URL for an external speech service'),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Privacy and guardian controls', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const Text('Prototype only. Do not enter real children\'s personal data until guardian sign-in, verified consent, access controls, security review, privacy notices, and a retention policy are complete.'),
        const SizedBox(height: 9),
        const Text('Microphone use is initiated by the user. Voice uploads are processed only through your configured backend. This app does not infer medical or developmental diagnoses.'),
        const SizedBox(height: 9),
        if (controller.demo) const Text('Demo mode: changes are only held in memory and disappear when the application restarts.'),
      ]))),
    ]),
  ));
  }

  Widget _setting(IconData icon, String title, String sub) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon), title: Text(title), subtitle: Text(sub),
  );
}

class _KidsSoundCard extends StatelessWidget {
  const _KidsSoundCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final sound = controller.sound;
    return ListenableBuilder(listenable: sound, builder: (context, _) => Card(child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Commander and music for ${controller.profile?.name ?? 'this profile'}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Kids mode only. The voice is saved per profile; music pauses automatically while recording.'),
        const SizedBox(height: 14),
        const Text('Commander voice', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'f', label: Text('Commander (female)')),
              ButtonSegment(value: 'm', label: Text('Commander (male)')),
            ],
            selected: {controller.voice},
            onSelectionChanged: (v) => controller.setVoice(v.first),
          ),
          TextButton.icon(
            onPressed: () => showCommanderBriefing(context, sound, voice: controller.voice),
            icon: const Icon(Icons.smart_display_outlined),
            label: const Text('Preview video'),
          ),
        ]),
        const SizedBox(height: 16),
        const Text('Background music', style: TextStyle(fontWeight: FontWeight.w600)),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Play space music'),
          value: sound.musicOn,
          onChanged: (_) => sound.toggleMusic(),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < SoundService.tracks.length; i++) ChoiceChip(
            label: Text('Track ${i + 1}'),
            selected: sound.trackIndex == i,
            onSelected: (_) => sound.selectTrack(i),
          ),
        ]),
        if (sound.error != null) Padding(padding: const EdgeInsets.only(top: 10),
            child: Text(sound.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ]),
    )));
  }
}
