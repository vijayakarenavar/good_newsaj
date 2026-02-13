# Joy Scroll (Good News)

Joy Scroll is a Flutter-based mobile application that delivers positive, AI-transformed news content to users. The app combines traditional news consumption with social networking features, allowing users to engage with uplifting content and connect with friends.

## Features

- **AI-Powered News Curation**: Aggregates news from various sources and applies AI to transform negative/neutral stories into positive, constructive narratives
- **Multi-Tab Interface**: Video, News, Social, and Profile tabs with swipe navigation
- **Social Features**: Friend discovery, user-generated posts, like/comment functionality, and private messaging
- **Personalization & Accessibility**: Dual theme support, adjustable font sizing, and comprehensive accessibility features
- **Onboarding & User Engagement**: Category selection onboarding and reading history tracking

## Getting Started

### Prerequisites

- Flutter SDK (3.41.0 or later)
- Dart (3.11.0 or later)
- Android SDK (for building APKs)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/joy-scroll.git
   cd joy-scroll
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Create a `.env` file in the root directory with your API configuration:
   ```
   API_BASE_URL=https://your-api-url.com
   ```

4. Run the application:
   ```bash
   flutter run
   ```

## Building APK with Branch Details

This project includes automated APK building with branch and version information. See [APK_BUILDING_GUIDE.md](APK_BUILDING_GUIDE.md) for detailed instructions.

### Automated Builds
- GitHub Actions automatically builds APKs when code is pushed to `main` or `feature` branches
- APKs are named with format: `joy_scroll-[version]-[branch_name]-[commit_hash].apk`
- Build artifacts are available in GitHub Actions

### Manual Builds
Run the build script to create an APK with branch details:
```bash
chmod +x build_apk.sh
./build_apk.sh
```

## Project Structure

```
lib/
├── core/              # Core utilities, services, themes
├── features/          # Feature modules (authentication, articles, etc.)
├── widgets/           # Reusable UI components
└── main.dart          # Entry point
```

## Branch Information

- `main`: Production-ready code with comprehensive analysis
- `other_features`: Active development branch for new features

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the excellent framework
- All contributors who helped make this project possible