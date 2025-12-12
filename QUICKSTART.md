# Recipe Keeper - Modern Web Recipe Application

> **Ahoy! This be yer modern, responsive web-first recipe application with a treasure chest of features!**

## 🚀 Quick Start

**Run on Web (Recommended)**
```bash
flutter pub get
flutter run -d chrome
```

**For Mobile/Desktop**
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## ✨ What's New - Modern Web Experience

### 🎨 **Responsive Grid Layout**
- **Adaptive columns**: 1 column (mobile) → 2 (tablet) → 3-4 (desktop)
- **Beautiful recipe cards** with images, difficulty badges, and quick info
- **Smooth hover effects** for better web interaction

### 🧭 **Smart Navigation & Routing**
- **Deep linking** - Share direct links to recipes
- **Browser back/forward** works seamlessly
- **Clean URLs** like `/recipe/123` and `/recipe/123/cook`

### 🔍 **Enhanced Search & Filtering**
- **Live search** across titles, descriptions, and tags
- **Category sidebar** (desktop) with quick navigation
- **Difficulty filters** - Easy, Medium, Hard
- **Favorites filter** - Find your starred recipes instantly

### 📱 **Responsive Sidebar (Wide Screens)**
- Browse all categories
- Filter by difficulty level
- Always visible on desktop for quick access

### 🎯 **Improved Recipe Cards**
- **Image support** - Add recipe photos via URL
- **Difficulty badges** - Color-coded visual indicators
- **Favorite markers** - Heart icon for starred recipes
- **Quick stats** - Prep time, cook time, servings at a glance

## 🎮 Using the App

### Adding Recipes
1. Click the **"New Recipe"** floating button
2. Fill in details (title, description, times, difficulty)
3. Add **ingredients** with amounts
4. Create **step-by-step instructions** with optional timers
5. Save - your recipe appears in the grid!

### Browsing & Searching
- **Search bar** - Type to filter instantly
- **Category sidebar** (desktop) - Click to filter by category
- **Difficulty chips** (mobile) - Tap to filter
- **Grid view** - See all recipes at once with images

### Recipe Details
- **Clean layout** with all info visible
- **Favorite toggle** - Star your best recipes
- **Edit/Delete** - Quick actions via menu
- **Start Cooking** - Enter cooking mode with timers

### Cooking Mode
- **Step-by-step view** with ingredient amounts per step
- **Built-in timers** - Tap to start countdown
- **Swipe navigation** - Move between steps easily
- **Distraction-free** cooking experience

### Cooking Mode
- **Step-by-step view** with ingredient amounts per step
- **Built-in timers** - Tap to start countdown
- **Swipe navigation** - Move between steps easily
- **Distraction-free** cooking experience

## 📦 Importing Sample Recipes

The app includes sample recipes to get you started:

1. Click the menu (⋮) in top right
2. Select **"Import Recipes"**
3. Choose `sample_recipes.json` from the project folder
4. Enjoy 2 pre-made recipes!

## 💾 Data Storage

### Web Platform
- **Browser localStorage** - Recipes saved in your browser
- **Persistent** - Data survives page refreshes
- **Per-browser** - Each browser has its own storage

### Mobile/Desktop
- **Isar Database** - Fast local NoSQL database
- **Persistent** - Data saved to device
- **Fast search** - Optimized indexing

## 🎨 Technical Features

### Modern Stack
- **Flutter 3.8+** - Cross-platform framework
- **Material Design 3** - Modern, beautiful UI
- **go_router** - Web-friendly navigation
- **Riverpod** - Reactive state management
- **Responsive design** - Works on any screen size

### Performance
- **Lazy loading** - Only loads what you see
- **Cached images** - Fast image loading
- **Instant search** - Filter as you type
- **Smooth animations** - 60 FPS transitions

## 🛠️ Common Issues

**Q: App shows blank grid?**
A: You haven't added recipes yet! Click "New Recipe" or import sample data.

**Q: Categories not showing?**
A: Categories appear automatically when you add recipes with category tags.

**Q: Search not working?**
A: The search is case-insensitive and searches across title, description, and tags.

**Q: Can't see sidebar?**
A: Sidebar only appears on screens wider than 900px. Use mobile filters on smaller screens.

**Q: Images not loading?**
A: Make sure image URLs are valid and publicly accessible (HTTPS preferred).

## 🌐 Web-Specific Tips

- **Bookmarkable URLs** - Bookmark specific recipes
- **Share links** - Copy URL to share recipes
- **Import/Export** - Backup your recipes as JSON
- **Works offline** - Basic PWA support (recipes already loaded)

## 🚢 What's Next?

### Immediate Actions
1. **Import sample recipes** to see the app in action
2. **Create your first recipe** with your favorite dish
3. **Add images** to make recipes visually appealing
4. **Organize with categories** - Breakfast, Dinner, Desserts, etc.
5. **Mark favorites** for quick access

### Advanced Features
- **Use URL images** - Add recipe photos from the web
- **Set difficulty levels** - Help others know what to expect
- **Add detailed timers** - Perfect for precise cooking
- **Export backups** - Save your recipe collection
- **Share URLs** - Send recipe links to friends

## 🏴‍☠️ Pro Tips from a Pirate Chef

- **Prep times matter** - Set them accurately for better planning
- **Use step timers** - Never overcook again!
- **Tag everything** - Makes searching a breeze
- **Add notes** - Document your secret tweaks
- **Star your favorites** - Quick access to go-to recipes
- **Categories are your friend** - Stay organized as you grow

---

**Happy Cookin', Matey!** May yer recipes be plentiful and yer meals delicious! 🍽️⚓

For technical details, see `PROJECT_SUMMARY.md` | For commands, see `COMMANDS.md`
