/// Shared steps after a match. Each member sets their own progress.
enum JourneyStep { talking, questions, families, istikhara, decision }

extension JourneyStepX on JourneyStep {
  String get title => switch (this) {
        JourneyStep.talking => 'Getting to know each other',
        JourneyStep.questions => 'Important Questions',
        JourneyStep.families => 'Families have spoken',
        JourneyStep.istikhara => 'Istikhara',
        JourneyStep.decision => 'Decision',
      };

  String get detail => switch (this) {
        JourneyStep.talking => 'Talk respectfully and keep early chats on the app.',
        JourneyStep.questions => 'Answer the questions below, then compare.',
        JourneyStep.families => 'Bring your families into the conversation.',
        JourneyStep.istikhara => 'Take the time you need. Ask a scholar you trust if unsure.',
        JourneyStep.decision => 'Decide together, with your families.',
      };
}

class JourneyQuestion {
  const JourneyQuestion(this.id, this.topic, this.text);
  final String id;
  final String topic;
  final String text;
}

/// Prompts for discussion, not rulings. Have a scholar review the wording.
const List<JourneyQuestion> journeyQuestions = <JourneyQuestion>[
  JourneyQuestion('deen1', 'Deen', 'How do you practise day to day, and what are you working on?'),
  JourneyQuestion('deen2', 'Deen', 'What do you hope our home will look like in terms of faith?'),
  JourneyQuestion('char1', 'Character', 'How do you usually handle anger or disagreement?'),
  JourneyQuestion('money1', 'Money', 'Do you have any debts or regular financial commitments?'),
  JourneyQuestion('money2', 'Money', 'How should we decide on spending and saving?'),
  JourneyQuestion('mahr1', 'Mahr and nikah', 'What are your expectations for the mahr?'),
  JourneyQuestion('mahr2', 'Mahr and nikah', 'What kind of nikah and walimah do you want, and at what cost?'),
  JourneyQuestion('kids1', 'Children', 'Do you want children, and when? Do you have any now?'),
  JourneyQuestion('fam1', 'Family', 'Where do you expect to live, and with whom?'),
  JourneyQuestion('fam2', 'Family', 'What will your responsibilities to your parents be?'),
  JourneyQuestion('work1', 'Work', 'What are your plans for work or study after marriage?'),
  JourneyQuestion('health1', 'Health', 'Is there anything about your health your spouse should know?'),
];
