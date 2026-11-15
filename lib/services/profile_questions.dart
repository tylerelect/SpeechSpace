import 'package:flutter/material.dart';

import '../models/models.dart';
import 'writing_prompts.dart';

/// Turns a profile's "About me" details into conversation-starter questions:
/// for Kids (age, school, favorite color, interests) things like "How was
/// school today?" or "Which friends did you see?"; for Adults (occupation,
/// goals, hobbies) things like "How did work go today?" or "How is "run a
/// 10k" going?".
///
/// Runs locally: nothing is sent anywhere and nothing is inferred about the
/// writer. Each prompt's [WritingPrompt.starter] begins a sentence the writer
/// finishes in their own words.
///
/// * School questions only appear on weekdays; weekends get weekend questions.
/// * Younger children (under 7) get shorter, simpler wording; older children
///   (10+) also get a "something tricky" question.
/// * Adult profiles get short, practical wording (see [_adultPrompts]); work
///   questions only appear on weekdays and only when an occupation is set.
List<WritingPrompt> profilePrompts(SpaceProfile? profile, DateTime day, {Set<String> used = const {}, int max = 4}) {
  if (profile == null) return const [];
  final out = profile.isKids ? _kidsPrompts(profile.details, day) : _adultPrompts(profile.details, day);
  final seen = <String>{}; // e.g. a goal and a hobby can't clash, but two clipped interests could
  return out.where((q) => !used.contains(q.id) && seen.add(q.id)).take(max).toList();
}

/// The entry editor's "Need an idea?" chips for an entry on [day]: today's
/// [dailyQuestion] first (so the question on the Today screen is always one
/// tap away), then the other [profilePrompts].
List<WritingPrompt> startingPrompts(SpaceProfile? profile, DateTime day, {Set<String> used = const {}, int max = 3}) {
  final all = profilePrompts(profile, day, used: used, max: 99);
  final lead = _dailyPick(profile, day);
  final i = lead == null ? -1 : all.indexWhere((q) => q.id == lead.id);
  if (i > 0) all.insert(0, all.removeAt(i));
  return all.take(max).toList();
}

WritingPrompt _p(String id, String label, String starter, IconData icon) =>
    WritingPrompt(id: 'me:$id', label: label, starter: starter, icon: icon);

List<WritingPrompt> _kidsPrompts(ProfileDetails d, DateTime day) {
  const p = _p;
  final age = d.age;
  final young = age != null && age < 7;
  final older = age != null && age >= 10;
  final schoolDay = day.weekday <= DateTime.friday;
  final school = d.school;

  final interests = [
    for (final interest in _rotate(d.interests, day))
      p('interest:${interest.toLowerCase()}', 'Anything about $interest?', 'Something about $interest: ',
          Icons.favorite_outline),
  ];
  final color = d.favoriteColor.toLowerCase();
  // Order matters (callers show the first few): the day's main question, then
  // friends, then the child's own interests and color before generic extras.
  // With no details at all, only the generic school/friends questions remain.
  return [
    if (schoolDay)
      p('school', school.isNotEmpty && school.length <= 18 ? 'How was $school today?' : 'How was school today?',
          young ? 'At school I ' : 'My day at school was ', Icons.school_outlined)
    else
      p('weekend', 'What did you do this weekend?', 'This weekend I ', Icons.weekend_outlined),
    if (schoolDay)
      p('friends', young ? 'Who did you play with?' : 'Which friends did you see?',
          young ? 'I played with ' : 'Today I saw my friend ', Icons.people_alt_outlined)
    else
      p('friends', young ? 'Who did you play with?' : 'Did you see any friends?',
          young ? 'I played with ' : 'I spent time with ', Icons.people_alt_outlined),
    ...interests.take(1),
    if (color.isNotEmpty) p('color', 'Did you see anything $color?', 'I saw something $color: ', Icons.palette_outlined),
    if (schoolDay) p('learned', young ? 'What did you learn?' : 'What did you learn today?', 'Today I learned ',
        Icons.lightbulb_outline),
    if (schoolDay && older) p('tricky', 'Anything tricky today?', 'Something tricky was ', Icons.extension_outlined),
    ...interests.skip(1),
  ];
}

/// Adult questions: concise and practical, matching the neutral adult prompts.
/// An Adult who filled in nothing gets nothing (their prompts stay neutral).
/// Otherwise only filled-in details produce questions, plus "How was your
/// weekend?" on weekends. Age is not used locally (it only gives Gemini context).
List<WritingPrompt> _adultPrompts(ProfileDetails d, DateTime day) {
  if (d.isEmpty) return const [];
  const p = _p;
  final weekday = day.weekday <= DateTime.friday;
  final working = weekday && d.occupation.isNotEmpty;
  final goals = [
    for (final goal in _rotate(d.goals, day))
      p('goal:${goal.toLowerCase()}', 'How is "${_shorten(goal, 24)}" going?',
          'On my goal "$goal": ', Icons.flag_outlined),
  ];
  final hobbies = [
    for (final hobby in _rotate(d.interests, day))
      p('hobby:${hobby.toLowerCase()}',
          weekday ? 'Any time for $hobby today?' : 'What did you do for $hobby this week?',
          'For $hobby, I ', Icons.interests_outlined),
  ];
  // The day's main question first (work or weekend), then goals and hobbies.
  return [
    if (working) p('work', 'How did work go today?', 'Work today: ', Icons.work_outline)
    else if (!weekday) p('weekend', 'How was your weekend?', 'This weekend I ', Icons.weekend_outlined),
    ...goals.take(1),
    ...hobbies.take(1),
    if (working) p('work-next', "What's next at work?", 'Next at work: ', Icons.checklist_rounded),
    ...goals.skip(1),
    ...hobbies.skip(1),
  ];
}

/// The Today screen's main question: one of the [profilePrompts] questions,
/// rotating once a day so it doesn't get stale. Works for both kinds. Falls
/// back to [fallback] when the profile has no details yet (or, for an Adult,
/// when none of the filled-in details produce a question today).
String dailyQuestion(SpaceProfile? profile, DateTime day, {required String fallback}) =>
    _dailyPick(profile, day)?.label ?? fallback;

WritingPrompt? _dailyPick(SpaceProfile? profile, DateTime day) {
  if (profile == null || profile.details.isEmpty) return null;
  final options = profilePrompts(profile, day, max: 8);
  return options.isEmpty ? null : options[_dayIndex(day) % options.length];
}

/// Starts the interest/goal list at a different item each *week*. This is
/// deliberately a different cycle from [dailyQuestion]'s daily pick: if both
/// moved daily they'd stay in lockstep and some interests would never be the
/// Today question.
List<String> _rotate(List<String> items, DateTime day) {
  if (items.length < 2) return items;
  final start = (_dayIndex(day) ~/ 7) % items.length;
  return [...items.skip(start), ...items.take(start)];
}

/// Clips [text] to about [max] characters on a word boundary, adding "…", so
/// long goals still get distinct chip labels.
String _shorten(String text, int max) {
  if (text.length <= max) return text;
  final cut = text.substring(0, max);
  final space = cut.lastIndexOf(' ');
  return '${(space > max ~/ 2 ? cut.substring(0, space) : cut).trimRight()}…';
}

int _dayIndex(DateTime day) => DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
