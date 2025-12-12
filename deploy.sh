#!/bin/bash
# Firebase Hosting Deployment Script
# Builds Flutter web app and deploys to Firebase Hosting

set -e  # Exit on error

echo "🏴‍☠️ Building and Deploying Recipe Keeper to Firebase Hosting"
echo "=============================================================="
echo ""

# Step 1: Build Flutter web app
echo "📦 Step 1: Building Flutter web app..."
flutter build web --release

echo ""
echo "✅ Build complete!"
echo ""

# Step 2: Deploy to Firebase Hosting
echo "🚀 Step 2: Deploying to Firebase Hosting..."
firebase deploy --only hosting --project recipe-f644f

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "Your app is now live at:"
echo "https://recipe-f644f.web.app"
echo "or"
echo "https://recipe-f644f.firebaseapp.com"
echo ""
echo "⚓ Happy sailing, Captain!"
