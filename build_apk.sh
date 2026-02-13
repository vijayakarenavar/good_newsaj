#!/bin/bash

# Script to build APK with branch name and version details
# This script should be run in an environment with Android SDK properly configured

set -e  # Exit on any error

echo "==========================================="
echo "Building Joy Scroll APK with Branch Details"
echo "==========================================="

# Get current branch name
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $BRANCH_NAME"

# Get current commit hash
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "Current commit: $COMMIT_HASH"

# Get version from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | cut -d ' ' -f 2)
echo "App version: $VERSION"

# Create version string with branch and commit info
BUILD_VERSION="${VERSION}-${BRANCH_NAME}-${COMMIT_HASH}"
echo "Build version: $BUILD_VERSION"

# Update version in pubspec.yaml temporarily for this build
TEMP_PUBSPEC="pubspec_temp.yaml"
cp pubspec.yaml $TEMP_PUBSPEC

# Create a temporary pubspec with updated version
sed "s/^version:.*/version: $BUILD_VERSION+${COMMIT_HASH:0:4}/" pubspec.yaml > $TEMP_PUBSPEC

# Build the APK
echo "Building APK for branch: $BRANCH_NAME"
flutter build apk --debug --dart-define=APP_BRANCH="$BRANCH_NAME" --dart-define=APP_COMMIT="$COMMIT_HASH" --dart-define=APP_VERSION="$BUILD_VERSION"

# Restore original pubspec
mv $TEMP_PUBSPEC pubspec.yaml

echo "==========================================="
echo "APK Build Complete!"
echo "==========================================="
echo "Branch: $BRANCH_NAME"
echo "Commit: $COMMIT_HASH" 
echo "Version: $BUILD_VERSION"
echo ""
echo "APK Location: build/app/outputs/flutter-apk/app-debug.apk"
echo ""
echo "Note: If you're in a GitHub Codespace without Android SDK,"
echo "      you'll need to run this script in an environment with"
echo "      Android SDK properly configured."
echo ""

# If running in GitHub Actions or similar CI environment
if [ "$GITHUB_ACTIONS" = "true" ]; then
    echo "GitHub Actions detected - preparing artifact..."
    # Create a build info file
    cat > build_info.txt << EOF
Build Information:
Branch: $BRANCH_NAME
Commit: $COMMIT_HASH
Version: $BUILD_VERSION
Build Date: $(date)
Environment: GitHub Actions
EOF
    
    echo "Build info saved to build_info.txt"
fi