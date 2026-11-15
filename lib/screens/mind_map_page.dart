import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../models/models.dart';
import '../services/app_controller.dart';
import '../services/layout_store.dart';
import '../widgets/entry_editor.dart';
import '../widgets/space_art.dart';

/// Size of one card on the map.
const mindMapNodeSize = Size(176, 72);

/// Canvas size for [count] entries: the classic 780×520 board for small maps,
/// growing with the grid layout for larger ones so cards never have to overlap.
Size mindMapCanvasFor(int count) {
  if (count <= _ellipseMax) return const Size(780, 520);
  final cols = _gridCols(count);
  final rows = (count / cols).ceil();
  return Size(math.max(780, 2 * _margin + cols * _colStep + _colStep / 2),
      math.max(520, 2 * _margin + rows * _rowStep));
}

const _ellipseMax = 6;
const _margin = 20.0;
const _colStep = 200.0;
const _rowStep = 100.0;
int _gridCols(int count) => math.max(3, math.sqrt(count * 1.6).ceil());

/// Default, overlap-free card centres for [count] entries (newest first): an
/// ellipse for up to six cards, then a staggered grid.
List<Offset> defaultMindMapLayout(int count) {
  if (count <= _ellipseMax) {
    double angle(int i) => (2 * math.pi * i) / math.max(1, count) - math.pi / 2;
    return [for (var i = 0; i < count; i++) Offset(390 + 250 * math.cos(angle(i)), 260 + 165 * math.sin(angle(i)))];
  }
  final cols = _gridCols(count);
  return [
    for (var i = 0; i < count; i++)
      Offset(_margin + mindMapNodeSize.width / 2 + (i % cols) * _colStep + ((i ~/ cols).isOdd ? _colStep / 2 : 0),
          _margin + mindMapNodeSize.height / 2 + (i ~/ cols) * _rowStep),
  ];
}

