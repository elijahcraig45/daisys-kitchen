# 🏴‍☠️ Recipe Keeper - Quick Reference Card

## First Time Setup (3 steps)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Daily Use

```bash
flutter run
```

## Key Features

### 📝 Create Recipe
Home → Tap **+** → Fill details → Add ingredients → Add steps → Save

### 👨‍🍳 Cooking Mode  
Recipe Detail → **Start Cooking** → Swipe/Navigate steps → Use timers

### 🔍 Search
Home → Search bar → Type to filter recipes

### 📤 Export
Menu (⋮) → **Export All** → Share/Save backup

### 📥 Import
Menu (⋮) → **Import Recipes** → Select JSON file

### ⭐ Favorites
Recipe Detail → Tap heart icon

## Sample Data

Import `sample_recipes.json` to try the app!

## File Locations

- **README.md** - Full documentation
- **QUICKSTART.md** - Setup guide  
- **STATUS.md** - Project status
- **COMMANDS.md** - All CLI commands
- **FIREBASE_SETUP.md** - Optional cloud sync

## Troubleshooting

**Build fails?**
```bash
flutter clean && flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

**Need help?** Check QUICKSTART.md

## Code Generation

After changing models:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Platforms Supported

✅ iOS | ✅ Android | ✅ Web | ✅ macOS | ✅ Windows | ✅ Linux

---

**Happy Cooking!** 🏴‍☠️
