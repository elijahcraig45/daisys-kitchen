# Deployment Guide

## Automated Deployment

This repository uses GitHub Actions for continuous deployment. Every push to the `main` branch automatically:

1. Builds the Flutter web app
2. Deploys to Firebase Hosting at https://recipe-f644f.web.app

## Branch Protection

The `main` branch is protected with the following rules:
- ❌ Force pushes are disabled
- ❌ Branch deletion is disabled

## Manual Deployment

If you need to deploy manually:

```bash
# Build the app
flutter build web --release

# Deploy to Firebase
firebase deploy --only hosting
```

## Secrets Configuration

The following secrets are configured in GitHub Actions:
- `FIREBASE_SERVICE_DART` - Firebase configuration file
- `ADMIN_CONFIG_DART` - Admin email configuration
- `FIREBASE_TOKEN` - Firebase CI deployment token

## Workflow Status

Check the status of deployments at:
https://github.com/elijahcraig45/daisys-kitchen/actions
