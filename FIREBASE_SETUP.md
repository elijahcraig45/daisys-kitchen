# Firebase Setup Guide - Admin-Controlled Recipe App 🔥

> **Ahoy, Captain! This guide sets up yer cloud-based recipe treasure with admin controls!**

## 🎯 What You're Building

- **Public Viewing**: Anyone can browse recipes (no sign-in required)
- **Admin Control**: Only YOU can add/edit/delete recipes  
- **Cloud Storage**: Recipes stored in Firebase Firestore (GCP)
- **Real-time Sync**: Changes appear instantly across all devices
- **Future-Ready**: Comments & ratings infrastructure included

## 💰 Cost

- **Free Tier**: 50K reads/day, 20K writes/day, 1GB storage
- **Your Usage**: ~100-500 reads/day, ~5-20 writes/day
- **Actual Cost**: **FREE** for personal use! 🎉
- **If Popular**: ~$1-5/month if thousands of daily users

---

## 📋 Step 1: Create Firebase Project

1. **Navigate to [Firebase Console](https://console.firebase.google.com/)**
2. Click **"Add project"**
3. **Project name**: `recipe-keeper` (or your choice)
4. **Google Analytics**: Disable (not needed)
5. Click **"Create project"** and wait ~30 seconds

---

## 🔐 Step 2: Enable Google Authentication

1. In Firebase sidebar, click **"Authentication"**
2. Click **"Get started"**
3. Go to **"Sign-in method"** tab
4. Click **"Google"** provider
5. **Toggle "Enable"** to ON
6. **Project support email**: Select your email
7. Click **"Save"**

---

## 💾 Step 3: Create Firestore Database

1. In Firebase sidebar, click **"Firestore Database"**
2. Click **"Create database"**
3. **Start in**: Choose **"production mode"**
4. **Firestore location**: Choose closest region (e.g., `us-central1`)
5. Click **"Enable"** and wait ~1 minute

---

## 🌐 Step 4: Register Web App & Get Config

1. In Firebase Console, click **⚙️ Settings** > **Project settings**
2. Scroll to **"Your apps"** section
3. Click **Web icon** (`</>`) to add web app
4. **App nickname**: `Recipe Keeper Web`
5. Click **"Register app"**
6. **COPY** the Firebase configuration:

```javascript
// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyAFhSARa_HWEv_CxEkLH2hbcmMMBCkAQvw",
  authDomain: "recipe-f644f.firebaseapp.com",
  projectId: "recipe-f644f",
  storageBucket: "recipe-f644f.firebasestorage.app",
  messagingSenderId: "9282742070",
  appId: "1:9282742070:web:f2faee8af955867d537597"
};
```

7. **Keep this window open** - you'll need these values next!

---

## ⚙️ Step 5: Update Flutter App Configuration

1. **Open** `lib/services/firebase_service.dart`
2. **Replace** the placeholder values with YOUR Firebase config:

```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: "YOUR_API_KEY",              // Replace with your apiKey
    authDomain: "YOUR_PROJECT_ID.firebaseapp.com",  // Replace with your authDomain
    projectId: "YOUR_PROJECT_ID",        // Replace with your projectId
    storageBucket: "YOUR_PROJECT_ID.appspot.com",  // Replace with your storageBucket
    messagingSenderId: "YOUR_MESSAGING_SENDER_ID",  // Replace
    appId: "YOUR_APP_ID",                // Replace with your appId
  ),
);
```

3. **Save** the file

---

## 🔒 Step 6: Configure Google Sign-In for Web

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project (same name)
3. **APIs & Services** > **Credentials**
4. Find **OAuth 2.0 Client IDs** (created by Firebase)
5. Click **Edit** (pencil icon)
6. **Authorized JavaScript origins** - Add these:
   - `http://localhost`
   - `http://localhost:*`
   - Add your production domain later (e.g., `https://recipes.yourdomain.com`)
7. **Authorized redirect URIs** - Add:
   - `http://localhost`
   - `http://localhost/__/auth/handler`
   - Add production URI later
8. Click **Save**

---

## 👑 Step 7: Set Yourself as Admin

### Method 1: Before First Sign-In (Recommended)

1. **Open** `lib/services/auth_service.dart`
2. **Find** the `_adminEmails` set (~line 10)
3. **Add YOUR Google email**:

```dart
static final Set<String> _adminEmails = {
  'your-actual-email@gmail.com',  // Replace with YOUR Google email!
};
```

4. **Save** the file

### Method 2: After First Sign-In (Alternative)

1. Sign in to the app first
2. Go to **Firebase Console** > **Firestore Database**
3. Open `users` collection
4. Find your user document (search by your email)
5. Click **Edit** (pencil icon)
6. Add field: `isAdmin` = `true` (boolean)
7. Click **Update**

---

## 🛡️ Step 8: Deploy Firestore Security Rules

### Install Firebase CLI

```bash
npm install -g firebase-tools
```

### Login and Initialize

```bash
firebase login
cd /Users/VTNX82W/Documents/personalDev/recipes
firebase init firestore
```

- **Select** your Firebase project
- **Firestore rules file**: Press Enter (use default `firestore.rules`)
- **Firestore indexes file**: Press Enter (use default)

### Deploy Rules

```bash
firebase deploy --only firestore:rules
```

**Security Rules Summary** (already in `firestore.rules`):
- ✅ **Anyone** can READ recipes (public viewing)
- ✅ **Only admins** can CREATE/UPDATE/DELETE recipes
- ✅ **Signed-in users** can comment (future feature)
- ✅ **Signed-in users** can rate (future feature)

---

## 🚀 Step 9: Run the App!

1. **Install dependencies**:

```bash
flutter pub get
```

2. **Start the app**:

```bash
flutter run -d chrome
```

3. **Sign in**:
   - Click **sign-in button** (top right)
   - Click **"Sign in with Google"**
   - Select your Google account
   - Allow permissions

4. **Verify admin access**:
   - You should see **"Admin"** badge in user menu
   - **"New Recipe"** button should be visible
   - You can create/edit/delete recipes

5. **Test public viewing**:
   - Open app in **incognito/private window**
   - You can browse recipes WITHOUT signing in
   - "New Recipe" button is hidden for non-admins

---

## 📦 Step 10: Migrate Existing Recipes (Optional)

If you have recipes from the old localStorage system:

1. **Export** from old system:
   - Click menu (⋮) > "Export All"
   - Save JSON file

2. **Sign in as admin** in new Firebase app

3. **Import** to Firestore:
   - Click menu (⋮) > "Import Recipes"
   - Select exported JSON file
   - Recipes upload to Firestore!

---

## ✅ Verification Checklist

- [ ] Firebase project created
- [ ] Google authentication enabled
- [ ] Firestore database created  
- [ ] Web app registered
- [ ] `firebase_service.dart` updated with YOUR config
- [ ] Your email added to `_adminEmails` in `auth_service.dart`
- [ ] Google Cloud OAuth configured (authorized origins)
- [ ] Firebase CLI installed
- [ ] Firestore rules deployed
- [ ] Successfully signed in to app
- [ ] "Admin" badge appears
- [ ] Can create/edit/delete recipes
- [ ] Public viewing works (test in incognito)

---

## 🔧 Troubleshooting

### "Firebase not initialized"
- Verify you updated `firebase_service.dart` with YOUR project config (not placeholders)
- Restart app after config changes
- Check browser console for detailed error

### "Sign-in popup blocked"
- Allow popups for localhost in browser settings
- Try Chrome (best compatibility)

### "Not authorized to create recipes"
- Verify YOUR email is in `_adminEmails` set
- Sign out and sign in again after adding email
- Check Firestore console: `users/{yourId}/isAdmin` should be `true`

### "Can't see recipes"
- Check Firestore console > Database to verify data exists
- Check browser console for errors
- Verify security rules are deployed: `firebase deploy --only firestore:rules`

### "CORS errors"
- Add `http://localhost` to OAuth authorized origins in Google Cloud Console
- Clear browser cache and restart

### "Operation not allowed"
- Make sure Google provider is enabled in Firebase Authentication
- Check authorized domains in Firebase Console > Authentication > Settings > Authorized domains

---

## 🎯 Next Steps

Once Firebase is running:

1. **Add More Admins**: Add their emails to `_adminEmails` set
2. **Share Recipe URL**: Anyone can view at your app URL
3. **Add Comments** (future): Infrastructure already in place
4. **Add Ratings** (future): Security rules ready
5. **Deploy to Hosting**: Use Firebase Hosting (free!)

---

## 💻 Future Features (Already Configured!)

### Comments System

Firestore structure already set up:
```
recipes/{recipeId}/comments/{commentId}
  - userId: string
  - text: string
  - displayName: string
  - timestamp: timestamp
```

### Ratings System

Firestore structure ready:
```
recipes/{recipeId}/ratings/{userId}
  - rating: number (1-5)
  - timestamp: timestamp
```

---

## 📊 Monitoring & Costs

### Check Usage

1. **Firebase Console** > **Firestore Database** > **Usage** tab
2. Monitor reads/writes/storage
3. Should stay well within free tier for personal use

### Set Billing Alerts

1. **Google Cloud Console** > **Billing** > **Budgets & alerts**
2. Create budget: $5/month
3. Get email if you approach limit

### Typical Usage (Personal Recipe App)

- **Storage**: ~1-5 MB (hundreds of recipes)
- **Reads**: ~100-500/day (browsing)
- **Writes**: ~5-20/day (editing)
- **Cost**: **$0** (well within free tier!)

---

**Yer cloud treasure chest is ready to sail, Captain! ⚓**

All hands on deck - ye now have a professional, scalable recipe app with admin controls, public viewing, and room to grow! 🏴‍☠️🍽️