class MindMapPage extends StatefulWidget {
  const MindMapPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> {
  final Map<String, Offset> _positions = {};
  final _transform = TransformationController();
  String? _childId;
  String? _selectedId;
  Size _canvas = mindMapCanvasFor(0);
  Size _viewport = Size.zero;
  bool _needsFit = false;

  static const _minScale = .25;
  static const _maxScale = 2.5;

  AppController get _c => widget.controller;


  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _ensurePositions(List<JournalEntry> entries) {
    final profileId = _c.selectedProfileId;
    if (_childId != profileId) {
      // New profile: forget every transient bit of the previous one.
      _positions.clear();
      _selectedId = null;
      _childId = profileId;
      _needsFit = true; // also resets pan/zoom (after this frame, not during build)
      if (profileId != null) _loadSavedLayout(profileId);
    }
    _canvas = mindMapCanvasFor(entries.length);
    final defaults = defaultMindMapLayout(entries.length);
    for (var i = 0; i < entries.length; i++) {
      if (_positions.containsKey(entries[i].id)) continue;
      final slot = defaults[i];
      _positions[entries[i].id] = _isFree(slot) ? slot : _freeSpot(slot);
    }
    final ideas = _c.profileIdeas;
    for (final idea in ideas) {
      _positions.putIfAbsent(idea.id, () {
        // Place each suggestion just outside the centre of its source stars.
        final sources = idea.sourceIds.map((id) => _positions[id]).whereType<Offset>().toList();
        final centre = sources.isEmpty ? Offset(_canvas.width / 2, _canvas.height / 2)
            : sources.reduce((x, y) => x + y) / sources.length.toDouble();
        return _freeSpot(centre);
      });
    }
    _positions.removeWhere((key, value) => !entries.any((e) => e.id == key) && !ideas.any((i) => i.id == key));
    for (final key in _positions.keys.toList()) { _positions[key] = _clamp(_positions[key]!); }
    if (_selectedId != null && !_positions.containsKey(_selectedId)) _selectedId = null;
  }

  Future<void> _loadSavedLayout(String profileId) async {
    final saved = await MindMapLayoutStore.load(profileId);
    if (!mounted || _childId != profileId || saved.isEmpty) return;
    setState(() {
      final ids = _c.profileEntries.map((e) => e.id).toSet();
      saved.forEach((id, p) { if (ids.contains(id)) _positions[id] = _clamp(p); });
      _needsFit = true;
    });
  }

  void _saveLayout() {
    final profileId = _childId;
    if (profileId == null) return;
    final ids = _c.profileEntries.map((e) => e.id).toSet(); // ideas are session-only
    MindMapLayoutStore.save(profileId, {for (final e in _positions.entries) if (ids.contains(e.key)) e.key: e.value});
  }

  Future<void> _resetLayout() async {
    final profileId = _childId;
    if (profileId != null) await MindMapLayoutStore.clear(profileId);
    if (!mounted) return;
    setState(() {
      _positions.clear();
      _selectedId = null;
      _needsFit = true;
    });
  }

  bool _isFree(Offset p) => _positions.values.every((q) =>
      (p.dx - q.dx).abs() > mindMapNodeSize.width + 4 || (p.dy - q.dy).abs() > mindMapNodeSize.height + 4);

  /// First spot near [centre] that does not overlap an existing card.
  Offset _freeSpot(Offset centre) {
    for (final radius in const [130.0, 200.0, 280.0, 360.0, 460.0, 580.0]) {
      for (var k = 0; k < 12; k++) {
        final angle = k * math.pi / 6 + .3;
        final candidate = _clamp(centre + Offset(radius * math.cos(angle), radius * .7 * math.sin(angle)));
        if (_isFree(candidate)) return candidate;
      }
    }
    return _clamp(centre + const Offset(0, 90)); // crowded map: overlap is unavoidable
  }

  Offset _clamp(Offset p) {
    final hw = mindMapNodeSize.width / 2, hh = mindMapNodeSize.height / 2;
    return Offset(p.dx.clamp(hw, math.max(hw, _canvas.width - hw)), p.dy.clamp(hh, math.max(hh, _canvas.height - hh)));
  }

  // ---- Pan / zoom controls --------------------------------------------------

  /// Fits every card into the visible area. [maxScale] 1 = never enlarge.
  void _fit({double maxScale = 1.5}) {
    if (_positions.isEmpty || _viewport.isEmpty) {
      _transform.value = Matrix4.identity();
      return;
    }
    var bounds = Rect.zero;
    var first = true;
    for (final p in _positions.values) {
      final r = Rect.fromCenter(center: p, width: mindMapNodeSize.width, height: mindMapNodeSize.height);
      bounds = first ? r : bounds.expandToInclude(r);
      first = false;
    }
    bounds = bounds.inflate(24);
    final scale = math.min(_viewport.width / bounds.width, _viewport.height / bounds.height).clamp(_minScale, maxScale);
    final tx = (_viewport.width - bounds.width * scale) / 2 - bounds.left * scale;
    final ty = (_viewport.height - bounds.height * scale) / 2 - bounds.top * scale;
    _transform.value = Matrix4.diagonal3Values(scale, scale, scale)..setTranslationRaw(tx, ty, 0);
  }

  void _zoom(double factor) {
    final m = _transform.value;
    final current = m.getMaxScaleOnAxis();
    final next = (current * factor).clamp(_minScale, _maxScale);
    final f = next / current;
    final c = Offset(_viewport.width / 2, _viewport.height / 2);
    final t = m.getTranslation();
    _transform.value = Matrix4.diagonal3Values(next, next, next)
      ..setTranslationRaw(c.dx + f * (t.x - c.dx), c.dy + f * (t.y - c.dy), 0);
  }

  // ---- AI ideas (unchanged behavior) ----------------------------------------

  Future<void> _generateIdeas() async {
    final controller = _c;
    final entries = controller.profileEntries;
    if (entries.isEmpty) return;
    final kids = controller.isKids;
    final decor = KidsDecor.of(controller.spaceTheme.id);
    // Default: the 3 most recent entries (already sorted newest first).
    final chosen = entries.take(3).map((e) => e.id).toSet();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: Text(kids ? 'Make new idea ${decor.nouns}' : 'Generate ideas'),
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
          : 'Added $count suggested ${count == 1 ? decor.noun : decor.nouns}. Tap one to keep or dismiss it.')));
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
    final controller = _c;
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

  // ---- Manual links (unchanged behavior) ------------------------------------

  Future<void> _addConnection() async {
    final entries = _c.profileEntries;
    if (entries.length < 2) return;
    // Start from the selected card, if any.
    final from = _selectedId != null && entries.any((e) => e.id == _selectedId) ? _selectedId! : entries.first.id;
    final to = entries.firstWhere((e) => e.id != from).id;
    final result = await showDialog<(String, String, String)>(context: context,
        builder: (ctx) => _ConnectDialog(entries: entries, from: from, to: to));
    if (result == null || !mounted) return;
    final (a, b, relation) = result;
    try {
      await _c.addLink(a, b, relation.trim().isEmpty ? 'related' : relation.trim());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }

  Future<void> _removeConnection() async {
    final links = _c.profileLinks;
    if (links.isEmpty) return;
    final entries = {for (final e in _c.profileEntries) e.id: e.title};
    // The selected card's connections are listed first.
    final ordered = [
      ...links.where((l) => l.fromId == _selectedId || l.toId == _selectedId),
      ...links.where((l) => l.fromId != _selectedId && l.toId != _selectedId),
    ];
    final selected = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      title: const Text('Remove a connection'),
      children: ordered.map((l) => SimpleDialogOption(
        onPressed: () => Navigator.pop(ctx, l.id),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(
          '${entries[l.fromId] ?? 'Memory'} ↔ ${entries[l.toId] ?? 'Memory'} • ${l.label}')),
      )).toList(),
    ));
    if (selected == null) return;
    try {
      await _c.removeLink(selected);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _select(String? id) {
    if (_selectedId == id) return;
    setState(() => _selectedId = id);
  }

  Future<void> _edit(JournalEntry entry) async {
    _select(entry.id);
    await openEntryEditor(context, _c, entry: entry);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _c.profileEntries;
    final links = _c.profileLinks;
    _ensurePositions(entries);
    final kids = _c.isKids;
    final themeId = _c.spaceTheme.id;
    final decor = KidsDecor.of(themeId);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ideas = _c.profileIdeas;
    final generating = _c.generatingIdeas;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final selected = entries.where((e) => e.id == _selectedId).firstOrNull;
    final selectedLinks = selected == null ? 0 : links.where((l) => l.fromId == _selectedId || l.toId == _selectedId).length;

    final toolbar = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (generating) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
      FilledButton.icon(onPressed: entries.isEmpty || generating ? null : _generateIdeas,
        icon: const Icon(Icons.auto_awesome), label: Text(kids ? 'New ideas' : 'Ideas')),
      if (entries.length >= 2) IconButton(tooltip: 'Remove connection', icon: const Icon(Icons.link_off),
          onPressed: links.isEmpty ? null : _removeConnection),
      FilledButton.tonalIcon(onPressed: entries.length >= 2 ? _addConnection : null,
        icon: const Icon(Icons.add_link), label: const Text('Link')),
    ]);

    final viewControls = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(tooltip: 'Zoom out', icon: const Icon(Icons.zoom_out), onPressed: entries.isEmpty ? null : () => _zoom(1 / 1.25)),
      IconButton(tooltip: 'Zoom in', icon: const Icon(Icons.zoom_in), onPressed: entries.isEmpty ? null : () => _zoom(1.25)),
      IconButton(tooltip: 'Fit to screen', icon: const Icon(Icons.fit_screen_outlined),
          onPressed: entries.isEmpty ? null : () => setState(_fit)),
      IconButton(tooltip: 'Reset layout', icon: const Icon(Icons.restart_alt),
          onPressed: entries.isEmpty ? null : _resetLayout),
    ]);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _select(null)},
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (kids) ...[SpaceArt.of(themeId, ArtRole.hero, size: 40), const SizedBox(width: 10)],
          Expanded(child: Text(kids ? decor.mapName : 'Mind map',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
          if (!narrow) toolbar,
        ]),
        if (narrow) Padding(padding: const EdgeInsets.only(top: 8), child: toolbar),
        const SizedBox(height: 8),
        Text(kids ? 'Drag your stories around and connect them like ${decor.nouns}. Tap "New ideas" to make idea ${decor.nouns}!'
            : 'Drag cards to arrange entries. Tap a card to edit it. Use Ideas to get Gemini suggestions from related entries.'),
        const SizedBox(height: 4),
        Text(narrow
            ? 'Pinch to zoom • drag the background to pan • drag a card to move it'
            : 'Scroll or pinch to zoom • drag the background to pan • drag a card to move it • Esc clears the selection',
            key: const ValueKey('mindmap-hint'),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: selected == null
              ? Text(entries.length == 1 ? 'Add another ${kids ? 'story' : 'entry'} to make connections.' : '',
                  style: theme.textTheme.bodySmall)
              : Row(children: [
                  Flexible(child: Text('Selected: ${selected.title} • $selectedLinks '
                      '${selectedLinks == 1 ? 'connection' : 'connections'}',
                      key: const ValueKey('mindmap-selected'), overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  IconButton(tooltip: 'Clear selection', visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18), onPressed: () => _select(null)),
                ])),
          viewControls,
        ]),
        Expanded(child: Card(clipBehavior: Clip.antiAlias, color: kids ? Colors.transparent : null, child: Stack(children: [
          if (kids) Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: MapScenePainter(themeId)))),
          Positioned.fill(child: entries.isEmpty
          ? Center(child: Text(kids ? 'Tell a story to see it here!' : 'Create some entries to see them here.'))
          : LayoutBuilder(builder: (context, constraints) {
              _viewport = constraints.biggest;
              if (_needsFit) {
                _needsFit = false;
                // Shrink to fit large maps on first view; never enlarge automatically.
                WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _fit(maxScale: 1); });
              }
              return InteractiveViewer(
                transformationController: _transform,
                minScale: _minScale,
                maxScale: _maxScale,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(400),
                child: SizedBox(width: _canvas.width, height: _canvas.height, child: Stack(children: [
                  // Tapping empty space clears the selection.
                  Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _select(null))),
                  Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _LinksPainter(
                      _positions, links, scheme.primary, scheme.onSurface,
                      labelBackground: scheme.surface, selectedId: _selectedId,
                      ideas: ideas, ideaColor: scheme.tertiary, endDots: kids)))),
                  ...entries.map((entry) {
                    final point = _positions[entry.id] ?? Offset.zero;
                    final count = links.where((l) => l.fromId == entry.id || l.toId == entry.id).length;
                    return Positioned(
                      key: ValueKey(entry.id),
                      left: point.dx - mindMapNodeSize.width / 2,
                      top: point.dy - mindMapNodeSize.height / 2,
                      child: _EntryNode(
                        entry: entry,
                        kids: kids,
                        themeId: themeId,
                        connections: count,
                        selected: entry.id == _selectedId,
                        dimmed: _selectedId != null && entry.id != _selectedId &&
                            !links.any((l) => (l.fromId == _selectedId && l.toId == entry.id) ||
                                (l.toId == _selectedId && l.fromId == entry.id)),
                        onTap: () => _edit(entry),
                        onFocused: () => _select(entry.id),
                        onDrag: (delta) => setState(() => _positions[entry.id] = _clamp(point + delta)),
                        onDragEnd: _saveLayout,
                      ),
                    );
                  }),
                  ...ideas.map((idea) {
                    final point = _positions[idea.id] ?? Offset.zero;
                    return Positioned(
                      key: ValueKey(idea.id),
                      left: point.dx - mindMapNodeSize.width / 2,
                      top: point.dy - mindMapNodeSize.height / 2,
                      child: GestureDetector(
                        onPanUpdate: (detail) => setState(() => _positions[idea.id] = _clamp(point + detail.delta)),
                        onTap: () => _openIdea(idea),
                        child: _IdeaNode(idea: idea, kids: kids, themeId: themeId),
                      ),
                    );
                  }),
                ])),
              );
            })),
        ]))),
      ])),
    );
  }
}

