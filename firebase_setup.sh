#!/bin/bash
# Firebase Setup - Final Steps Script
# Run this after completing Step 4 in FIREBASE_SETUP.md

set -e  # Exit on error

echo "🏴‍☠️ Firebase Setup - Final Steps"
echo "=================================="
echo ""

# Step 8: Initialize Firebase
echo "📋 Step 8: Initialize Firebase in project..."
echo ""
echo "Running: firebase init firestore"
echo ""

firebase init firestore <<EOF


EOF

echo ""
echo "✅ Firebase initialized!"
echo ""

# Step 8b: Deploy security rules
echo "🛡️  Step 8b: Deploy Firestore security rules..."
echo ""

firebase deploy --only firestore:rules

echo ""
echo "✅ Security rules deployed!"
echo ""

echo "🎉 Firebase setup complete!"
echo ""
echo "Next steps:"
echo "1. Make sure you've updated lib/services/firebase_service.dart with YOUR Firebase config"
echo "2. Make sure you've added YOUR email to lib/services/auth_service.dart"
echo "3. Run: flutter run -d chrome"
echo "4. Sign in and test!"
echo ""
