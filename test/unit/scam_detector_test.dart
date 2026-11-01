import 'package:flutter_test/flutter_test.dart';

import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/services/scam_detector.dart';

ChatMessage from(MessageSender sender, String text) => ChatMessage(
      id: 'm',
      text: text,
      time: '',
      createdAt: DateTime(2026),
      sender: sender,
    );

void main() {
  test('flags the patterns in the fraud advisory', () {
    for (final String text in <String>[
      'Please send me money for the hospital',
      'Can you transfer 5000 rupees today',
      'My UPI is below',
      'I can teach you crypto trading',
      'Guaranteed returns if you invest with me',
      'My parcel is stuck, the customs officer needs ₹20000',
      'Tell me the OTP you received',
    ]) {
      expect(ScamDetector.isRisky(text), isTrue, reason: text);
    }
  });

  test('leaves ordinary conversation alone', () {
    for (final String text in <String>[
      'Assalamu alaikum, how is your family?',
      'What did you study at university?',
      'My father will call yours this weekend',
      'I work in a hospital as a doctor',
      'Do you want children?',
    ]) {
      expect(ScamDetector.isRisky(text), isFalse, reason: text);
    }
  });

  test('only the other person can raise the warning', () {
    expect(
      ScamDetector.threadIsRisky(<ChatMessage>[from(MessageSender.user, 'What is your UPI?')]),
      isFalse,
    );
    expect(
      ScamDetector.threadIsRisky(<ChatMessage>[from(MessageSender.match, 'My UPI is here')]),
      isTrue,
    );
  });
}
