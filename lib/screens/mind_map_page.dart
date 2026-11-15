import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_controller.dart';
import '../widgets/entry_editor.dart';

class MindMapPage extends StatefulWidget {
  const MindMapPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> {
  final Map<String, Offset> _positions = {};
  String? _childId;

  void _ensurePositions(List<JournalEntry> entries) {
    if (_childId != widget.controller.selectedProfileId) {
      _positions.clear();
      _childId = widget.controller.selectedProfileId;
    }
    for (var i = 0; i < entries.length; i++) {
      _positions.putIfAbsent(entries[i].id, () {
        final angle = (2 * math.pi * i) / math.max(1, entries.length) - math.pi / 2;
        return Offset(380 + 250 * math.cos(angle), 250 + 165 * math.sin(angle));
      });
    }
    final ideas = widget.controller.profileIdeas;
    for (var i = 0; i < ideas.length; i++) {
      final idea = ideas[i];
      _positions.putIfAbsent(idea.id, () {
        // Place each suggestion just outside the centre of its source stars.
        final sources = idea.sourceIds.map((id) => _positions[id]).whereType<Offset>().toList();
        final centre = sources.isEmpty ? const Offset(390, 260)
            : sources.reduce((x, y) => x + y) / sources.length.toDouble();
        return _freeSpot(centre);
      });
    }
    _positions.removeWhere((key, value) => !entries.any((e) => e.id == key) && !ideas.any((i) => i.id == key));
  }

  /// First spot near [centre] that does not overlap an existing card (172×68).
  Offset _freeSpot(Offset centre) {
    bool free(Offset p) => _positions.values.every((q) => (p.dx - q.dx).abs() > 180 || (p.dy - q.dy).abs() > 76);
    for (final radius in const [130.0, 200.0, 280.0, 360.0]) {
      for (var k = 0; k < 12; k++) {
        final angle = k * math.pi / 6 + .3;
        final candidate = _clamp(centre + Offset(radius * math.cos(angle), radius * .7 * math.sin(angle)));
        if (free(candidate)) return candidate;
      }
    }
    return _clamp(centre + const Offset(0, 90)); // crowded map: overlap is unavoidable
  }

  static Offset _clamp(Offset p) => Offset(p.dx.clamp(88.0, 690.0), p.dy.clamp(34.0, 475.0));

  Future<void> _generateIdeas() async {
    final controller = widget.controller;
    final entries = controller.profileEntries;
    if (entries.isEmpty) return;
    final kids = controller.isKids;
    // Default: the 3 most recent entries (already sorted newest first).
    final chosen = entries.take(3).map((e) => e.id).toSet();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: Text(kids ? 'Make new idea stars' : 'Generate ideas'),
        content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kids ? 'Pick stories that go together. Gemini will suggest new ideas from them.'
              : 'Select related entries (up to 6). Gemini will suggest new ideas and recommendations.'),
          const SizedBox(height: 8),
          Flexible(child: ListView(shrinkWrap: true, children: [
            for (final e in entries) CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: chosen.contains(e.id),
              title: Text(e.title, overflow: TextOverflow.ellipsis),
              subtitle: e.tags.isEmpty ? null : Text(e.tags.join(', '), overflow: TextOverflow.ellipsis),
              onChanged: (v) => update(() {
                if (v == true && chosen.length < 6) { chosen.add(e.id); } else { chosen.remove(e.id); }
              }),
            ),
          ])),
          const SizedBox(height: 6),
          Text('${chosen.length}/6 selected • Suggestions are not saved unless you keep one.',
              style: Theme.of(ctx).textTheme.bodySmall),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(onPressed: chosen.isEmpty ? null : () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.auto_awesome), label: const Text('Generate')),
        ],
      ),
    ));
    if (ok != true || !mounted) return;
    try {
      final count = await controller.generateIdeas(chosen.toList());
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(count == 0
          ? 'No new ideas this time. Try picking different entries.'
          : 'Added $count suggested ${count == 1 ? 'star' : 'stars'}. Tap one to keep or dismiss it.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(error))));
    }
  }

  String _friendly(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '');
    if (text.contains('GEMINI_API_KEY') || text.contains('not configured')) {
      return 'Gemini is not configured on the backend yet (GEMINI_API_KEY).';
    }
    if (text.contains('TimeoutException') || text.contains('SocketException') || text.contains('ClientException')) {
      return 'Could not reach the backend. Check your connection and try again.';
    }
    return text;
  }

  Future<void> _openIdea(StarIdea idea) async {
    final controller = widget.controller;
    final titles = {for (final e in controller.profileEntries) e.id: e.title};
    final action = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 18), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, children: [
            Chip(avatar: Icon(idea.isRecommendation ? Icons.recommend_outlined : Icons.lightbulb_outline, size: 18),
                label: Text(idea.isRecommendation ? 'Recommendation' : 'Idea')),
            Chip(label: Text(idea.demo ? 'Demo sample (not Gemini)' : 'Suggested by Gemini')),
          ]),
          const SizedBox(height: 10),
          Text(idea.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (idea.detail.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(idea.detail)),
          const SizedBox(height: 12),
          Text('Based on: ${idea.sourceIds.map((id) => titles[id] ?? 'an entry').join(' • ')}',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text('A suggestion only. Review it before keeping; it is not an assessment of anyone.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(children: [
            TextButton.icon(onPressed: () => Navigator.pop(ctx, 'dismiss'),
                icon: const Icon(Icons.close), label: const Text('Dismiss')),
            const Spacer(),
            FilledButton.icon(onPressed: () => Navigator.pop(ctx, 'keep'),
                icon: const Icon(Icons.edit_note), label: Text(controller.isKids ? 'Tell this story' : 'Write entry')),
          ]),
        ],
      )));
    });
    if (!mounted) return;
    if (action == 'dismiss') setState(() => controller.dismissIdea(idea.id));
    if (action == 'keep') {
      await openEntryEditor(context, controller, suggestion: idea, onSaved: (saved) async {
        try {
          await controller.acceptIdea(idea, saved);
        } catch (error) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(error))));
        }
      });
    }
  }

  Future<void> _addConnection() async {
    final entries = widget.controller.profileEntries;
    if (entries.length < 2) return;
    String? from = entries.first.id;
    String? to = entries[1].id;
    final label = TextEditingController(text: 'related');
    final submitted = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: const Text('Connect two memories'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: from, isExpanded: true, decoration: const InputDecoration(labelText: 'First memory'),
            items: entries.map((e) => DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (value) => update(() => from = value)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: to, isExpanded: true, decoration: const InputDecoration(labelText: 'Second memory'),
            items: entries.map((e) => DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (value) => update(() => to = value)),
          const SizedBox(height: 12),
          TextField(controller: label, decoration: const InputDecoration(labelText: 'Relationship label')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: from == null || to == null || from == to ? null : () => Navigator.pop(ctx, true),
            child: const Text('Connect'))],
      ),
    ));
    final relation = label.text;
    label.dispose();
    if (submitted != true || from == null || to == null || !mounted) return;
    try {
      await widget.controller.addLink(from!, to!, relation.trim().isEmpty ? 'related' : relation.trim());
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _removeConnection() async {
    final links = widget.controller.profileLinks;
    if (links.isEmpty) return;
    final entries = {for (final e in widget.controller.profileEntries) e.id: e.title};
    final selected = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      title: const Text('Remove a connection'),
      children: links.map((l) => SimpleDialogOption(
        onPressed: () => Navigator.pop(ctx, l.id),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(
          '${entries[l.fromId] ?? 'Memory'} ↔ ${entries[l.toId] ?? 'Memory'} • ${l.label}')),
      )).toList(),
    ));
    if (selected != null) await widget.controller.removeLink(selected);
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.controller.profileEntries;
    final links = widget.controller.profileLinks;
    _ensurePositions(entries);
    final kids = widget.controller.isKids;
    final scheme = Theme.of(context).colorScheme;
    final ideas = widget.controller.profileIdeas;
    final generating = widget.controller.generatingIdeas;
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(kids ? 'Star map' : 'Mind map',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
        if (generating) const Padding(padding: EdgeInsets.only(right: 10),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))),
        FilledButton.icon(onPressed: entries.isEmpty || generating ? null : _generateIdeas,
          icon: const Icon(Icons.auto_awesome), label: Text(kids ? 'New ideas' : 'Ideas')),
        const SizedBox(width: 8),
        if (entries.length >= 2) IconButton(tooltip: 'Remove connection', icon: const Icon(Icons.link_off), onPressed: _removeConnection),
        FilledButton.tonalIcon(onPressed: entries.length >= 2 ? _addConnection : null,
          icon: const Icon(Icons.add_link), label: const Text('Link')),
      ]),
      const SizedBox(height: 8),
      Text(kids ? 'Drag your stories around and connect them like stars. Tap "New ideas" to make idea stars!'
          : 'Drag cards to arrange entries. Tap a card to edit it. Use Ideas to get Gemini suggestions from related entries.'),
      const SizedBox(height: 10),
      Expanded(child: Card(clipBehavior: Clip.antiAlias, child: entries.isEmpty
        ? Center(child: Text(kids ? 'Tell a story to see it here!' : 'Create some entries to see them here.'))
        : InteractiveViewer(
            minScale: .5,
            maxScale: 2.5,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(100),
            child: SizedBox(width: 780, height: 520, child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _LinksPainter(_positions, links, scheme.primary, scheme.onSurface,
                  ideas: ideas, ideaColor: scheme.tertiary))),
              ...entries.map((entry) {
                final point = _positions[entry.id] ?? Offset.zero;
                return Positioned(
                  key: ValueKey(entry.id),
                  left: point.dx - 86,
                  top: point.dy - 33,
                  child: GestureDetector(
                    onPanUpdate: (detail) => setState(() {
                      _positions[entry.id] = Offset((point.dx + detail.delta.dx).clamp(88.0, 690.0),
                        (point.dy + detail.delta.dy).clamp(34.0, 475.0));
                    }),
                    onTap: () => openEntryEditor(context, widget.controller, entry: entry),
                    child: Container(
                      width: 172, height: 68,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        border: Border.all(color: scheme.primary),
                        borderRadius: BorderRadius.circular(kids ? 34 : 14),
                        boxShadow: const [BoxShadow(color: Color(0x15000000), blurRadius: 8, offset: Offset(0, 3))]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(entry.title, overflow: TextOverflow.ellipsis, maxLines: 1,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: scheme.onPrimaryContainer)),
                        Text(entry.tags.isNotEmpty ? entry.tags.first : (kids ? 'Story' : 'Entry'),
                          overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer)),
                      ]),
                    ),
                  ),
                );
              }),
              ...ideas.map((idea) {
                final point = _positions[idea.id] ?? Offset.zero;
                return Positioned(
                  key: ValueKey(idea.id),
                  left: point.dx - 86,
                  top: point.dy - 33,
                  child: GestureDetector(
                    onPanUpdate: (detail) => setState(() => _positions[idea.id] = _clamp(point + detail.delta)),
                    onTap: () => _openIdea(idea),
                    child: _IdeaNode(idea: idea, kids: kids),
                  ),
                );
              }),
            ])),
          ))),
    ]));
  }
}