/// "Connect two memories". Owns its text controller so it is disposed only
/// after the dialog (including its exit animation) is gone.
class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog({required this.entries, required this.from, required this.to});
  final List<JournalEntry> entries;
  final String from;
  final String to;

  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  late String? _from = widget.from;
  late String? _to = widget.to;
  final _label = TextEditingController(text: 'related');

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.entries
        .map((e) => DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis))).toList();
    return AlertDialog(
      title: const Text('Connect two memories'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: _from, isExpanded: true,
            decoration: const InputDecoration(labelText: 'First memory'), items: items,
            onChanged: (value) => setState(() => _from = value)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: _to, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Second memory'), items: items,
            onChanged: (value) => setState(() => _to = value)),
        const SizedBox(height: 12),
        TextField(controller: _label, decoration: const InputDecoration(labelText: 'Relationship label')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _from == null || _to == null || _from == _to ? null : () => Navigator.pop(context, (_from!, _to!, _label.text)),
          child: const Text('Connect'),
        ),
      ],
    );
  }
}

/// A saved entry card: draggable, tap (or Enter) to edit, focus to select.
class _EntryNode extends StatelessWidget {
  const _EntryNode({required this.entry, required this.kids, this.themeId = 'space', required this.connections, required this.selected,
      required this.dimmed, required this.onTap, required this.onFocused, required this.onDrag, required this.onDragEnd});
  final JournalEntry entry;
  final bool kids;
  final String themeId;
  final int connections;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  final VoidCallback onFocused;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final noun = kids ? 'Story' : 'Entry';
    return FocusableActionDetector(
      onFocusChange: (focused) { if (focused) onFocused(); },
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { onTap(); return null; })},
      child: Semantics(
        button: true,
        selected: selected,
        label: '$noun: ${entry.title}. $connections ${connections == 1 ? 'connection' : 'connections'}. Activate to edit.',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          onPanUpdate: (detail) => onDrag(detail.delta),
          onPanEnd: (_) => onDragEnd(),
          child: Tooltip(
            message: entry.title,
            waitDuration: const Duration(milliseconds: 600),
            excludeFromSemantics: true,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: dimmed ? .45 : 1,
              child: Container(
                width: mindMapNodeSize.width, height: mindMapNodeSize.height,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  border: Border.all(color: scheme.primary, width: selected ? 3 : 1),
                  borderRadius: BorderRadius.circular(kids ? 34 : 14),
                  boxShadow: [BoxShadow(color: selected ? scheme.primary.withValues(alpha: .35) : const Color(0x15000000),
                      blurRadius: selected ? 14 : 8, offset: const Offset(0, 3))]),
                child: Row(children: [
                  // Kids: each story is a little themed sticker (star, starfish, flower).
                  if (kids) ...[SpaceArt.of(themeId, ArtRole.sticker, size: 34), const SizedBox(width: 8)],
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(entry.title, overflow: TextOverflow.ellipsis, maxLines: 2,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.15, color: scheme.onPrimaryContainer)),
                    const SizedBox(height: 2),
                    Text(entry.tags.isNotEmpty ? entry.tags.first : noun,
                      overflow: TextOverflow.ellipsis, maxLines: 1,
                      style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer)),
                  ])),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A suggested (not yet saved) star: lighter, outlined, with an idea icon.
