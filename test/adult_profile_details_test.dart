import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/services/profile_questions.dart';
import 'package:speechspace/widgets/profile_details_form.dart';

void main() {
  // 2026-11-16 is a Monday; 2026-11-14 a Saturday.
  final monday = DateTime(2026, 11, 16);
  final saturday = DateTime(2026, 11, 14);
  SpaceProfile adult(ProfileDetails d) => SpaceProfile(id: 'a', name: 'Jamie', kind: SpaceProfile.adult, details: d);
  List<String> labels(SpaceProfile p, DateTime day, {int max = 8}) =>
      profilePrompts(p, day, max: max).map((q) => q.label).toList();

  const full = ProfileDetails(age: 34, occupation: 'nurse', goals: ['run a 10k', 'learn Spanish'],
      interests: ['cooking', 'cycling']);

  test('weekday questions lead with work, then goals and hobbies', () {
    final prompts = profilePrompts(adult(full), monday, max: 8);
    final l = prompts.map((q) => q.label).toList();
    expect(l.first, 'How did work go today?');
    expect(prompts.first.starter, 'Work today: ');
    expect(l, contains("What's next at work?"));
    expect(l.where((q) => q.startsWith('How is "')), hasLength(2));
    expect(l.where((q) => q.startsWith('Any time for ')), hasLength(2));
    expect(prompts.every((q) => q.id.startsWith('me:')), isTrue);
    // The first four include a goal and a hobby, not just work.
    final top = labels(adult(full), monday, max: 4);
    expect(top.any((q) => q.startsWith('How is "')), isTrue);
    expect(top.any((q) => q.startsWith('Any time for ')), isTrue);
  });

  test('weekends skip work and ask about the weekend and hobbies this week', () {
    final l = labels(adult(full), saturday);
    expect(l.first, 'How was your weekend?');
    expect(l.any((q) => q.contains('work')), isFalse);
    expect(l, containsAll(['What did you do for cooking this week?', 'What did you do for cycling this week?']));
  });

  test('no occupation means no work questions', () {
    final l = labels(adult(const ProfileDetails(goals: ['run a 10k'])), monday);
    expect(l, ['How is "run a 10k" going?']);
  });

  test('an empty adult profile gets no questions and the fallback', () {
    expect(profilePrompts(adult(ProfileDetails.empty), monday), isEmpty);
    expect(profilePrompts(adult(ProfileDetails.empty), saturday), isEmpty);
    expect(dailyQuestion(adult(ProfileDetails.empty), monday, fallback: 'F'), 'F');
    // Age alone gives nothing to ask about on a weekday.
    expect(dailyQuestion(adult(const ProfileDetails(age: 40)), monday, fallback: 'F'), 'F');
  });

  test('adult questions ignore kids-only fields', () {
    final l = labels(adult(const ProfileDetails(school: 'Maple School', favoriteColor: 'Blue')), monday);
    expect(l, isEmpty);
  });

  test('long goals are shortened on a word boundary but kept whole in the starter', () {
    const goal = 'finish the long kitchen renovation project';
    final q = profilePrompts(adult(const ProfileDetails(goals: [goal])), monday).single;
    expect(q.label, 'How is "finish the long kitchen…" going?');
    expect(q.starter, 'On my goal "$goal": ');
  });

  test('used ids are skipped and dailyQuestion rotates through adult questions', () {
    final l = profilePrompts(adult(full), monday, used: {'me:work'}).map((q) => q.id);
    expect(l, isNot(contains('me:work')));
    final all = labels(adult(full), monday);
    final daily = {for (var i = 0; i < 5; i++) dailyQuestion(adult(full), monday.add(Duration(days: i * 7)), fallback: 'F')};
    expect(daily.every(all.contains), isTrue);
  });

  test('kids output is unchanged by the adult fields', () {
    const kids = ProfileDetails(age: 8, school: 'Maple School', interests: ['soccer']);
    const kid = SpaceProfile(id: 'k', name: 'Sky', details: kids);
    const withAdultFields = SpaceProfile(id: 'k', name: 'Sky',
        details: ProfileDetails(age: 8, school: 'Maple School', interests: ['soccer'], occupation: 'x', goals: ['y']));
    expect(labels(withAdultFields, monday), labels(kid, monday));
    expect(labels(kid, monday).first, 'How was Maple School today?');
  });

  group('ProfileDetails', () {
    test('adult fields round-trip and missing keys mean empty', () {
      expect(ProfileDetails.fromJson(full.toJson()), full);
      final old = ProfileDetails.fromJson({'age': 40, 'interests': ['chess']});
      expect(old.occupation, '');
      expect(old.goals, isEmpty);
      expect(ProfileDetails.fromJson(const {}).isEmpty, isTrue);
      expect(const ProfileDetails(occupation: 'nurse').isEmpty, isFalse);
      expect(const ProfileDetails(goals: ['a']) == const ProfileDetails(goals: ['b']), isFalse);
    });

    test('age ranges depend on kind', () {
      expect(ProfileDetails.ageRange(SpaceProfile.kids), (3, 17));
      expect(ProfileDetails.ageRange(SpaceProfile.adult), (18, 100));
    });

    test('parseGoals tidies, de-duplicates and limits', () {
      expect(ProfileDetails.parseGoals(' run a 10k, Run a 10K ,, learn Spanish, sleep more, read'),
          ['run a 10k', 'learn Spanish', 'sleep more']);
      expect(ProfileDetails.parseGoals('x' * 50).single, hasLength(ProfileDetails.maxGoal));
    });
  });

  testWidgets('adult form shows adult fields and emits them', (tester) async {
    ProfileDetails? last;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ProfileDetailsForm(
      kind: SpaceProfile.adult,
      initial: const ProfileDetails(school: 'kept'),
      onChanged: (d) => last = d,
    )))));
    expect(find.byKey(const ValueKey('details-school')), findsNothing);
    expect(find.byKey(const ValueKey('color-Blue')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('details-occupation')), ' nurse ');
    await tester.enterText(find.byKey(const ValueKey('details-goals')), 'run a 10k, learn Spanish');
    await tester.enterText(find.byKey(const ValueKey('details-interests')), 'cooking');
    expect(last, const ProfileDetails(school: 'kept', occupation: 'nurse', goals: ['run a 10k', 'learn Spanish'],
        interests: ['cooking']));
    await tester.tap(find.byKey(const ValueKey('details-age')));
    await tester.pumpAndSettle();
    expect(find.text('17'), findsNothing);
    await tester.tap(find.text('18').last);
    await tester.pumpAndSettle();
    expect(last?.age, 18);
  });
}
