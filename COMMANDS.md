# Useful Commands Reference

## Development Commands

### Setup & Installation
```bash
# Get all dependencies
flutter pub get

# Generate code (run after model changes)
dart run build_runner build --delete-conflicting-outputs

# Watch mode (auto-regenerate on file changes)
dart run build_runner watch
```

### Running the App
```bash
# Run on connected device/emulator
flutter run

# Run with hot reload enabled (default)
flutter run --debug

# Run in release mode (optimized)
flutter run --release

# Run on specific device
flutter devices                    # List available devices
flutter run -d <device-id>        # Run on specific device
flutter run -d chrome             # Run in Chrome browser
```

### Code Quality
```bash
# Static analysis
flutter analyze

# Format code
flutter format .

# Run tests
flutter test

# Code coverage
flutter test --coverage
```

### Building

#### Android
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

#### iOS
```bash
# Build for device
flutter build ios --release

# Build for simulator
flutter build ios --debug --simulator
```

#### Web
```bash
# Build for web
flutter build web --release

# Serve locally
flutter run -d chrome
```

#### Desktop
```bash
# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release
```

### Maintenance
```bash
# Clean build files
flutter clean

# Get latest package versions
flutter pub upgrade

# Check for outdated packages
flutter pub outdated

# Doctor (check Flutter installation)
flutter doctor
```

## Git Commands

```bash
# Initial commit
git add .
git commit -m "Initial commit: Recipe Keeper app"

# Create repository on GitHub/GitLab
git remote add origin <your-repo-url>
git push -u origin main

# Regular commits
git add .
git commit -m "Your commit message"
git push
```

## Troubleshooting Commands

```bash
# Full clean rebuild
flutter clean && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter run

# Clear pub cache (if dependency issues)
flutter pub cache repair

# Update Flutter
flutter upgrade

# Check Flutter installation
flutter doctor -v
```

## Code Generation

```bash
# Generate once
dart run build_runner build

# Delete conflicting outputs and regenerate
dart run build_runner build --delete-conflicting-outputs

# Watch mode (auto-regenerate)
dart run build_runner watch --delete-conflicting-outputs

# Clean generated files
dart run build_runner clean
```

## Platform-Specific

### Android
```bash
# List connected devices
adb devices

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# View logs
adb logcat

# Clear app data
adb shell pm clear com.seadog.recipe_keeper
```

### iOS
```bash
# List simulators
xcrun simctl list devices

# Boot simulator
xcrun simctl boot <device-id>

# Install on simulator
flutter install
```

## Performance

```bash
# Profile mode (performance testing)
flutter run --profile

# Measure app size
flutter build apk --analyze-size
flutter build ios --analyze-size

# Run with performance overlay
flutter run --profile --trace-skia
```

## Useful Shortcuts (While Running)

- `r` - Hot reload
- `R` - Hot restart
- `p` - Toggle performance overlay
- `o` - Toggle platform (iOS/Android widgets)
- `z` - Toggle elevation
- `h` - List all shortcuts
- `q` - Quit

## Quick Start Sequence

For first-time setup:
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

For subsequent runs:
```bash
flutter run
```

After model changes:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

Save this file for quick reference! 🏴‍☠️
