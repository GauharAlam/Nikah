import 'package:flutter_test/flutter_test.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/models/notification_item.dart';
import 'package:nikah_app/models/proposal.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late RemoteAppStore store;

  Future<void> settle() async {
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ChatMessage server(String id, String text, MessageSender sender, DateTime at) =>
      ChatMessage(id: id, text: text, time: '', createdAt: at, sender: sender);

  MatchThread thread({
    bool open = true,
    int unread = 0,
    DateTime? lastAt,
    DateTime? theirRead,
  }) =>
      MatchThread(
        pairId: 'a_me',
        otherId: 'a',
        isOpen: open,
        unread: unread,
        lastMessage: 'Salam',
        lastMessageAt: lastAt,
        theirReadAt: theirRead,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    backend = FakeBackend();
    store = RemoteAppStore(await SharedPreferences.getInstance(), backend);
    addTearDown(store.dispose);
    backend.auth.add(const AuthUser(uid: 'me', isApproved: true));
    await settle();
    backend.account.add(const AccountState(stage: ReviewStage.approved));
    await settle();
  });

  group('conversation listeners', () {
    test('having matches opens no message listener', () async {
      backend.matches.add(<MatchThread>[thread(), thread(lastAt: DateTime(2026))]);
      await settle();
      expect(backend.messageListeners, 0);
    });

    test('a listener runs only while the conversation is open', () async {
      backend.matches.add(<MatchThread>[thread()]);
      await settle();
      store.openThread('a');
      expect(backend.messageListeners, 1);
      store.closeThread();
      expect(store.messages('a'), isEmpty);
    });

    test('a closed match cannot be opened', () async {
      backend.matches.add(<MatchThread>[thread(open: false)]);
      await settle();
      store.openThread('a');
      expect(backend.messageListeners, 0);
      expect(store.isThreadOpen('a'), isFalse);
    });
  });

  group('previews and unread', () {
    test('come from the match document, with no conversation open', () async {
      backend.matches.add(<MatchThread>[thread(unread: 3, lastAt: DateTime(2026))]);
      await settle();
      expect(store.chatThreadIds, <String>['a']);
      expect(store.lastMessagePreview('a'), 'Salam');
      expect(store.unreadCount('a'), 3);
      expect(store.totalUnread, 3);
    });

    test('marking read tells the server only when something is unread', () async {
      backend.matches.add(<MatchThread>[thread()]);
      await settle();
      store.markThreadRead('a');
      await settle();
      expect(backend.calls, isNot(contains('read:a_me')));
      backend.matches.add(<MatchThread>[thread(unread: 2)]);
      await settle();
      store.markThreadRead('a');
      await settle();
      expect(backend.calls, contains('read:a_me'));
    });

    test('seen follows the other member\'s real read time', () async {
      final DateTime read = DateTime(2026, 1, 2);
      backend.matches.add(<MatchThread>[thread(theirRead: read)]);
      await settle();
      expect(store.isSeen('a', server('1', 'x', MessageSender.user, DateTime(2026, 1, 1))), isTrue);
      expect(store.isSeen('a', server('2', 'x', MessageSender.user, DateTime(2026, 1, 3))), isFalse);
      expect(store.isSeen('a', server('3', 'x', MessageSender.match, DateTime(2026, 1, 1))), isFalse);
    });
  });

  group('sending', () {
    setUp(() async {
      backend.matches.add(<MatchThread>[thread()]);
      await settle();
      store.openThread('a');
    });

    test('a message shows as sending, then the server copy replaces it', () async {
      store.sendMessage('a', 'Salam');
      expect(store.messages('a').single.state, MessageState.sending);
      await settle();
      final String id = backend.sentIds.single;
      backend.messages.add(<ChatMessage>[server(id, 'Salam', MessageSender.user, DateTime.now())]);
      await settle();
      expect(store.messages('a').single.state, MessageState.sent);
    });

    test('a failed send can be retried with the same id, so it cannot duplicate', () async {
      backend.failSend = const BackendException('offline');
      store.sendMessage('a', 'Salam');
      await settle();
      final ChatMessage failed = store.messages('a').single;
      expect(failed.state, MessageState.failed);
      store.retryMessage('a', failed.id);
      await settle();
      expect(backend.sentIds, <String>[failed.id, failed.id]);
    });

    test('nothing is sent on a closed match', () async {
      backend.matches.add(<MatchThread>[thread(open: false)]);
      await settle();
      store.sendMessage('a', 'Salam');
      await settle();
      expect(backend.sentIds, isEmpty);
    });

    test('older messages load before the live ones and stop at the start', () async {
      backend.messages.add(<ChatMessage>[server('new', 'b', MessageSender.match, DateTime(2026, 2))]);
      await settle();
      backend.olderPage = <ChatMessage>[server('old', 'a', MessageSender.match, DateTime(2026, 1))];
      await store.loadOlderMessages();
      expect(store.messages('a').map((ChatMessage m) => m.id), <String>['old', 'new']);
      backend.olderPage = <ChatMessage>[];
      await store.loadOlderMessages();
      expect(store.reachedChatStart, isTrue);
    });
  });

  group('honest outcomes', () {
    test('a refused proposal puts the card back and reports why', () async {
      backend.pages = <IntroductionPage>[IntroductionPage(<dynamic>[card('a')].cast(), null)];
      await store.refreshIntroductions();
      await settle();
      expect(store.discoveredProfiles, hasLength(1));
      backend.failNext = const BackendException('Daily proposal limit reached.');
      store.sendProposal('a');
      await settle();
      expect(store.discoveredProfiles, hasLength(1));
      expect(store.errors.value, 'Daily proposal limit reached.');
    });

    test('report failures reach the caller, so no success is shown', () async {
      backend.failNext = const BackendException('offline');
      await expectLater(store.reportProfile('a', 'Fake profile'), throwsA(isA<BackendException>()));
    });

    test('a refused block is undone', () async {
      backend.failOn = 'block';
      await expectLater(store.blockProfile('a'), throwsA(isA<BackendException>()));
      expect(store.isBlocked('a'), isFalse);
    });
  });

  test('search passes the query and mode without touching the deck', () async {
    backend.pages = <IntroductionPage>[IntroductionPage(<dynamic>[card('s')].cast(), null)];
    final IntroductionPage page = await store.searchProfiles(query: 'jamia', nearby: true);
    expect(page.profiles.single.id, 's');
    expect(backend.lastQuery, 'jamia');
    expect(backend.lastNearby, isTrue);
    expect(store.discoveredProfiles, isEmpty);
  });

  test('the activity timeline is real server notifications', () async {
    backend.notifications.add(<NotificationItem>[
      NotificationItem(
        id: 'n',
        type: NotificationType.match,
        title: 'New match',
        body: 'Interest is mutual.',
        createdAt: DateTime(2026),
      ),
    ]);
    await settle();
    expect(store.activityLog.single.title, 'New match');
  });

  test('closed matches and pending contacts have their own views', () async {
    backend.matches.add(<MatchThread>[thread(open: false)]);
    backend.contacts.add(<ContactRequestRecord>[
      const ContactRequestRecord(profileId: 'b', isIncoming: false, status: 'pending'),
      const ContactRequestRecord(profileId: 'c', isIncoming: true, status: 'declined'),
    ]);
    backend.proposals.add(<Proposal>[]);
    await settle();
    expect(store.closedMatches.map((p) => p.id), <String>['a']);
    expect(store.pendingContacts.map((p) => p.id), <String>['b']);
  });
}
