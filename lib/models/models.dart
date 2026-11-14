class ChildProfile {
  final String id;
  final String name;
  final String color;

  const ChildProfile({required this.id, required this.name, this.color = 'lavender'});

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        color: (json['color'] as String?) ?? 'lavender',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
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
  final List<ChildProfile> children;
  final List<JournalEntry> entries;
  final List<MemoryLink> links;

  const AppSnapshot({required this.children, required this.entries, required this.links});

  factory AppSnapshot.fromJson(Map<String, dynamic> json) => AppSnapshot(
        children: ((json['children'] as List?) ?? []).map((e) => ChildProfile.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        entries: ((json['entries'] as List?) ?? []).map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        links: ((json['links'] as List?) ?? []).map((e) => MemoryLink.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}