/// A suggested (not yet saved) star: lighter, outlined, with an idea icon.
class _IdeaNode extends StatelessWidget {
  const _IdeaNode({required this.idea, required this.kids});
  final StarIdea idea;
  final bool kids;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Suggested ${idea.isRecommendation ? 'recommendation' : 'idea'}: ${idea.title}',
      child: Container(
        width: 172, height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: .55),
          border: Border.all(color: scheme.tertiary.withValues(alpha: .8), width: 1.5),
          borderRadius: BorderRadius.circular(kids ? 34 : 14)),
        child: Row(children: [
          Icon(idea.isRecommendation ? Icons.recommend_outlined : Icons.lightbulb_outline,
              size: 20, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(idea.title, overflow: TextOverflow.ellipsis, maxLines: 1,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: scheme.onTertiaryContainer)),
            Text(idea.isRecommendation ? 'Try this • tap to keep' : 'Idea • tap to keep',
                overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: scheme.onTertiaryContainer)),
          ])),
        ]),
      ),
    );
  }
}

class _LinksPainter extends CustomPainter {
  const _LinksPainter(this.positions, this.links, this.lineColor, this.labelColor,
      {this.ideas = const [], this.ideaColor = const Color(0xFF888888)});
  final List<StarIdea> ideas;
  final Color ideaColor;
  final Color lineColor;
  final Color labelColor;
  final Map<String, Offset> positions;
  final List<MemoryLink> links;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: .7)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (final link in links) {
      final a = positions[link.fromId];
      final b = positions[link.toId];
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, paint);
      final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final textPainter = TextPainter(
        text: TextSpan(text: link.label, style: TextStyle(fontSize: 10, color: labelColor)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 128);
      textPainter.paint(canvas, midpoint + const Offset(5, -16));
    }
    // Dashed lines from each suggestion to the entries it came from.
    final dashed = Paint()
      ..color = ideaColor.withValues(alpha: .7)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final idea in ideas) {
      final a = positions[idea.id];
      if (a == null) continue;
      for (final source in idea.sourceIds) {
        final b = positions[source];
        if (b != null) _dash(canvas, a, b, dashed);
      }
    }
  }

  static void _dash(Canvas canvas, Offset a, Offset b, Paint paint) {
    final delta = b - a;
    final length = delta.distance;
    if (length == 0) return;
    final step = delta / length;
    for (var d = 0.0; d < length; d += 12) {
      canvas.drawLine(a + step * d, a + step * math.min(d + 6, length), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinksPainter oldDelegate) => true;
}
