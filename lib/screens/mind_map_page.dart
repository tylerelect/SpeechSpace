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
    if (_childId != widget.controller.selectedChildId) {
      _positions.clear();
      _childId = widget.controller.selectedChildId;
    }
    for (var i = 0; i < entries.length; i++) {
      _positions.putIfAbsent(entries[i].id, () {
        final angle = (2 * math.pi * i) / math.max(1, entries.length) - math.pi / 2;
        return Offset(380 + 250 * math.cos(angle), 250 + 165 * math.sin(angle));
      });
    }
    _positions.removeWhere((key, value) => !entries.any((e) => e.id == key));
  }

  Future<void> _addConnection() async {
    final entries = widget.controller.childEntries;
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
    final links = widget.controller.childLinks;
    if (links.isEmpty) return;
    final entries = {for (final e in widget.controller.childEntries) e.id: e.title};
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
    final entries = widget.controller.childEntries;
    final links = widget.controller.childLinks;
    _ensurePositions(entries);
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Memory mind map',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
        if (entries.length >= 2) IconButton(tooltip: 'Remove connection', icon: const Icon(Icons.link_off), onPressed: _removeConnection),
        FilledButton.tonalIcon(onPressed: entries.length >= 2 ? _addConnection : null,
          icon: const Icon(Icons.add_link), label: const Text('Link')),
      ]),
      const SizedBox(height: 8),
      const Text('Drag cards to arrange your ideas. Tap a card to edit it. Links are stored independently of layout.'),
      const SizedBox(height: 10),
      Expanded(child: Card(clipBehavior: Clip.antiAlias, child: entries.isEmpty
        ? const Center(child: Text('Create some memories to see them here.'))
        : InteractiveViewer(
            minScale: .5,
            maxScale: 2.5,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(100),
            child: SizedBox(width: 780, height: 520, child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _LinksPainter(_positions, links))),
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
                        color: const Color(0xFFECE5FF),
                        border: Border.all(color: const Color(0xFF8872C7)),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Color(0x15000000), blurRadius: 8, offset: Offset(0, 3))]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(entry.title, overflow: TextOverflow.ellipsis, maxLines: 1,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(entry.tags.isNotEmpty ? entry.tags.first : 'Memory',
                          overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                      ]),
                    ),
                  ),
                );
              }),
            ])),
          ))),
    ]));
  }
}

class _LinksPainter extends CustomPainter {
  const _LinksPainter(this.positions, this.links);
  final Map<String, Offset> positions;
  final List<MemoryLink> links;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9A88C8)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (final link in links) {
      final a = positions[link.fromId];
      final b = positions[link.toId];
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, paint);
      final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final textPainter = TextPainter(
        text: TextSpan(text: link.label, style: const TextStyle(fontSize: 10, color: Color(0xFF514276))),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 128);
      textPainter.paint(canvas, midpoint + const Offset(5, -16));
    }
  }

  @override
  bool shouldRepaint(covariant _LinksPainter oldDelegate) => true;
}
