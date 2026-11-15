import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/models.dart';

abstract class MemoryRepository {
  bool get isDemo;
  Future<AppSnapshot> load();
  Future<SpaceProfile> addProfile(String name, String kind);
  Future<SpaceProfile> updateProfile(SpaceProfile profile);
  Future<void> deleteChild(String id); // deletes any profile (Kids or Adult)
  Future<JournalEntry> saveEntry(JournalEntry entry);
  Future<void> deleteEntry(String id);
  Future<MemoryLink> addLink(MemoryLink link);
  Future<void> deleteLink(String id);
  Future<AiInsight> analyze(String text, {required String kind});
  /// Asks Gemini for new ideas/recommendations based on related entries.
  Future<List<StarIdea>> expand(String profileId, List<String> entryIds, {required String kind});
  Future<String> transcribe(Uint8List wav);
}

String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
int _nextId = 0;

/// In-memory synthetic sample data (one Kids and one Adult profile).
/// Nothing is persisted: all changes are lost on restart.
class DemoRepository implements MemoryRepository {
  @override
  bool get isDemo => true;
  final List<SpaceProfile> _children = [
    const SpaceProfile(id: 'demo-alex', name: 'Alex', kind: SpaceProfile.kids),
    const SpaceProfile(id: 'demo-jordan', name: 'Jordan', kind: SpaceProfile.adult),
  ];
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
      JournalEntry(id: 'demo-a1', childId: 'demo-jordan', date: today, title: 'Planning the week',
          body: 'Blocked out time for the garden project and booked the dentist for Thursday.',
          highlight: 'Weekly plan set.', tags: const ['Planning']),
      JournalEntry(id: 'demo-a2', childId: 'demo-jordan', date: today.subtract(const Duration(days: 2)), title: 'Started a running routine',
          body: 'First 3k run in a while. Felt slow but finished it.', isMilestone: true,
          highlight: 'First run of the new routine.', tags: const ['Health', 'Goals']),
    ]);
    _links.addAll(const [
      MemoryLink(id: 'demo-link', childId: 'demo-alex', fromId: 'demo-1', toId: 'demo-3', label: 'Family activities'),
      MemoryLink(id: 'demo-link-a', childId: 'demo-jordan', fromId: 'demo-a1', toId: 'demo-a2', label: 'Goals'),
    ]);
  }

  @override
  Future<AppSnapshot> load() async => AppSnapshot(children: List.of(_children), entries: List.of(_entries), links: List.of(_links));

  @override
  Future<SpaceProfile> addProfile(String name, String kind) async {
    final profile = SpaceProfile(id: newId(), name: name, kind: kind == SpaceProfile.adult ? SpaceProfile.adult : SpaceProfile.kids);
    _children.add(profile);
    return profile;
  }

  @override
  Future<SpaceProfile> updateProfile(SpaceProfile profile) async {
    final i = _children.indexWhere((c) => c.id == profile.id);
    if (i < 0) throw StateError('Profile not found.');
    _children[i] = profile;
    return profile;
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
  Future<AiInsight> analyze(String text, {required String kind}) => Future.error(StateError('AI is not connected in demo mode. Configure the backend and Gemini key.'));

  /// Offline stand-in for Gemini: simple template suggestions built from the
  /// selected entries, clearly flagged as demo samples.
  @override
  Future<List<StarIdea>> expand(String profileId, List<String> entryIds, {required String kind}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final picked = _entries.where((e) => e.childId == profileId && entryIds.contains(e.id)).toList();
    if (picked.isEmpty) throw StateError('Choose at least one entry.');
    final first = picked.first;
    final second = picked.length > 1 ? picked[1] : null;
    final tag = picked.expand((e) => e.tags).firstOrNull ?? (kind == SpaceProfile.adult ? 'this' : 'fun');
    final ids = picked.map((e) => e.id).toList();
    StarIdea make(String title, String detail, String type, List<String> sources) =>
        StarIdea(id: newId(), profileId: profileId, title: title, detail: detail, type: type, sourceIds: sources, demo: true);
    if (kind == SpaceProfile.adult) {
      return [
        make('Follow up on "${first.title}"', 'Note what happened next and anything you would do differently.', StarIdea.idea, [first.id]),
        make('Set a next step for ${tag.toLowerCase()}', 'Pick one small, concrete action for the coming week.', StarIdea.recommendation, ids),
        if (second != null) make('What links these entries?', 'Compare "${first.title}" and "${second.title}" and write down the common thread.', StarIdea.idea, [first.id, second.id]),
      ];
    }
    return [
      make('Another ${tag.toLowerCase()} adventure', 'You told a story about "${first.title}". What else could you try next time?', StarIdea.idea, [first.id]),
      make('Draw your favorite part', 'Make a picture of the best moment, then tell a story about your drawing.', StarIdea.recommendation, ids),
      if (second != null) make('Mix two stories together', 'What if "${first.title}" and "${second.title}" happened on the same day?', StarIdea.idea, [first.id, second.id]),
    ];
  }

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
      case 'PATCH': response = await http.patch(uri, headers: _headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 15)); break;
      case 'DELETE': response = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 15)); break;
      default: throw ArgumentError('Unsupported method');
    }
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 404 && path == '/api/expand' && decoded['detail'] == 'Not Found') {
      throw StateError('Star ideas need the new /api/expand backend endpoint, which is not deployed yet.');
    }
    if (response.statusCode >= 400) throw StateError(decoded['detail']?.toString() ?? 'Server error ${response.statusCode}');
    return decoded;
  }

  @override
  Future<AppSnapshot> load() async => AppSnapshot.fromJson(await _request('GET', '/api/snapshot'));

  @override
  Future<SpaceProfile> addProfile(String name, String kind) async =>
      SpaceProfile.fromJson(await _request('POST', '/api/profiles', {'name': name, 'kind': kind}));

  @override
  Future<SpaceProfile> updateProfile(SpaceProfile profile) async => SpaceProfile.fromJson(
      await _request('PATCH', '/api/profiles/${Uri.encodeComponent(profile.id)}', {'themeId': profile.themeId}));

  @override
  Future<void> deleteChild(String id) async { await _request('DELETE', '/api/profiles/${Uri.encodeComponent(id)}'); }

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
  Future<AiInsight> analyze(String text, {required String kind}) async =>
      AiInsight.fromJson(await _request('POST', '/api/analyze', {'text': text, 'kind': kind}));

  /// PROPOSED ENDPOINT — not yet in the agreed contract; the backend developer
  /// needs to implement it (see the PR description).
  ///
  /// `POST /api/expand`
  /// Request:  `{ "profileId": "...", "entryIds": ["..."], "kind": "kids" | "adult" }`
  ///           (1–6 IDs; the server loads the entries itself, scoped to the
  ///           authenticated owner and profile, rather than trusting client text)
  /// Response: `{ "ideas": [ { "title": "...", "detail": "...",
  ///             "type": "idea" | "recommendation", "sourceIds": ["..."] } ] }`
  ///           (2–4 ideas; sourceIds must be a subset of entryIds)
  /// Errors:   503 when GEMINI_API_KEY is unset, 502 when Gemini fails,
  ///           404 when an entry is not owned by this profile.
  @override
  Future<List<StarIdea>> expand(String profileId, List<String> entryIds, {required String kind}) async {
    final data = await _request('POST', '/api/expand', {'profileId': profileId, 'entryIds': entryIds, 'kind': kind});
    final allowed = entryIds.toSet();
    return ((data['ideas'] as List?) ?? [])
        .map((e) => StarIdea.fromJson(Map<String, dynamic>.from(e as Map), id: newId(), profileId: profileId, allowedSourceIds: allowed))
        .whereType<StarIdea>()
        .take(6)
        .toList();
  }

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
