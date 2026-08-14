import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'logger_service.dart';

/// A household: the people who share a recipe log and a grocery list.
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.memberUids,
    required this.createdBy,
  });

  final String id;
  final String name;
  final List<String> memberUids;
  final String createdBy;

  static Household? fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return null;
    return Household(
      id: snap.id,
      name: data['name'] as String? ?? 'Our Kitchen',
      memberUids: (data['memberUids'] as List?)?.cast<String>() ?? const [],
      createdBy: data['createdBy'] as String? ?? '',
    );
  }
}

/// Thrown with a message worth showing to someone. Everything else is logged and
/// swallowed, following the convention in this directory.
class HouseholdException implements Exception {
  HouseholdException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Creating, joining and leaving all go through Cloud Functions.
///
/// Not because it is tidier, but because it has to: a security rule permissive enough to
/// let a non-member add themselves to `memberUids` is permissive enough to let them add
/// themselves to *any* household, and checking an invite code in rules would mean trusting
/// a code supplied by whoever is writing. The functions look the code up server-side and
/// make both writes together.
class HouseholdService {
  HouseholdService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// The signed-in user's household, or null. Follows sign-in and membership changes.
  Stream<Household?> watchMyHousehold() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<Household?>.value(null);
      return _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .asyncExpand((userSnap) {
        final householdId = userSnap.data()?['householdId'] as String?;
        if (householdId == null) return Stream<Household?>.value(null);
        return _firestore
            .collection('households')
            .doc(householdId)
            .snapshots()
            .map(Household.fromSnapshot);
      });
    });
  }

  /// Display names for a household's members, for the members list.
  ///
  /// Reads each member's profile, which the rules allow only because they are in your
  /// household. Names, never emails.
  Future<Map<String, String>> memberNames(Household household) async {
    if (household.memberUids.isEmpty) return {};
    try {
      // One query rather than a read per member. A loop of get() calls is the same code
      // length and turns a members list into a dozen billed reads every time it renders.
      final snap = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: household.memberUids)
          .get();
      return {
        for (final doc in snap.docs)
          doc.id: doc.data()['displayName'] as String? ?? 'Someone',
      };
    } catch (e) {
      LoggerService.warning('Could not load member names', 'Household');
      return {for (final uid in household.memberUids) uid: 'Someone'};
    }
  }

  Future<String?> create(String name) => _call('createHousehold', {'name': name})
      .then((data) => data?['householdId'] as String?);

  Future<String?> join(String code) =>
      _call('joinHousehold', {'code': code}).then((data) => data?['name'] as String?);

  Future<bool> leave() => _call('leaveHousehold', {}).then((data) => data != null);

  /// A fresh invite code, replacing any previous one for this household.
  Future<String?> createInvite() =>
      _call('createHouseholdInvite', {}).then((data) => data?['code'] as String?);

  Future<Map<String, dynamic>?> _call(String name, Map<String, dynamic> args) async {
    try {
      final result =
          await _functions.httpsCallable(name).call<Map<String, dynamic>>(args);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      LoggerService.warning('$name refused: ${e.code}', 'Household');
      // The functions phrase their own refusals — "that code has expired", "you are
      // already in a household" — so pass them through rather than inventing wording.
      throw HouseholdException(e.message ?? 'That did not work. Try again.');
    } catch (e) {
      LoggerService.error('$name failed', error: e, tag: 'Household');
      throw HouseholdException('Could not reach the server. Try again.');
    }
  }
}
