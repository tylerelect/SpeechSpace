/// All wording that differs between Kids and Adult mode lives here, so screens
/// stay shared and just ask for `ModeCopy.of(profile)`.
class ModeCopy {
  const ModeCopy._({
    required this.isKids,
    required this.headline,
    required this.subtitle,
    required this.questionLabel,
    required this.question,
    required this.questionHelp,
    required this.addToday,
    required this.todaySection,
    required this.todayEmpty,
    required this.recentSection,
    required this.navToday,
    required this.navCalendar,
    required this.navMemories,
    required this.navMindMap,
    required this.navSettings,
    required this.navActivity,
    required this.entryNoun,
    required this.entryNounPlural,
    required this.editorNewTitle,
    required this.editorEditTitle,
    required this.titleLabel,
    required this.titleHint,
    required this.bodyLabel,
    required this.bodyHint,
    required this.recordPrompt,
    required this.saveLabel,
  });

  final bool isKids;
  final String headline;
  final String Function(String name) subtitle;
  final String questionLabel;
  final String question;
  final String questionHelp;
  final String addToday;
  final String todaySection;
  final String todayEmpty;
  final String recentSection;
  final String navToday, navCalendar, navMemories, navMindMap, navSettings, navActivity;
  final String entryNoun, entryNounPlural;
  final String editorNewTitle, editorEditTitle;
  final String titleLabel, titleHint, bodyLabel, bodyHint;
  final String recordPrompt;
  final String saveLabel;

  static ModeCopy forKind(String kind) => kind == 'adult' ? adult : kids;

  static final kids = ModeCopy._(
    isKids: true,
    headline: 'Ready for liftoff!',
    subtitle: (name) => 'Hi $name! Tell us about your day.',
    questionLabel: 'TODAY\'S MISSION',
    question: 'What was the best part of your day?',
    questionHelp: 'Press the big button and tell your story out loud.',
    addToday: 'Tell my story',
    todaySection: 'My stories today',
    todayEmpty: 'No stories yet today. Tap "Tell my story" to start!',
    recentSection: 'Stories from before',
    navToday: 'Today',
    navCalendar: 'My days',
    navMemories: 'Stories',
    navMindMap: 'Star map',
    navSettings: 'Grown-ups',
    navActivity: 'Activity',
    entryNoun: 'story',
    entryNounPlural: 'Stories',
    editorNewTitle: 'New story',
    editorEditTitle: 'My story',
    titleLabel: 'Name your story',
    titleHint: 'The day I saw a rainbow',
    bodyLabel: 'What happened?',
    bodyHint: 'Today I…',
    recordPrompt: 'Tell your story out loud',
    saveLabel: 'Save my story',
  );

  static final adult = ModeCopy._(
    isKids: false,
    headline: 'Today',
    subtitle: (name) => '$name\'s journal: notes, progress, and highlights.',
    questionLabel: 'DAILY ENTRY',
    question: 'What stood out today?',
    questionHelp: 'Dictate or type a note. You can edit, tag, and link it later.',
    addToday: 'New entry',
    todaySection: 'Today\'s entries',
    todayEmpty: 'No entries for today.',
    recentSection: 'Recent entries',
    navToday: 'Today',
    navCalendar: 'Calendar',
    navMemories: 'Entries',
    navMindMap: 'Mind map',
    navSettings: 'Settings',
    navActivity: 'Activity',
    entryNoun: 'entry',
    entryNounPlural: 'Entries',
    editorNewTitle: 'New entry',
    editorEditTitle: 'Edit entry',
    titleLabel: 'Title',
    titleHint: 'Weekly planning notes',
    bodyLabel: 'Notes',
    bodyHint: 'Key points, decisions, follow-ups…',
    recordPrompt: 'Dictate a note',
    saveLabel: 'Save entry',
  );
}
