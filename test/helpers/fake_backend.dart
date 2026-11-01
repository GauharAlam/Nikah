import 'dart:async';

import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/models/filters.dart';
import 'package:nikah_app/models/match_profile.dart';
import 'package:nikah_app/models/notification_item.dart';
import 'package:nikah_app/models/proposal.dart';
import 'package:nikah_app/models/verification_doc.dart';

MatchProfile card(String id) => MatchProfile.fromCard(<String, dynamic>{
      'id': id,
      'name': 'Member $id',
      'age': 27,
      'photos': <String>['https://example.com/$id.jpg'],
    });

/// In-memory [Backend]. Records calls and lets a test push server state.
class FakeBackend implements Backend {
  final StreamController<AuthUser?> auth = StreamController<AuthUser?>.broadcast();
  final StreamController<AccountState> account = StreamController<AccountState>.broadcast();
  final StreamController<AppLimits> limits = StreamController<AppLimits>.broadcast();
  final StreamController<List<Proposal>> proposals = StreamController<List<Proposal>>.broadcast();
  final StreamController<List<MatchThread>> matches = StreamController<List<MatchThread>>.broadcast();
  final StreamController<List<ChatMessage>> messages = StreamController<List<ChatMessage>>.broadcast();
  final StreamController<Map<String, String>> shares = StreamController<Map<String, String>>.broadcast();
  final StreamController<List<ContactRequestRecord>> contacts = StreamController<List<ContactRequestRecord>>.broadcast();
  final StreamController<List<NotificationItem>> notifications = StreamController<List<NotificationItem>>.broadcast();
  final StreamController<List<VerificationDoc>> documents = StreamController<List<VerificationDoc>>.broadcast();

  final List<String> calls = <String>[];
  Map<String, dynamic>? draft;
  Map<String, dynamic>? savedDraft;
  List<IntroductionPage> pages = <IntroductionPage>[];
  Object? failNext;

  Future<void> _record(String call) async {
    calls.add(call);
    final Object? failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
  }

  @override
  Stream<AuthUser?> get authChanges => auth.stream;
  @override
  Future<String> sendOtp(String e164Phone) async => 'verification';
  @override
  Future<void> confirmOtp(String verificationId, String code) => _record('confirmOtp');
  @override
  Future<void> signInWithGoogle() => _record('google');
  @override
  Future<void> refreshClaims() => _record('refreshClaims');
  @override
  Future<void> signOut() => _record('signOut');
  @override
  Future<void> deleteAccount() => _record('deleteAccount');
  @override
  Stream<AccountState> watchAccount(String uid) => account.stream;
  @override
  Stream<AppLimits> watchLimits() => limits.stream;
  @override
  Future<Map<String, dynamic>?> loadDraft(String uid) async => draft;
  @override
  Future<void> saveDraft(String uid, Map<String, dynamic> d) async {
    savedDraft = d;
    await _record('saveDraft');
  }

  @override
  Future<void> submitProfile() => _record('submitProfile');
  @override
  Future<String> uploadPhoto(String uid, String localPath) async => 'photos/$uid/1.jpg';
  @override
  Future<String> photoUrl(String storagePath) async => 'https://example.com/p.jpg';
  @override
  Future<void> deletePhoto(String storagePath) => _record('deletePhoto');

  @override
  Future<IntroductionPage> fetchIntroductions(MatchFilters filters, int? cursor) async {
    await _record('fetchIntroductions:$cursor');
    return pages.isEmpty ? const IntroductionPage(<MatchProfile>[], null) : pages.removeAt(0);
  }

  @override
  Future<List<MatchProfile>> getProfiles(List<String> ids) async {
    await _record('getProfiles');
    return ids.map(card).toList();
  }

  @override
  Future<void> hideProfile(String target) => _record('hide:$target');
  @override
  Stream<List<Proposal>> watchProposals(String uid) => proposals.stream;
  @override
  Future<void> sendProposal(String to) => _record('propose:$to');
  @override
  Future<void> respondProposal(String from, {required bool accept}) =>
      _record('respond:$from:$accept');
  @override
  Future<void> withdrawProposal(String to) => _record('withdraw:$to');
  @override
  Stream<List<ContactRequestRecord>> watchContactRequests(String uid) => contacts.stream;
  @override
  Stream<Map<String, String>> watchSharedContacts(String uid) => shares.stream;
  @override
  Future<void> requestContact(String to) => _record('contact:$to');
  @override
  Future<void> respondContact(String from, {required bool accept}) =>
      _record('respondContact:$from:$accept');
  @override
  Stream<List<MatchThread>> watchMatches(String uid) => matches.stream;
  @override
  Stream<List<ChatMessage>> watchMessages(String pairId, String uid) => messages.stream;
  @override
  Future<void> sendMessage(String pairId, String uid, String text) =>
      _record('message:$pairId:$text');
  @override
  Future<void> markThreadRead(String pairId, String uid) => _record('read:$pairId');
  @override
  Future<void> unmatch(String other) => _record('unmatch:$other');
  @override
  Future<void> blockProfile(String target) => _record('block:$target');
  @override
  Future<void> reportProfile(String target, String reason) => _record('report:$target:$reason');
  @override
  Stream<List<NotificationItem>> watchNotifications(String uid) => notifications.stream;
  @override
  Future<void> markNotificationRead(String uid, String id) => _record('notified:$id');
  @override
  Future<void> registerPushToken(String uid) => _record('push');
  @override
  Stream<List<VerificationDoc>> watchDocuments(String uid) => documents.stream;
  @override
  Future<void> submitDocument(String uid, String type, List<String> localPaths) =>
      _record('document:$type');
  @override
  Future<void> validatePurchase({
    required String productId,
    required String platform,
    required String token,
    String? packageName,
  }) =>
      _record('purchase:$productId');
  @override
  Future<List<Map<String, dynamic>>> listReviewQueue() async => const <Map<String, dynamic>>[];
  @override
  Future<List<String>> documentUrls(String uid, String type) async => const <String>[];
  @override
  Future<void> reviewProfile(String uid, {required bool approve, String reason = ''}) =>
      _record('review:$uid');
  @override
  Future<void> reviewDocument(String uid, String type, {required bool approve, String reason = ''}) =>
      _record('reviewDoc:$uid');
}
