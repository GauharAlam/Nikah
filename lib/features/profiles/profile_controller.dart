import '../../data/backend.dart';
import '../../data/option_lists.dart';
import '../../models/verification_doc.dart';
import '../../models/ward_profile.dart';
import '../core/feature_controller.dart';
import '../session/session_controller.dart';

/// The member's own draft, photos and verification documents.
class ProfileController extends FeatureController {
  ProfileController(super.backend, super.report, this._session);

  final SessionController _session;

  WardProfile? _profile;
  List<VerificationDoc> _docs = List<VerificationDoc>.from(VerificationDoc.blank);

  WardProfile? get profile => _profile;
  List<VerificationDoc> get documents => List<VerificationDoc>.unmodifiable(_docs);

  bool get isVerified => _docs
      .where((VerificationDoc d) => d.isRequired)
      .every((VerificationDoc d) => d.status == VerificationDocStatus.approved);

  int get verificationProgress {
    final List<VerificationDoc> required =
        _docs.where((VerificationDoc d) => d.isRequired).toList();
    if (required.isEmpty) return 0;
    final int done = required
        .where((VerificationDoc d) => d.status == VerificationDocStatus.approved)
        .length;
    return (done * 100 / required.length).round();
  }

  /// Returns false when the draft could not be read, so the caller can offer a
  /// retry instead of carrying on with an empty profile.
  Future<bool> loadDraft(AuthUser user) async {
    try {
      final Map<String, dynamic>? draft = await backend.loadDraft(user.uid);
      _profile = draft == null
          ? WardProfile(email: user.email, phoneCode: '+91', country: '')
          : WardProfile.fromDraft(draft);
      return true;
    } on Object {
      return false;
    }
  }

  void start(String uid) {
    follow(backend.watchDocuments(uid), (List<VerificationDoc> d) {
      _docs = d;
      notifyListeners();
    });
  }

  static Map<String, dynamic> _draftOf(WardProfile p) => p.toDraft(
        qualificationGraduate: OptionLists.qualifications[p.qualification],
      );

  void updateProfile(WardProfile Function(WardProfile) mutate) {
    final WardProfile next = mutate(_profile ?? const WardProfile());
    _profile = next;
    notifyListeners();
    if (_session.user != null) send(() => backend.saveDraft(_session.uid, _draftOf(next)));
  }

  Future<void> saveDraft(WardProfile next) async {
    _profile = next;
    notifyListeners();
    if (_session.user != null) await backend.saveDraft(_session.uid, _draftOf(next));
  }

  Future<String> uploadPhoto(String localPath, {void Function(double)? onProgress}) {
    if (_session.user == null) throw const BackendException('Please sign in again.');
    return backend.uploadPhoto(_session.uid, localPath, onProgress: onProgress);
  }

  Future<void> removePhoto(String stored) async {
    await backend.deletePhoto(stored);
    updateProfile((WardProfile p) =>
        p.copyWith(photos: p.photos.where((String x) => x != stored).toList()));
  }

  void submitEdits() {
    if (_session.isActive) send(backend.submitEdits);
  }

  void updatePrivacy({String? photoPrivacy, bool? showCaste, bool? allowFamilyShare}) {
    updateProfile((WardProfile p) => p.copyWith(
          photoPrivacy: photoPrivacy,
          showCaste: showCaste,
          allowFamilyShare: allowFamilyShare,
        ));
    if (_session.isActive) {
      send(() => backend.updatePrivacy(
            photoPrivacy: photoPrivacy,
            showCaste: showCaste,
            allowFamilyShare: allowFamilyShare,
          ));
    }
  }

  Future<void> uploadVerificationDoc(String docId, List<String> localPaths) {
    if (_session.user == null) throw const BackendException('Please sign in again.');
    return backend.submitDocument(_session.uid, docId, localPaths);
  }

  @override
  Future<void> stop() async {
    await super.stop();
    _profile = null;
    _docs = List<VerificationDoc>.from(VerificationDoc.blank);
  }
}
