# Joy Scroll APK Building Guide

This guide explains how to build APKs for the Joy Scroll application with branch and version details.

## Branch Configuration

### Current Repository State
The Joy Scroll repository currently has the following branches:

**Local branches:**
- `main`: Production-ready code with comprehensive analysis
- `other_features`: Active development branch (current branch)
- `backup_before_ui_changes`: Backup branch before UI modifications

**Remote branches:**
- `origin/main`: The main branch on GitHub (remote)

### GitHub Actions Workflow
The workflow is configured to trigger on pushes to both `main` and `other_features` branches, building APKs for each with appropriate branch identification.

## Prerequisites

Before building the APK, ensure you have:

1. Flutter SDK installed (3.41.0 or later)
2. Android SDK properly configured with environment variables
3. A properly set up Flutter project
4. Git repository initialized (for branch detection)

## Building APK with Branch Details

The Joy Scroll project includes a script that automatically builds APKs with branch name and version information.

### Using the Build Script

1. Make sure the script is executable:
   ```bash
   chmod +x build_apk_with_branch.sh
   ```

2. Run the build script:
   ```bash
   ./build_apk_with_branch.sh
   ```

3. The script will:
   - Detect the current git branch
   - Get the latest commit hash
   - Extract version from pubspec.yaml
   - Build the APK with debug symbols
   - Rename the APK with branch and version details
   - Create a build information file

### APK Naming Convention

The built APK follows this naming convention:
```
joy_scroll-[version]-[branch_name]-[commit_hash].apk
```

Examples:
- `joy_scroll-1.0.0-main-a1b2c3d.apk` - Main branch build
- `joy_scroll-1.0.0-other_features-e5f6g7h.apk` - Feature branch build
- `joy_scroll-1.0.1-fix_ui_issues-i9j8k7l.apk` - Fix branch build

### Build Output

The script creates:
- APK file in `build/apk_output/` directory
- Build information text file in `build/apk_output/` directory
- Original debug APK in `build/app/outputs/flutter-apk/`

### Build Information

Each build includes:
- Branch name
- Commit hash
- App version from pubspec.yaml
- Build date and time
- Environment information
- Flutter version used for building

### GitHub Actions Integration

The project includes a GitHub Actions workflow that automatically:
- Builds APKs when code is pushed to `main` or `other_features` branches
- Embeds branch name, commit hash, and version in the APK filename
- Uploads the APK as an artifact to GitHub
- Creates releases for tagged commits

Workflow file: `.github/workflows/build_apk.yml`

### Manual Build Process

If you prefer to build manually without the script:

1. Get branch information:
   ```bash
   BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
   COMMIT_HASH=$(git rev-parse --short HEAD)
   VERSION=$(grep '^version:' pubspec.yaml | cut -d ' ' -f 2)
   ```

2. Build with Flutter:
   ```bash
   flutter build apk --debug \
     --dart-define=APP_BRANCH="$BRANCH_NAME" \
     --dart-define=APP_COMMIT="$COMMIT_HASH" \
     --dart-define=APP_VERSION="$VERSION-$BRANCH_NAME-$COMMIT_HASH"
   ```

3. Rename the APK with branch details:
   ```bash
   mv build/app/outputs/flutter-apk/app-debug.apk "joy_scroll-$VERSION-$BRANCH_NAME-$COMMIT_HASH.apk"
   ```

## Troubleshooting

### Common Issues

1. **"Flutter is not installed or not in PATH"**
   - Ensure Flutter is properly installed and added to your PATH
   - Run `flutter doctor` to verify the installation

2. **"Android SDK not found"**
   - Install Android Studio and SDK
   - Set ANDROID_HOME environment variable
   - Add Android tools to PATH

3. **"No connected devices"**
   - This is normal for APK building (not required for build process)
   - The script builds APK without needing a connected device

### Environment Variables

The build process defines these environment variables available in the app:
- `APP_BRANCH`: Current git branch name
- `APP_COMMIT`: Current commit hash
- `APP_VERSION`: Full version string with branch info
- `BUILD_DATE`: UTC timestamp of build

## Notes

- The script builds debug APKs by default (for testing)
- For production releases, use `flutter build apk --release`
- APKs built in GitHub Actions are available as artifacts
- Build artifacts are retained for 30 days in GitHub Actions
- The build script works on Unix-like systems (Linux/macOS)
- Currently configured for main and other_features branches
- Remote repository only has main branch, but local feature branches are supported