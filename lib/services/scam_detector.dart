import '../models/chat_message.dart';

/// Spots the patterns in India's cybercrime advisory on matrimony fraud:
/// money requests, investment or crypto pitches, and moving off the app.
/// It only warns the reader. It never blocks a message or sends text anywhere.
class ScamDetector {
  ScamDetector._();

  static final RegExp _money = RegExp(
    r'\b(send|transfer|lend|loan|need|borrow)\b[^.?!]{0,30}\b(money|rupees|rs\.?|inr|cash|funds|amount|dollars|lakh|lakhs)\b'
    r'|\b(upi|paytm|phonepe|gpay|google pay|bank account|account number|ifsc|gift card|western union)\b'
    r'|₹\s?\d',
    caseSensitive: false,
  );

  static final RegExp _investment = RegExp(
    r'\b(crypto|bitcoin|usdt|forex|trading|invest|investment|double your|guaranteed returns|profit)\b',
    caseSensitive: false,
  );

  static final RegExp _pressure = RegExp(
    r'\b(customs|stuck at (the )?airport|medical emergency|hospital bill|visa fee|parcel|otp)\b',
    caseSensitive: false,
  );

  static bool isRisky(String text) =>
      _money.hasMatch(text) ||
      _investment.hasMatch(text) ||
      _pressure.hasMatch(text);

  /// Whether a recent message from the other person should raise the warning.
  static bool threadIsRisky(List<ChatMessage> messages, {int window = 30}) {
    final int start = messages.length > window ? messages.length - window : 0;
    return messages
        .sublist(start)
        .where((ChatMessage m) => m.sender == MessageSender.match)
        .any((ChatMessage m) => isRisky(m.text));
  }
}
