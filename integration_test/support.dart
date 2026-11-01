// Shared by the device tests. Everything talks to the local emulators.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nikah_app/data/firebase_backend.dart';
import 'package:nikah_app/models/ward_profile.dart';
import 'package:path_provider/path_provider.dart';

const String host = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
const String project = 'demo-nikah';

final String run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
int _phone = 0;

Future<Map<String, dynamic>> rest(String method, String url, Map<String, dynamic>? body) async {
  final HttpClient client = HttpClient();
  final HttpClientRequest req = await client.openUrl(method, Uri.parse(url));
  req.headers.set('Authorization', 'Bearer owner');
  req.headers.contentType = ContentType.json;
  if (body != null) req.write(jsonEncode(body));
  final HttpClientResponse res = await req.close();
  final String text = await res.transform(utf8.decoder).join();
  client.close();
  if (res.statusCode >= 300) throw StateError('$method $url: ${res.statusCode} $text');
  return text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
}

Future<void> createUser(String uid, {String? phone, Map<String, dynamic>? claims}) async {
  const String accounts = 'identitytoolkit.googleapis.com/v1/projects/$project/accounts';
  await rest('POST', 'http://$host:9099/$accounts', <String, dynamic>{'localId': uid, 'phoneNumber': ?phone});
  if (claims != null) {
    await rest('POST', 'http://$host:9099/$accounts:update', <String, dynamic>{
      'localId': uid,
      'customAttributes': jsonEncode(claims),
    });
  }
}

/// The auth emulator accepts unsigned custom tokens.
String customToken(String uid) {
  String b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return '${b64(<String, dynamic>{'alg': 'none', 'typ': 'JWT'})}.${b64(<String, dynamic>{
        'iss': 'firebase-auth-emulator@example.com',
        'sub': 'firebase-auth-emulator@example.com',
        'aud': 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
        'iat': now,
        'exp': now + 3600,
        'uid': uid,
      })}.';
}

Future<void> signInAs(String uid) async {
  await FirebaseAuth.instance.signOut();
  await FirebaseAuth.instance.signInWithCustomToken(customToken(uid));
  await FirebaseAuth.instance.currentUser!.getIdToken(true);
}

Future<String> phoneNumber() async => '+9195${run.hashCode.abs().toString().padLeft(6, '0').substring(0, 6)}${(_phone++).toString().padLeft(2, '0')}';

/// A file with real JPEG bytes, so the server's byte check runs.
Future<String> jpegFile(String name) async {
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/$name.jpg');
  await file.writeAsBytes(Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xe0, ...List<int>.filled(64, 7)]));
  return file.path;
}

WardProfile draftFor(String name, Gender gender) => WardProfile(
      displayName: name,
      hasGender: true,
      gender: gender,
      dateOfBirth: DateTime(1997, 3, 4),
      maritalStatus: 'Never married',
      marriageReadiness: 'Ready within 1 year',
      city: 'Delhi',
      homeState: 'Delhi',
      country: 'India',
      height: '5\'6"',
      almaMaters: const <String>['Aligarh Muslim University'],
      qualification: 'MBA',
      profession: 'Doctor',
      familyType: 'Joint family',
      familyBackground: 'Teachers from Lucknow',
      preferredLanguage: 'Urdu',
      graduationYear: '2020',
      intentConfirmed: true,
      dataConsent: true,
    );

/// Takes a member from nothing to approved through the real client and rules.
Future<void> approvedMember(FirebaseBackend b, String uid, String name, Gender gender, String reviewer) async {
  await createUser(uid, phone: await phoneNumber());
  await signInAs(uid);
  final String photo = await b.uploadPhoto(uid, await jpegFile('$uid-p'));
  await b.saveDraft(uid, draftFor(name, gender).copyWith(photos: <String>[photo]).toDraft(qualificationGraduate: true));
  await b.submitDocument(uid, 'name-proof', <String>[await jpegFile('$uid-d')]);
  await b.submitProfile();
  await signInAs(reviewer);
  final Map<String, dynamic> item = (await b.listReviewQueue()).firstWhere((Map<String, dynamic> i) => i['uid'] == uid);
  await b.reviewProfile(uid, decision: 'approve', version: (item['version'] as num).toInt());
  await signInAs(uid);
}


Future<void> startFirebase() => Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaLOCALEMULATORONLYNOTAREALKEY0000000',
        appId: '1:1:android:1',
        messagingSenderId: '1',
        projectId: project,
        storageBucket: 'demo-nikah.appspot.com',
      ),
    );
