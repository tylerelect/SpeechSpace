import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/models.dart';

abstract class MemoryRepository {
  bool get isDemo;
  Future<AppSnapshot> load();
  Future<ChildProfile> addChild(String name);
  Future<void> deleteChild(String id);
  Future<JournalEntry> saveEntry(JournalEntry entry);
  Future<void> deleteEntry(String id);
  Future<MemoryLink> addLink(MemoryLink link);
  Future<void> deleteLink(String id);
  Future<AiInsight> analyze(String text);
  Future<String> transcribe(Uint8List wav);
}

String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
int _nextId = 0;

/// In-memory synthetic sample data. Changes are intentionally lost on restart.
class DemoRepository implements MemoryRepository {
  @override
  bool get isDemo => true;
  final List<ChildProfile> _children = [const ChildProfile(id: 'demo-alex', name: 'Alex')];
  final List<JournalEntry> _entries = [];
  final List<MemoryLink> _links = [];

  DemoRepository() {
    final today = DateTime.now();
    _entries.addAll([
      JournalEntry(id: 'demo-1', childId: 'demo-alex', date: today.subtract(const Duration(days: 1)), title: 'The big blue kite',
          body: 'Today we went outside. My favorite part was flying a big blue kite with Grandpa!', favorite: 'Blue kite',
          highlight: 'A happy afternoon flying a kite.', tags: const ['Outdoors', 'Family']),
      JournalEntry(id: 'demo-2', childId: 'demo-alex', date: today.subtract(const Duration(days: 4)), title: 'Favorite outfit',
          body: 'I wore my yellow raincoat because it has little ducks on it.', favorite: 'Yellow raincoat',
          highlight: 'Alex chose a favorite outfit.', tags: const ['Favorites']),
      JournalEntry(id: 'demo-3', childId: 'demo-alex', date: today.subtract(const Duration(days: 9)), title: 'Made a cardboard castle',
          body: 'We made a castle from boxes and drew windows and a drawbridge.',
          highlight: 'A creative day building a cardboard castle.', tags: const ['Creativity', 'Family']),
    ]);
    _links.add(const MemoryLink(id: 'demo-link', childId: 'demo-alex', fromId: 'demo-1', toId: 'demo-3', label: 'Family activities'));
  }

  @override
  Future<AppSnapshot> load() async => AppSnapshot(children: List.of(_children), entries: List.of(_entries), links: List.of(_links));

  @override
  Future<ChildProfile> addChild(String name) async {
    final child = ChildProfile(id: newId(), name: name);
    _children.add(child);
    return child;
  }

  @override
  Future<void> deleteChild(String id) async {
    _children.removeWhere((c) => c.id == id);
    _entries.removeWhere((e) => e.childId == id);
    _links.removeWhere((l) => l.childId == id);
  }

  @override
  Future<JournalEntry> saveEntry(JournalEntry entry) async {
    final saved = entry.id.isEmpty ? entry.copyWith(id: newId()) : entry;
    _entries.removeWhere((e) => e.id == saved.id);
    _entries.add(saved);
    return saved;
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    _links.removeWhere((l) => l.fromId == id || l.toId == id);
  }

  @override
  Future<MemoryLink> addLink(MemoryLink link) async {
    final saved = MemoryLink(id: link.id.isEmpty ? newId() : link.id, childId: link.childId, fromId: link.fromId, toId: link.toId, label: link.label);
    _links.add(saved);
    return saved;
  }

  @override
  Future<void> deleteLink(String id) async => _links.removeWhere((l) => l.id == id);

  @override
  Future<AiInsight> analyze(String text) => Future.error(StateError('AI is not connected in demo mode. Configure the backend and Gemini key.'));

  @override
  Future<String> transcribe(Uint8List wav) => Future.error(StateError('Speech model not configured. Connect an STT adapter in the backend.'));
}

/// Backend-controlled app API. The Dart client never holds Atlas or Gemini credentials.
/// DEV_API_TOKEN is for a private prototype only, not public production authentication.
class RemoteRepository implements MemoryRepository {
  RemoteRepository({required this.baseUrl, required this.devToken});
  final String baseUrl;
  final String devToken;
  @override
  bool get isDemo => false;

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');
  Map<String, String> get _headers => {'Authorization': 'Bearer $devToken', 'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> _request(String method, String path, [Map<String, dynamic>? payload]) async {
    final uri = _uri(path);
    late http.Response response;
    switch (method) {
      case 'GET': response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15)); break;
      case 'POST': response = await http.post(uri, headers: _headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 20)); break;
      case 'DELETE': response = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 15)); break;
      default: throw ArgumentError('Unsupported method');
    }
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) throw StateError(decoded['detail']?.toString() ?? 'Server error ${response.statusCode}');
    return decoded;
  }

  @override
  Future<AppSnapshot> load() async => AppSnapshot.fromJson(await _request('GET', '/api/snapshot'));

  @override
  Future<ChildProfile> addChild(String name) async => ChildProfile.fromJson(await _request('POST', '/api/children', {'name': name}));

  @override
  Future<void> deleteChild(String id) async { await _request('DELETE', '/api/children/${Uri.encodeComponent(id)}'); }

  @override
  Future<JournalEntry> saveEntry(JournalEntry entry) async =>
      JournalEntry.fromJson(await _request('POST', '/api/entries', entry.toJson()));

  @override
  Future<void> deleteEntry(String id) async { await _request('DELETE', '/api/entries/${Uri.encodeComponent(id)}'); }

  @override
  Future<MemoryLink> addLink(MemoryLink link) async => MemoryLink.fromJson(await _request('POST', '/api/links', link.toJson()));

  @override
  Future<void> deleteLink(String id) async { await _request('DELETE', '/api/links/${Uri.encodeComponent(id)}'); }

  @override
  Future<AiInsight> analyze(String text) async => AiInsight.fromJson(await _request('POST', '/api/analyze', {'text': text}));

  @override
  Future<String> transcribe(Uint8List wav) async {
    final request = http.MultipartRequest('POST', _uri('/api/transcribe'))
      ..headers['Authorization'] = 'Bearer $devToken'
      ..files.add(http.MultipartFile.fromBytes('file', wav, filename: 'daily-memory.wav'));
    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) throw StateError(data['detail']?.toString() ?? 'Transcription failed');
    return (data['transcript'] as String?) ?? '';
  }
}
