import 'package:flutter/material.dart';

/// A tappable "add more detail" suggestion for the journal editor. Tapping it
/// appends [starter] to the note so the writer can finish the sentence.
class WritingPrompt {
  const WritingPrompt({required this.id, required this.label, required this.starter, required this.icon,
      this.source = PromptSource.local});
  final String id;
  final String label;
  final String starter;
  final IconData icon;
  final PromptSource source;

  bool get fromAi => source != PromptSource.local;

  /// Parses one item from `/api/prompts`, rejecting anything empty or oversized.
  static WritingPrompt? fromJson(Map<String, dynamic> json) {
    String clean(Object? v, int max) {
      final text = (v as String? ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
      return text.length > max ? text.substring(0, max) : text;
    }
    final label = clean(json['label'], 40);
    var starter = clean(json['starter'], 80);
    if (label.isEmpty || starter.isEmpty) return null;
    if (!starter.endsWith(' ')) starter = '$starter ';
    return WritingPrompt(id: 'ai:${label.toLowerCase()}', label: label, starter: starter,
        icon: Icons.auto_awesome, source: PromptSource.gemini);
  }
}

enum PromptSource { local, gemini, demo }

/// Offline stand-in for Gemini in demo mode: picks a word from the note so the
/// samples feel specific, and marks them as demo so nobody mistakes them for AI.
List<WritingPrompt> demoAiPrompts(String text, {required bool kids}) {
  const stop = {'today', 'with', 'were', 'went', 'that', 'this', 'there', 'then', 'they', 'have', 'about', 'really',
    'very', 'some', 'what', 'when', 'from', 'after', 'because', 'played', 'made', 'favorite'};
  final words = RegExp(r"[A-Za-z]+").allMatches(text).map((m) => m.group(0)!.toLowerCase())
      .where((w) => w.length >= 4 && !stop.contains(w)).toList();
  final topic = words.isEmpty ? null : words.reduce((a, b) => b.length >= a.length ? b : a);
  WritingPrompt make(String label, String starter) => WritingPrompt(id: 'ai:${label.toLowerCase()}', label: label,
      starter: starter, icon: Icons.auto_awesome, source: PromptSource.demo);
  if (kids) {
    return [
      if (topic != null) make('Tell more about the $topic', 'The $topic was '),
      make('Who helped you?', 'Someone who helped me was '),
      make('What surprised you?', 'I was surprised when '),
    ];
  }
  return [
    if (topic != null) make('More on the $topic', 'About the $topic: '),
    make('A challenge', 'One challenge was '),
    make('The outcome', 'The result was '),
  ];
}

/// Minimum words before suggestions appear, so they follow a starter sentence
/// instead of crowding an empty box.
const promptMinWords = 4;

/// Picks up to [max] prompts for details the note doesn't mention yet.
///
/// Runs locally with simple keyword checks: no network, no AI, and nothing is
/// inferred about the writer. It only notices which kinds of detail are absent.
List<WritingPrompt> suggestPrompts(String text, {required bool kids, Set<String> used = const {}, int max = 4}) {
  final words = RegExp(r"[A-Za-z']+").allMatches(text).map((m) => m.group(0)!.toLowerCase()).toList();
  if (words.length < promptMinWords) return const [];
  final present = words.toSet();
  bool mentions(Iterable<String> keys) => keys.any(present.contains);

  final candidates = <(WritingPrompt, bool)>[
    for (final rule in kids ? _kidsRules : _adultRules) (rule.prompt, !mentions(rule.keywords)),
  ];
  // Prompts for missing details first, then the always-useful ones.
  final missing = candidates.where((c) => c.$2 && !used.contains(c.$1.id)).map((c) => c.$1);
  final always = (kids ? _kidsAlways : _adultAlways).where((p) => !used.contains(p.id));
  return [...missing, ...always].take(max).toList();
}

/// Adds [starter] to [text] as a new sentence, tidying punctuation and spacing.
String appendStarter(String text, String starter) {
  final trimmed = text.trimRight();
  if (trimmed.isEmpty) return starter;
  final ends = RegExp(r'[.!?…]$').hasMatch(trimmed);
  return '$trimmed${ends ? '' : '.'} $starter';
}

class _Rule {
  const _Rule(this.prompt, this.keywords);
  final WritingPrompt prompt;
  final List<String> keywords;
}

const _people = ['with', 'mom', 'mum', 'dad', 'mommy', 'daddy', 'grandma', 'grandpa', 'nana', 'papa', 'brother', 'sister',
  'friend', 'friends', 'teacher', 'aunt', 'uncle', 'cousin', 'family', 'we', 'us', 'baby', 'dog', 'cat', 'team', 'coworker',
  'colleague', 'partner', 'manager', 'kids', 'son', 'daughter', 'wife', 'husband', 'together'];
const _places = ['at', 'park', 'school', 'home', 'house', 'outside', 'beach', 'store', 'shop', 'zoo', 'library', 'garden',
  'yard', 'room', 'kitchen', 'car', 'office', 'work', 'gym', 'pool', 'playground', 'museum', 'restaurant', 'there'];
const _feelings = ['happy', 'sad', 'fun', 'funny', 'felt', 'feel', 'feeling', 'love', 'loved', 'excited', 'scared', 'proud',
  'silly', 'angry', 'mad', 'tired', 'glad', 'great', 'awesome', 'cool', 'nervous', 'calm', 'frustrated', 'relieved', 'enjoyed'];
const _senses = ['saw', 'see', 'heard', 'hear', 'smell', 'smelled', 'tasted', 'taste', 'looked', 'sounded', 'colour', 'color',
  'red', 'blue', 'green', 'yellow', 'big', 'little', 'loud', 'soft'];
const _favorite = ['favorite', 'favourite', 'best', 'liked', 'like'];
const _when = ['morning', 'afternoon', 'evening', 'night', 'today', 'yesterday', 'after', 'before', 'lunch', 'breakfast',
  'dinner', 'weekend', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday', 'when'];
const _reasons = ['because', 'since', 'so', 'why', 'reason'];
const _next = ['next', 'plan', 'will', 'tomorrow', 'todo', 'follow', 'goal', 'going'];

const _kidsRules = [
  _Rule(WritingPrompt(id: 'who', label: 'Who was there?', starter: 'I was with ', icon: Icons.people_alt_outlined), _people),
  _Rule(WritingPrompt(id: 'where', label: 'Where were you?', starter: 'We were at ', icon: Icons.place_outlined), _places),
  _Rule(WritingPrompt(id: 'feel', label: 'How did it feel?', starter: 'It made me feel ', icon: Icons.emoji_emotions_outlined), _feelings),
  _Rule(WritingPrompt(id: 'senses', label: 'What did you see or hear?', starter: 'I saw ', icon: Icons.visibility_outlined), _senses),
  _Rule(WritingPrompt(id: 'favorite', label: 'Best part?', starter: 'My favorite part was ', icon: Icons.star_outline_rounded), _favorite),
];
const _kidsAlways = [
  WritingPrompt(id: 'next', label: 'What happened next?', starter: 'Then ', icon: Icons.arrow_forward_rounded),
  WritingPrompt(id: 'funny', label: 'Anything funny?', starter: 'The funniest thing was ', icon: Icons.sentiment_very_satisfied_outlined),
  WritingPrompt(id: 'again', label: 'Do it again?', starter: 'Next time I want to ', icon: Icons.replay_rounded),
];

const _adultRules = [
  _Rule(WritingPrompt(id: 'when', label: 'When', starter: 'This was ', icon: Icons.schedule_outlined), _when),
  _Rule(WritingPrompt(id: 'who', label: 'Who was involved', starter: 'Involved: ', icon: Icons.people_alt_outlined), _people),
  _Rule(WritingPrompt(id: 'why', label: 'Why it matters', starter: 'This matters because ', icon: Icons.lightbulb_outline), _reasons),
  _Rule(WritingPrompt(id: 'feel', label: 'How it went', starter: 'Overall it felt ', icon: Icons.insights_outlined), _feelings),
  _Rule(WritingPrompt(id: 'next', label: 'Next step', starter: 'Next step: ', icon: Icons.checklist_rounded), _next),
];
const _adultAlways = [
  WritingPrompt(id: 'learned', label: 'What I learned', starter: 'One thing I learned: ', icon: Icons.school_outlined),
  WritingPrompt(id: 'differently', label: 'Do differently', starter: 'Next time I would ', icon: Icons.tune_rounded),
  WritingPrompt(id: 'win', label: 'A small win', starter: 'A small win: ', icon: Icons.emoji_events_outlined),
];
