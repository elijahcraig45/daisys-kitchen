import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/recipe.dart';
import 'ingredient_parser.dart';
import 'logger_service.dart';

/// One line on the household's list, as stored.
class GroceryItem {
  const GroceryItem({
    required this.id,
    required this.display,
    required this.canonicalName,
    required this.aisle,
    required this.done,
    this.quantityLabel = '',
    this.sourceTitles = const [],
  });

  final String id;
  final String display;
  final String canonicalName;
  final String aisle;
  final bool done;

  /// Pre-rendered, e.g. `2.5 cups` or `1 cup + 200 g`. Stored rather than recomputed so
  /// the list reads identically on any client, including the wall calendar, without
  /// every one of them needing the parser.
  final String quantityLabel;

  final List<String> sourceTitles;

  static GroceryItem fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    return GroceryItem(
      id: snap.id,
      display: data['display'] as String? ?? '',
      canonicalName: data['canonicalName'] as String? ?? '',
      aisle: data['aisle'] as String? ?? 'other',
      done: data['done'] as bool? ?? false,
      quantityLabel: data['quantityLabel'] as String? ?? '',
      sourceTitles: (data['sourceTitles'] as List?)?.cast<String>() ?? const [],
    );
  }
}

/// The household's grocery list.
///
/// One list per household rather than many. Two people in a kitchen need one list they
/// both trust; naming and switching between several is a feature that earns its keep in a
/// bigger product than this.
class GroceryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _lists =>
      _firestore.collection('groceryLists');

  /// The household's list id, created on first use.
  ///
  /// Keyed by household id rather than auto-generated, so two members opening the list at
  /// the same moment cannot create two of them.
  Future<String?> _listIdFor(String householdId) async {
    final ref = _lists.doc(householdId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'householdId': householdId,
        'name': 'Groceries',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return ref.id;
  }

  Stream<List<GroceryItem>> watchItems(String householdId) {
    return _lists
        .doc(householdId)
        .collection('items')
        .snapshots()
        .map((snap) => snap.docs.map(GroceryItem.fromSnapshot).toList()
          ..sort((a, b) {
            // Store order first, then alphabetical, so the list is walked once. Done
            // items sink to the bottom rather than disappearing — "did I get that?" is a
            // question people ask a list.
            if (a.done != b.done) return a.done ? 1 : -1;
            final byAisle = IngredientParser.aisleOrder
                .indexOf(a.aisle)
                .compareTo(IngredientParser.aisleOrder.indexOf(b.aisle));
            return byAisle != 0 ? byAisle : a.display.compareTo(b.display);
          }))
        .handleError((Object e) {
      LoggerService.error('Grocery list stream failed', error: e, tag: 'Grocery');
    });
  }

  /// Adds a recipe's ingredients, merging with whatever is already on the list.
  ///
  /// Merging happens against the existing items rather than only within the recipe, so
  /// adding two recipes one after another gives the same answer as adding both at once.
  Future<int> addRecipe(String householdId, Recipe recipe) async {
    final listId = await _listIdFor(householdId);
    if (listId == null) return 0;

    final existing = await _lists.doc(listId).collection('items').get();
    final byCanonical = {
      for (final doc in existing.docs) doc.data()['canonicalName'] as String? ?? '': doc,
    };

    final inputs = recipe.ingredients.map((i) => IngredientInput(
          name: i.name,
          amount: [i.amount, i.unit].where((p) => (p ?? '').trim().isNotEmpty).join(' '),
          sourceTitle: recipe.title,
        ));

    var added = 0;
    for (final item in IngredientParser.combine(inputs)) {
      final match = byCanonical[item.canonicalName];
      if (match == null) {
        await _lists.doc(listId).collection('items').add({
          'display': item.display,
          'canonicalName': item.canonicalName,
          'quantityLabel': item.quantityLabel,
          'aisle': item.aisle,
          'sourceTitles': item.sourceTitles,
          'raw': item.raw,
          'done': false,
          'addedBy': _auth.currentUser?.uid,
          'addedAt': FieldValue.serverTimestamp(),
        });
        added++;
        continue;
      }

      // Already on the list. Re-combining from the stored raw strings keeps the sum
      // right, rather than trying to add a rendered label to another rendered label.
      final storedRaw = (match.data()['raw'] as List?)?.cast<String>() ?? const [];
      final merged = IngredientParser.combine([
        ...storedRaw.map((r) => IngredientInput(name: item.canonicalName, amount: r)),
        ...item.raw.map((r) => IngredientInput(name: item.canonicalName, amount: r)),
      ]);
      final combined = merged.isEmpty ? item : merged.first;

      final titles = {
        ...((match.data()['sourceTitles'] as List?)?.cast<String>() ?? const []),
        ...item.sourceTitles,
      };
      await match.reference.update({
        'quantityLabel': combined.quantityLabel,
        'raw': [...storedRaw, ...item.raw],
        'sourceTitles': titles.toList(),
        // Re-adding something already ticked off means it is wanted again.
        'done': false,
      });
    }

    await _lists.doc(listId).update({'updatedAt': FieldValue.serverTimestamp()});
    return added;
  }

  Future<bool> addManual(String householdId, String text) async {
    final listId = await _listIdFor(householdId);
    if (listId == null || text.trim().isEmpty) return false;

    // Typed by a person, so it might be "2 lemons" or just "lemons".
    final parsed = IngredientParser.parseAmount(text);
    final name = parsed.hasQuantity ? (parsed.leftover ?? text) : text;
    final canonical = IngredientParser.canonicalName(name);
    if (canonical.isEmpty) return false;

    await _lists.doc(listId).collection('items').add({
      'display': name.trim(),
      'canonicalName': canonical,
      'quantityLabel':
          parsed.hasQuantity ? IngredientParser.formatTerm(parsed.quantity!, parsed.unit) : '',
      'aisle': IngredientParser.aisleFor(canonical),
      'sourceTitles': <String>[],
      'raw': [text.trim()],
      'done': false,
      'addedBy': _auth.currentUser?.uid,
      'addedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// Ticks an item off, and records the purchase.
  ///
  /// The history is what a "you usually buy this weekly" suggestion would be built from
  /// later. Recorded from the start because it can only ever be collected forwards —
  /// waiting until the feature exists means waiting again for the data.
  Future<bool> setDone(String householdId, GroceryItem item, bool done) async {
    try {
      await _lists.doc(householdId).collection('items').doc(item.id).update({
        'done': done,
        'doneAt': done ? FieldValue.serverTimestamp() : null,
      });
      if (done) {
        await _firestore
            .collection('groceryHistory')
            .doc(householdId)
            .collection('purchases')
            .add({
          'canonicalName': item.canonicalName,
          'doneAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      LoggerService.error('Could not tick item', error: e, tag: 'Grocery');
      return false;
    }
  }

  Future<bool> remove(String householdId, GroceryItem item) async {
    try {
      await _lists.doc(householdId).collection('items').doc(item.id).delete();
      return true;
    } catch (e) {
      LoggerService.error('Could not remove item', error: e, tag: 'Grocery');
      return false;
    }
  }

  /// Clears everything already ticked off.
  Future<int> clearDone(String householdId) async {
    try {
      final done = await _lists
          .doc(householdId)
          .collection('items')
          .where('done', isEqualTo: true)
          .get();
      // One batch: a half-cleared list after a dropped connection would be confusing.
      final batch = _firestore.batch();
      for (final doc in done.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return done.docs.length;
    } catch (e) {
      LoggerService.error('Could not clear finished items', error: e, tag: 'Grocery');
      return 0;
    }
  }
}