class _IdeaNode extends StatelessWidget {
  const _IdeaNode({required this.idea, required this.kids, this.themeId = 'space'});
  final StarIdea idea;
  final bool kids;
  final String themeId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Suggested ${idea.isRecommendation ? 'recommendation' : 'idea'}: ${idea.title}',
      child: Container(
        width: mindMapNodeSize.width, height: mindMapNodeSize.height,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: .55),
          border: Border.all(color: scheme.tertiary.withValues(alpha: .8), width: 1.5),
          borderRadius: BorderRadius.circular(kids ? 34 : 14)),
        child: Row(children: [
          if (kids)
            SpaceArt.of(themeId, ArtRole.calm, size: 28)
          else
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
      {required this.labelBackground, this.selectedId, this.ideas = const [], this.ideaColor = const Color(0xFF888888), this.endDots = false});
  final List<StarIdea> ideas;
  final Color ideaColor;
  final bool endDots;
  final Color lineColor;
  final Color labelColor;
  final Color labelBackground;
  final String? selectedId;
  final Map<String, Offset> positions;
  final List<MemoryLink> links;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw dimmed links first so emphasized ones sit on top.
    final ordered = [
      ...links.where((l) => !_touchesSelection(l)),
      ...links.where(_touchesSelection),
    ];
    for (final link in ordered) {
      final a = positions[link.fromId];
      final b = positions[link.toId];
      if (a == null || b == null) continue;
      final emphasized = _touchesSelection(link);
      final dim = selectedId != null && !emphasized;
      final paint = Paint()
        ..color = lineColor.withValues(alpha: emphasized ? 1 : (dim ? .22 : .7))
        ..strokeWidth = emphasized ? 4 : 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, paint);
      if (endDots) {
        for (final end in [a, b]) { canvas.drawCircle(end, emphasized ? 6 : 4.5, Paint()..color = paint.color); }
      }
      final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final textPainter = TextPainter(
        text: TextSpan(text: link.label, style: TextStyle(fontSize: 10.5,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            color: labelColor.withValues(alpha: dim ? .45 : 1))),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 140);
      final origin = midpoint + Offset(-textPainter.width / 2, -textPainter.height - 4);
      // A soft pill behind the label keeps it readable over lines and cards.
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(origin.dx - 4, origin.dy - 1, textPainter.width + 8, textPainter.height + 2),
            const Radius.circular(6)),
        Paint()..color = labelBackground.withValues(alpha: dim ? .4 : .82),
      );
      textPainter.paint(canvas, origin);
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

  bool _touchesSelection(MemoryLink l) => selectedId != null && (l.fromId == selectedId || l.toId == selectedId);

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
