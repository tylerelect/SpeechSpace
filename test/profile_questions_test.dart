import 'package:flutter_test/flutter_test.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/services/profile_questions.dart';

void main() {
  // 2026-11-16 is a Monday; 2026-11-14 a Saturday.
  final monday = DateTime(2026, 11, 16);
  final saturday = DateTime(2026, 11, 14);
  SpaceProfile kid(ProfileDetails d) => SpaceProfile(id: 'k', name: 'Sky', details: d);
  List<String> labels(SpaceProfile p, DateTime day, {int max = 8}) =>
      profilePrompts(p, day, max: max).map((q) => q.label).toList();

  const full = ProfileDetails(age: 8, school: 'Maple School', favoriteColor: 'Blue', interests: ['soccer', 'dinosaurs']);

  test('school-day questions use the school, friends, interests and color', () {
    final l = labels(kid(full), monday);
    expect(l.first, 'How was Maple School today?');
    expect(l, containsAll(['Which friends did you see?', 'Did you see anything blue?', 'What did you learn today?']));
    expect(l.where((q) => q.startsWith('Anything about ')), hasLength(2));
  });

  test('a personal question makes the first four', () {
    final l = labels(kid(full), monday, max: 4);
    expect(l, hasLength(4));
    expect(l.any((q) => q.startsWith('Anything about ') || q.contains('blue')), isTrue);
  });

  test('weekends skip school questions', () {
    final l = labels(kid(full), saturday);
    expect(l.first, 'What did you do this weekend?');
    expect(l.any((q) => q.contains('school') || q.contains('Maple') || q.contains('learn')), isFalse);
  });

  test('age changes the wording', () {
    expect(labels(kid(const ProfileDetails(age: 5)), monday), contains('Who did you play with?'));
    expect(labels(kid(const ProfileDetails(age: 11)), monday), contains('Anything tricky today?'));
    expect(labels(kid(const ProfileDetails(age: 8)), monday), isNot(contains('Anything tricky today?')));
  });

  test('a long school name falls back to generic wording', () {
    final l = labels(kid(const ProfileDetails(school: 'Riverside Elementary and Middle')), monday);
    expect(l.first, 'How was school today?');
  });

  test('used questions are dropped and starters stay unfinished', () {
    final all = profilePrompts(kid(full), monday, max: 8);
    expect(all.every((q) => q.id.startsWith('me:') && q.starter.endsWith(' ')), isTrue);
    final rest = profilePrompts(kid(full), monday, used: {'me:school'}, max: 8);
    expect(rest.any((q) => q.id == 'me:school'), isFalse);
  });

  test('daily question rotates by day and falls back with no details', () {
    expect(dailyQuestion(kid(ProfileDetails.empty), monday, fallback: 'F'), 'F');
    expect(dailyQuestion(null, monday, fallback: 'F'), 'F');
    final options = profilePrompts(kid(full), monday, max: 8).map((q) => q.label);
    expect(options, contains(dailyQuestion(kid(full), monday, fallback: 'F')));
    final week = {for (var i = 0; i < 5; i++) dailyQuestion(kid(full), monday.add(Duration(days: i)), fallback: 'F')};
    expect(week.length, greaterThan(1));
  });

  test('every interest can be the Today question over a few weeks', () {
    const many = ProfileDetails(interests: ['soccer', 'dinosaurs', 'drawing']);
    final seen = {for (var i = 0; i < 42; i++) dailyQuestion(kid(many), monday.add(Duration(days: i)), fallback: 'F')};
    for (final interest in many.interests) {
      expect(seen, contains('Anything about $interest?'));
    }
  });

  test('the editor leads with the Today question, on any day', () {
    for (var i = 0; i < 14; i++) {
      final day = monday.add(Duration(days: i));
      expect(startingPrompts(kid(full), day).first.label, dailyQuestion(kid(full), day, fallback: 'F'));
      expect(startingPrompts(kid(full), day), hasLength(3));
    }
  });

  test('text is tidied like the backend: spaces collapsed, clipped by code points, de-duplicated after clipping', () {
    expect(ProfileDetails.tidy('  Maple   School ', 60), 'Maple School');
    expect(ProfileDetails.tidy('🇺🇸' * 31, 60).runes.length, 60);
    expect(ProfileDetails.parseInterests('${'a' * 30}x, ${'a' * 30}y'), ['a' * 30]);
    final clipped = kid(ProfileDetails(interests: ['${'b' * 30}1', '${'b' * 30}2']));
    expect(profilePrompts(clipped, monday, max: 9).map((q) => q.id).toSet(), hasLength(profilePrompts(clipped, monday, max: 9).length));
  });

  test('interests parse from a comma list, de-duplicated and capped', () {
    expect(ProfileDetails.parseInterests(' soccer, Soccer ,, dinosaurs,a,b,c,d'),
        ['soccer', 'dinosaurs', 'a', 'b', 'c']);
  });

  test('details round-trip through JSON and old profiles have none', () {
    final p = kid(full);
    expect(SpaceProfile.fromJson(p.toJson()).details, full);
    expect(SpaceProfile.fromJson({'id': 'x', 'name': 'Old'}).details.isEmpty, isTrue);
  });
}
