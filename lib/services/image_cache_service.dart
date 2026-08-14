import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_keeper/models/recipe.dart';

/// Asks the backend to re-host a recipe's image in this project's Storage bucket.
///
/// Best-effort by design. A recipe whose image cannot be copied — the host refuses a
/// server-side fetch, the URL is dead, the bytes are not an image — is still a perfectly
/// good recipe, so every failure here is swallowed and the app goes on rendering the
/// original URL. Nothing about it is worth interrupting someone mid-save for.
class ImageCacheService {
  ImageCacheService({FirebaseFunctions? functions, FirebaseAuth? auth})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  /// Recipes already attempted this session, so a grid that rebuilds — or a detail screen
  /// reopened — does not re-ask for something that just failed.
  final Set<String> _attempted = {};

  /// True when [recipe] has an external image that has not been copied yet, and the
  /// signed-in user is the one allowed to ask for the copy.
  bool needsCaching(Recipe recipe) {
    final id = recipe.firestoreId;
    final url = recipe.imageUrl;
    final cached = recipe.cachedImageUrl;
    final uid = _auth.currentUser?.uid;

    return id != null &&
        uid != null &&
        recipe.createdBy == uid &&
        (cached == null || cached.isEmpty) &&
        url != null &&
        url.startsWith('http') &&
        !_attempted.contains(id);
  }

  /// Fires the copy if it is wanted. Returns the new URL, or null on any refusal.
  Future<String?> cacheIfNeeded(Recipe recipe) async {
    if (!needsCaching(recipe)) return null;
    final id = recipe.firestoreId!;
    _attempted.add(id);

    try {
      final result = await _functions
          .httpsCallable('cacheRecipeImage')
          .call<Map<String, dynamic>>({'recipeId': id});
      return result.data['url'] as String?;
    } on FirebaseFunctionsException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }
}
