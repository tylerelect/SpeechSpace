/// A journal owner. `kind` is `kids` or `adult`; both share the same data model.
/// Wire format: `{id, name, kind, themeId}`. Entries and links still refer to it
/// through their legacy `childId` key.
class SpaceProfile {
  final String id;
  final String name;
  final String kind;
  final String themeId;

  static const kids = 'kids';
  static const adult = 'adult';

  const SpaceProfile({required this.id, required this.name, this.kind = kids, String? themeId})
      : themeId = themeId ?? (kind == adult ? 'indigo' : 'space');

  bool get isKids => kind != adult;

  SpaceProfile copyWith({String? name, String? themeId}) =>
      SpaceProfile(id: id, name: name ?? this.name, kind: kind, themeId: themeId ?? this.themeId);

  factory SpaceProfile.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] == adult ? adult : kids;
    final theme = json['themeId'] as String?;
    return SpaceProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: kind,
      themeId: theme == null || theme.isEmpty ? null : theme,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'kind': kind, 'themeId': themeId};
}

class JournalEntry {
  final String id;
  final String childId;
  final DateTime date;
  final String title;
  final String body;
  final String favorite;
  final String highlight;
  final bool isMilestone;
  final List<String> tags;

  const JournalEntry({
    required this.id,
    required this.childId,
    required this.date,
    required this.title,
    required this.body,
    this.favorite = '',
    this.highlight = '',
    this.isMilestone = false,
    this.tags = const [],
  });

  JournalEntry copyWith({String? id, String? title, String? body, String? favorite, String? highlight, bool? isMilestone, List<String>? tags, DateTime? date}) =>
      JournalEntry(
        id: id ?? this.id,
        childId: childId,
        date: date ?? this.date,
        title: title ?? this.title,
        body: body ?? this.body,
        favorite: favorite ?? this.favorite,
        highlight: highlight ?? this.highlight,
        isMilestone: isMilestone ?? this.isMilestone,
        tags: tags ?? this.tags,
      );

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        childId: json['childId'] as String,
        date: DateTime.parse(json['date'] as String).toLocal(),
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        favorite: (json['favorite'] as String?) ?? '',
        highlight: (json['highlight'] as String?) ?? '',
        isMilestone: (json['isMilestone'] as bool?) ?? false,
        tags: ((json['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'title': title,
        'body': body,
        'favorite': favorite,
        'highlight': highlight,
        'isMilestone': isMilestone,
        'tags': tags,
      };
}

class MemoryLink {
  final String id;
  final String childId;
  final String fromId;
  final String toId;
  final String label;

  const MemoryLink({required this.id, required this.childId, required this.fromId, required this.toId, this.label = 'related'});

  factory MemoryLink.fromJson(Map<String, dynamic> json) => MemoryLink(
        id: json['id'] as String,
        childId: json['childId'] as String,
        fromId: json['fromId'] as String,
        toId: json['toId'] as String,
        label: (json['label'] as String?) ?? 'related',
      );

  Map<String, dynamic> toJson() => {'id': id, 'childId': childId, 'fromId': fromId, 'toId': toId, 'label': label};
}

class AiInsight {
  final String highlight;
  final String favorite;
  final List<String> tags;

  const AiInsight({required this.highlight, required this.favorite, required this.tags});

  factory AiInsight.fromJson(Map<String, dynamic> json) => AiInsight(
        highlight: (json['highlight'] as String?) ?? '',
        favorite: (json['favorite'] as String?) ?? '',
        tags: ((json['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

class AppSnapshot {
  final List<SpaceProfile> children;
  final List<JournalEntry> entries;
  final List<MemoryLink> links;

  const AppSnapshot({required this.children, required this.entries, required this.links});

  factory AppSnapshot.fromJson(Map<String, dynamic> json) => AppSnapshot(
        children: ((json['children'] as List?) ?? []).map((e) => SpaceProfile.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        entries: ((json['entries'] as List?) ?? []).map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        links: ((json['links'] as List?) ?? []).map((e) => MemoryLink.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

/// A Gemini-suggested star on the star/mind map: a new idea or recommendation
/// derived from one or more related journal entries. Suggestions are
/// session-only; nothing is saved unless the user turns one into a real entry.
class StarIdea {
  final String id;
  final String profileId;
  final String title;
  final String detail;
  /// `idea` or `recommendation`.
  final String type;
  final List<String> sourceIds;
  /// True for the offline demo samples, which do not come from Gemini.
  final bool demo;

  static const idea = 'idea';
  static const recommendation = 'recommendation';

  const StarIdea({
    required this.id,
    required this.profileId,
    required this.title,
    required this.detail,
    required this.type,
    required this.sourceIds,
    this.demo = false,
  });

  bool get isRecommendation => type == recommendation;

  /// Parses one item of the `/api/expand` response. Source IDs not in
  /// [allowedSourceIds] are dropped so a suggestion can never point at another
  /// profile's entries.
  static StarIdea? fromJson(Map<String, dynamic> json,
      {required String id, required String profileId, required Set<String> allowedSourceIds}) {
    final title = (json['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return null;
    final sources = ((json['sourceIds'] as List?) ?? [])
        .map((e) => e.toString()).where(allowedSourceIds.contains).toSet().toList();
    return StarIdea(
      id: id,
      profileId: profileId,
      title: title.length > 80 ? title.substring(0, 80) : title,
      detail: ((json['detail'] as String?) ?? '').trim(),
      type: json['type'] == recommendation ? recommendation : idea,
      sourceIds: sources.isEmpty ? allowedSourceIds.toList() : sources,
    );
  }
}
