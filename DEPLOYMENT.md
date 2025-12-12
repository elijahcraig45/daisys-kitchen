# Firebase Hosting Deployment Guide 🚀

## Quick Deploy

```bash
# Make deploy script executable (first time only)
chmod +x deploy.sh

# Build and deploy
./deploy.sh
```

---

## Manual Deploy Steps

### 1. Build Flutter Web App

```bash
flutter build web --release
```

This creates optimized production build in `build/web/`

### 2. Deploy to Firebase Hosting

```bash
firebase deploy --only hosting --project recipe-f644f
```

### 3. Your Live URLs

After deployment, your app will be available at:

- **Primary**: `https://recipe-f644f.web.app`
- **Alternate**: `https://recipe-f644f.firebaseapp.com`

---

## Custom Domain (Optional)

### Add Your Own Domain

1. **Firebase Console**: [https://console.firebase.google.com/project/recipe-f644f/hosting](https://console.firebase.google.com/project/recipe-f644f/hosting)
2. Click **"Add custom domain"**
3. Enter your domain (e.g., `recipes.yourdomain.com`)
4. Follow DNS setup instructions
5. Firebase handles SSL certificate automatically!

**Cost**: FREE (Firebase Hosting includes SSL)

---

## OAuth Configuration for Production

Once deployed, update Google Cloud OAuth:

1. **Go to**: [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. **Edit** your OAuth 2.0 Client ID
3. **Add to Authorized JavaScript origins**:
   - `https://recipe-f644f.web.app`
   - `https://recipe-f644f.firebaseapp.com`
   - Your custom domain (if added)
4. **Add to Authorized redirect URIs**:
   - `https://recipe-f644f.web.app/__/auth/handler`
   - `https://recipe-f644f.firebaseapp.com/__/auth/handler`
   - Your custom domain + `/__/auth/handler` (if added)
5. Click **"SAVE"**

---

## Deployment Workflow

### For Testing
```bash
flutter run -d chrome  # Local testing
```

### For Production
```bash
./deploy.sh  # Build & deploy to Firebase Hosting
```

---

## Cost Comparison 💰

### Firebase Hosting (Recommended)
- **Spark Plan (FREE)**:
  - 10 GB storage
  - 360 MB/day bandwidth (~10 GB/month)
  - SSL certificate included
  - Custom domain support
  - Global CDN
- **Blaze Plan (Pay as you go)**:
  - $0.026/GB storage after 10GB
  - $0.15/GB bandwidth after 10GB
  - **Your usage**: Likely FREE or ~$1-2/month

### App Engine (Not Recommended for This)
- **Standard Environment**: ~$5-10/month minimum
- **Flexible Environment**: ~$25-50/month minimum
- **Better for**: Backend services with server-side code

### Verdict
**Firebase Hosting = FREE for your recipe app!** 🎉

---

## Firebase Hosting Features

✅ **Global CDN** - Fast worldwide
✅ **Auto SSL** - HTTPS everywhere
✅ **Custom domains** - Free to add
✅ **Rollback** - Previous versions saved
✅ **Preview channels** - Test before going live
✅ **Zero config** - Works with Flutter web perfectly

---

## Monitoring & Analytics

### View Metrics
- **Firebase Console**: [Hosting Dashboard](https://console.firebase.google.com/project/recipe-f644f/hosting)
- See: Requests, bandwidth, errors

### Add Google Analytics (Optional)
```bash
firebase init analytics
```

---

## Tips for Production 🏴‍☠️

1. **Always build with --release**:
   ```bash
   flutter build web --release
   ```

2. **Test locally first**:
   ```bash
   flutter run -d chrome
   ```

3. **Preview before deploy** (optional):
   ```bash
   firebase hosting:channel:deploy preview
   ```

4. **Update OAuth** after first deploy (see above)

5. **Custom domain** - Makes it look professional!

---

## Rollback (If Needed)

View previous deployments:
```bash
firebase hosting:channel:list
```

Rollback to previous version:
- Go to Firebase Console → Hosting
- Click "Release history"
- Click "Rollback" on desired version

---

**Yer production deployment be ready, Captain!** ⚓

Run `./deploy.sh` when ye be ready to go live! 🏴‍☠️
