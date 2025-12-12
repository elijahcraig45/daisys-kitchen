# Firebase Quick Reference 🏴‍☠️⚓

## 🎯 What You Have

**A complete Firebase + Firestore setup for admin-controlled, publicly viewable recipes**

---

## 📦 Files Created

```
lib/services/
├── firebase_service.dart      → Firebase initialization
├── auth_service.dart          → Google Sign-In & admin checks
└── firestore_service.dart     → Recipe CRUD on Firestore

lib/providers/
└── firebase_providers.dart    → Riverpod providers for Firebase

lib/widgets/
└── auth_widgets.dart          → AuthAppBar, AdminGuard, SignInGuard

firestore.rules                → Security rules (public read, admin write)

FIREBASE_SETUP.md              → Complete setup guide (START HERE!)
FIREBASE_MIGRATION.md          → Architecture & migration details
```

---

## 🚀 Quick Start (30 Minutes Total)

### 1. Create Firebase Project (10 min)
```
→ https://console.firebase.google.com
→ Create project "recipe-keeper"
→ Enable Authentication → Google provider
→ Create Firestore database (production mode)
→ Register web app → Copy config
```

### 2. Configure App (5 min)
```dart
// lib/services/firebase_service.dart
// Replace placeholders with YOUR values from Firebase Console

// lib/services/auth_service.dart
// Line ~10: Add your email to _adminEmails set
static final Set<String> _adminEmails = {
  'your-email@gmail.com',  // Your Google email
};
```

### 3. Configure Google Sign-In (5 min)
```
→ https://console.cloud.google.com
→ Select your Firebase project
→ APIs & Services → Credentials
→ Edit OAuth 2.0 Client
→ Add to Authorized JavaScript origins:
   - http://localhost
   - http://localhost:*
```

### 4. Deploy Security Rules (5 min)
```bash
npm install -g firebase-tools
firebase login
cd /Users/VTNX82W/Documents/personalDev/recipes
firebase init firestore
firebase deploy --only firestore:rules
```

### 5. Run & Test (5 min)
```bash
flutter pub get  # ✅ Already done!
flutter run -d chrome
# → Sign in with Google
# → Create a recipe
# → Test in incognito (public view)
```

---

## 🔐 Security Model

```
PUBLIC (not signed in)
  ✅ View all recipes
  ❌ Create/edit/delete

SIGNED-IN (non-admin)
  ✅ View all recipes
  ✅ Comment (future)
  ✅ Rate (future)
  ❌ Create/edit/delete recipes

ADMIN (your email in _adminEmails)
  ✅ Everything
  ✅ Create recipes
  ✅ Edit any recipe
  ✅ Delete any recipe
```

---

## 💰 Cost (FREE!)

**Free Tier:**
- 50,000 reads/day
- 20,000 writes/day
- 1GB storage

**Your Usage:**
- ~100-500 reads/day
- ~5-20 writes/day
- ~1-5 MB storage

**Actual Cost: $0** (100% free for personal use)

---

## 🎨 Using Firebase in Your App

### Update Home Screen

```dart
// lib/screens/home_screen.dart

// Replace
final recipes = ref.watch(filteredRecipesProvider);

// With
final recipes = ref.watch(firestoreFilteredRecipesProvider);
```

### Add Auth App Bar

```dart
// Replace regular AppBar with
appBar: AuthAppBar(
  title: 'Recipe Keeper',
  actions: [...], // Your existing actions
),
```

### Guard Admin Actions

```dart
// Show "New Recipe" button only to admins
AdminGuard(
  child: FloatingActionButton(...),
)

// Show features only to signed-in users
SignInGuard(
  child: IconButton(...),
)
```

---

## 📖 Key Documents

| File | Purpose |
|------|---------|
| **FIREBASE_SETUP.md** | Step-by-step setup guide (START HERE!) |
| **FIREBASE_MIGRATION.md** | Architecture, features, migration details |
| **firestore.rules** | Security rules (already configured) |
| **THIS FILE** | Quick reference & cheat sheet |

---

## 🔧 Common Commands

```bash
# Install dependencies
flutter pub get

# Run app with Firebase
flutter run -d chrome

# Deploy security rules
firebase deploy --only firestore:rules

# Check Firestore usage
# → Firebase Console → Firestore → Usage tab

# Export recipes (before migration)
# → App menu (⋮) → Export All

# Import recipes (after migration)
# → Sign in as admin → Menu (⋮) → Import Recipes
```

---

## ✅ Setup Checklist

- [ ] Firebase project created
- [ ] Google Authentication enabled
- [ ] Firestore database created
- [ ] Web app registered
- [ ] Config copied from Firebase Console
- [ ] `firebase_service.dart` updated with YOUR config
- [ ] `auth_service.dart` updated with YOUR email
- [ ] Google Cloud OAuth configured (authorized origins)
- [ ] Firebase CLI installed (`npm install -g firebase-tools`)
- [ ] Firebase initialized (`firebase init firestore`)
- [ ] Security rules deployed (`firebase deploy --only firestore:rules`)
- [ ] App runs successfully
- [ ] Sign-in works
- [ ] Admin badge appears
- [ ] Can create recipes
- [ ] Public viewing works (test in incognito)

---

## 🐛 Quick Troubleshooting

**"Firebase not initialized"**
→ Update `firebase_service.dart` with YOUR config (not placeholders)

**"Sign-in popup blocked"**
→ Allow popups for localhost in browser

**"Not authorized"**
→ Add your email to `_adminEmails` in `auth_service.dart`
→ Sign out and sign in again

**"Can't see recipes"**
→ Check Firestore Console → Database tab
→ Verify security rules deployed

**"CORS errors"**
→ Add `http://localhost` to OAuth authorized origins

---

## 🎯 Next Steps

1. **Read** `FIREBASE_SETUP.md` for detailed instructions
2. **Create** Firebase project (10 min)
3. **Configure** app with your values (5 min)
4. **Deploy** security rules (5 min)
5. **Test** by signing in and creating a recipe!

---

**Ready to set sail, Captain? ⚓**

All the code is written - just need to add YOUR Firebase configuration and ye be ready to navigate the cloud seas! 🏴‍☠️✨
