// Runs the real FirebaseBackend on a device against the local emulators, so the
// Dart client, Firestore rules, Storage rules and Cloud Functions are proved
// together. Run with tool/integration_test.sh.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/data/firebase_backend.dart';
import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/models/filters.dart';
import 'package:nikah_app/models/proposal.dart';
import 'package:nikah_app/models/verification_doc.dart';
import 'package:nikah_app/models/ward_profile.dart';

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseBackend b;
  final String reviewer = 'rev$run';
  final String man = 'man$run';
  final String woman = 'wom$run';

  setUpAll(() async {
    await startFirebase();
    b = FirebaseBackend.emulator(host);
    await createUser(reviewer, claims: <String, dynamic>{'reviewer': true});
  });

  testWidgets('Journey 1: register, onboard, submit, review, approved, discovery', (_) async {
    await approvedMember(b, man, 'Zayd Khan', Gender.male, reviewer);
    await approvedMember(b, woman, 'Sara Ali', Gender.female, reviewer);

    await signInAs(man);
    final AccountState account = await b.watchAccount(man).first;
    expect(account.stage, ReviewStage.approved);

    final IntroductionPage page = await b.fetchIntroductions(const MatchFilters(minAge: 18, maxAge: 60), null);
    final Iterable<String> ids = page.profiles.map((p) => p.id);
    expect(ids, contains(woman));
    final card = page.profiles.firstWhere((p) => p.id == woman);
    expect(card.name, 'Sara', reason: 'discovery shows a first name only');
    expect(card.photos, isNotEmpty, reason: 'a link for the published photo');
  });

  testWidgets('a draft saved by the real client passes the field allow-list', (_) async {
    await signInAs(man);
    final Map<String, dynamic>? draft = await b.loadDraft(man);
    expect(WardProfile.fromDraft(draft!).familyBackground, 'Teachers from Lucknow');
  });

  testWidgets('Journey 2: proposal, acceptance, match, chat both ways', (_) async {
    await signInAs(man);
    await b.sendProposal(woman);
    expect((await b.watchProposals(man).first).single.status, ProposalStatus.pending);

    await signInAs(woman);
    await b.respondProposal(man, accept: true);
    final MatchThread thread = (await b.watchMatches(woman).first).single;
    expect(thread.isOpen, isTrue);

    await b.sendMessage(thread.pairId, woman, 'As-salamu alaykum', id: 'm-$run-1');
    await signInAs(man);
    final List<ChatMessage> seen = await b.watchMessages(thread.pairId, man).firstWhere((List<ChatMessage> m) => m.isNotEmpty);
    expect(seen.single.text, 'As-salamu alaykum');
    expect(seen.single.sender, MessageSender.match);

    await b.sendMessage(thread.pairId, man, 'Wa alaykum as-salam', id: 'm-$run-2');
    await b.sendMessage(thread.pairId, man, 'Wa alaykum as-salam', id: 'm-$run-2');
    final List<ChatMessage> all = await b.watchMessages(thread.pairId, man).firstWhere((List<ChatMessage> m) => m.length >= 2);
    expect(all, hasLength(2), reason: 'a retried message is not duplicated');

    await signInAs(woman);
    await Future<void>.delayed(const Duration(seconds: 2));
    final MatchThread after = (await b.watchMatches(woman).first).single;
    expect(after.unread, greaterThan(0));
    await b.markThreadRead(after.pairId, woman);
    expect((await b.watchMatches(woman).first).single.unread, 0);
  });

  testWidgets('Journey 6: contact needs the other person, and shares the verified number', (_) async {
    await signInAs(man);
    await b.requestContact(woman);
    await signInAs(woman);
    await b.respondContact(man, accept: true);
    final Map<String, String> shared = await b.watchSharedContacts(woman).firstWhere((Map<String, String> m) => m.isNotEmpty);
    expect(shared[man], startsWith('+9195'));
  });

  testWidgets('Journey 3: a declined proposal creates no match', (_) async {
    final String other = 'dec$run';
    await approvedMember(b, other, 'Hana Noor', Gender.female, reviewer);
    await signInAs(man);
    await b.sendProposal(other);
    await signInAs(other);
    await b.respondProposal(man, accept: false);
    expect(await b.watchMatches(other).first, isEmpty);
  });

  testWidgets('Journey 4: a family member gets what is granted, until it is removed', (_) async {
    final String parent = 'par$run';
    final String phone = await phoneNumber();
    await createUser(parent, phone: phone);
    await signInAs(man);
    final String code = await b.createFamilyInvite(
      name: 'Abu',
      relationship: 'father',
      phone: phone,
      permissions: <String>['view_shortlist', 'view_profile'],
    );
    await signInAs(parent);
    await b.joinFamily(code);
    final FamilyOverview overview = await b.familyOverview(man);
    expect(overview.profileSummary, contains('Zayd'));
    expect(overview.proposals, isNull);
    await signInAs(man);
    expect((await b.watchFamilyAdmin(man).firstWhere((FamilyAdmin a) => a.members.isNotEmpty)).members.single.name, 'Abu');
    await b.removeGuardian(parent);
    await signInAs(parent);
    await expectLater(
      b.familyOverview(man),
      throwsA(isA<BackendException>().having((BackendException e) => e.kind, 'kind', FailureKind.notAllowed)),
    );
  });

  testWidgets('verification states reach the client, and a reviewer can ask again', (_) async {
    await signInAs(reviewer);
    await b.documentUrls(man, 'name-proof');
    await b.reviewDocument(man, 'name-proof', decision: 'resubmit', reason: 'Too dark');
    await signInAs(man);
    final List<VerificationDoc> docs = await b.watchDocuments(man).first;
    final VerificationDoc id = docs.firstWhere((VerificationDoc d) => d.id == 'name-proof');
    expect(id.status, VerificationDocStatus.resubmissionRequired);
    expect(id.rejectionReason, 'Too dark');
  });

  testWidgets('Journey 5: blocking stops both people', (_) async {
    await signInAs(woman);
    final String pair = (await b.watchMatches(woman).first).single.pairId;
    await b.blockProfile(man);
    await signInAs(man);
    expect((await b.watchMatches(man).first).single.isOpen, isFalse);
    await expectLater(b.sendMessage(pair, man, 'hello', id: 'm-$run-3'), throwsA(isA<BackendException>()));
    await expectLater(b.requestContact(woman), throwsA(isA<BackendException>()));
    expect(await b.getProfiles(<String>[woman]), isEmpty);
  });

  testWidgets('export returns the member\'s own data', (_) async {
    await signInAs(man);
    final Map<String, dynamic> data = await b.exportMyData();
    expect((data['draft'] as Map<dynamic, dynamic>)['fullName'], 'Zayd Khan');
  });

  testWidgets('Journey 7: deleting removes the account and everything it can reach', (_) async {
    await signInAs(man);
    await b.deleteAccount();
    expect(FirebaseAuth.instance.currentUser, isNull);
    await signInAs(woman);
    expect(await b.getProfiles(<String>[man]), isEmpty);
    expect(await b.watchMatches(woman).first, isEmpty, reason: 'the match went with the account');
  });
}
