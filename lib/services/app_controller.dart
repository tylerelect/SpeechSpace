import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'repository.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository);
  final MemoryRepository repository;

  bool loading = true;
  String? loadError;
  List<ChildProfile> children = [];
  List<JournalEntry> entries = [];
  List<MemoryLink> links = [];
  String? selectedChildId;

  bool get demo => repository.isDemo;
  ChildProfile? get child {
    for (final c in children) { if (c.id == selectedChildId) return c; }
    return null;
  }

  List<JournalEntry> get childEntries => entries.where((e) => e.childId == selectedChildId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  List<MemoryLink> get childLinks => links.where((l) => l.childId == selectedChildId).toList();

  Future<void> initialize() async {
    loading = true;
    notifyListeners();
    try {
      await refresh();
      loadError = null;
    } catch (error) {
      loadError = error.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final data = await repository.load();
    children = data.children;
    entries = data.entries;
    links = data.links;
    if (selectedChildId == null || !children.any((c) => c.id == selectedChildId)) {
      selectedChildId = children.isEmpty ? null : children.first.id;
    }
    notifyListeners();
  }

  void selectChild(String id) {
    selectedChildId = id;
    notifyListeners();
  }

  Future<void> addChild(String name) async {
    final created = await repository.addChild(name.trim());
    await refresh();
    selectChild(created.id);
  }

  Future<void> deleteCurrentChild() async {
    if (selectedChildId == null) return;
    await repository.deleteChild(selectedChildId!);
    await refresh();
  }

  Future<void> saveEntry(JournalEntry entry) async {
    await repository.saveEntry(entry);
    await refresh();
  }

  Future<void> deleteEntry(JournalEntry entry) async {
    await repository.deleteEntry(entry.id);
    await refresh();
  }

  Future<void> addLink(String from, String to, String label) async {
    if (from == to || selectedChildId == null) throw StateError('Choose two different memories.');
    if (childLinks.any((l) => (l.fromId == from && l.toId == to) || (l.fromId == to && l.toId == from))) {
      throw StateError('These memories are already connected.');
    }
    await repository.addLink(MemoryLink(id: '', childId: selectedChildId!, fromId: from, toId: to, label: label));
    await refresh();
  }

  Future<void> removeLink(String id) async {
    await repository.deleteLink(id);
    await refresh();
  }

  Future<AiInsight> analyze(String text) => repository.analyze(text);
  Future<String> transcribe(Uint8List wav) => repository.transcribe(wav);
}
