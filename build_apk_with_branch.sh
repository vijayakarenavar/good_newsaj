#!/bin/bash
# Script to build APK with branch name and version details

# Exit on error
set -e

echo "==========================================="
echo "Building Joy Scroll APK with Branch Details"
echo "==========================================="

# Check if we're in a git repository
if ! git status > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Get current branch name
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $BRANCH_NAME"

# Get current commit hash
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "Current commit: $COMMIT_HASH"

# Get version from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | cut -d ' ' -f 2 | tr -d '\r')
echo "App version: $VERSION"

# Create version string with branch and commit info
BUILD_VERSION="${VERSION}-${BRANCH_NAME}-${COMMIT_HASH}"
echo "Build version: $BUILD_VERSION"

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter is not installed or not in PATH"
    exit 1
fi

echo "Flutter is available, proceeding with build..."

# Create build directory if it doesn't exist
mkdir -p build/apk_output

# Build the APK with debug symbols
echo "Building APK for branch: $BRANCH_NAME"
flutter build apk --debug \
  --dart-define=APP_BRANCH="$BRANCH_NAME" \
  --dart-define=APP_COMMIT="$COMMIT_HASH" \
  --dart-define=APP_VERSION="$BUILD_VERSION" \
  --dart-define=BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Check if build was successful
if [ $? -eq 0 ]; then
    # Find the built APK
    APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
    
    if [ -f "$APK_PATH" ]; then
        # Create new APK name with branch and version info
        NEW_APK_NAME="joy_scroll-${VERSION}-${BRANCH_NAME}-${COMMIT_HASH}.apk"
        OUTPUT_PATH="build/apk_output/$NEW_APK_NAME"
        
        # Copy APK to output directory with new name
        cp "$APK_PATH" "$OUTPUT_PATH"
        
        echo "==========================================="
        echo "APK Build Successful!"
        echo "==========================================="
        echo "Branch: $BRANCH_NAME"
        echo "Commit: $COMMIT_HASH" 
        echo "Version: $VERSION"
        echo "Build version: $BUILD_VERSION"
        echo ""
        echo "Original APK: $APK_PATH"
        echo "Renamed APK: $OUTPUT_PATH"
        echo ""
        
        # Show file size
        if command -v ls &> /dev/null; then
            ls -lh "$OUTPUT_PATH"
        fi
        
        # Create build info file
        BUILD_INFO_FILE="build/apk_output/build_info_${BRANCH_NAME}_${COMMIT_HASH}.txt"
        cat > "$BUILD_INFO_FILE" << EOF
Build Information:
Branch: $BRANCH_NAME
Commit: $COMMIT_HASH
Version: $VERSION
Build Version: $BUILD_VERSION
Build Date: $(date -u)
Build Type: Debug
Platform: Android
Environment: $(uname -a)
Flutter Version: $(flutter --version | head -n1)
EOF
        
        echo "Build info saved to: $BUILD_INFO_FILE"
        echo ""
        echo "🎉 Joy Scroll APK built successfully with branch details!"
    else
        echo "Error: APK file not found at $APK_PATH"
        exit 1
    fi
else
    echo "Error: Flutter build failed"
    exit 1
fi

echo "==========================================="
echo "Build Process Complete"
echo "==========================================="