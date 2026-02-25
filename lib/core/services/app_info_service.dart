import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppInfoService {

  /// Get dynamic app version from pubspec.yaml
  static Future<String> getAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  /// Clear app cache (keep login/session data)
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final keysToRemove = <String>[];

      for (final key in prefs.getKeys()) {
        if (key.startsWith('cache_') ||
            key.startsWith('temp_') ||
            key.contains('image_cache') ||
            key.contains('articles_cache') ||
            key.contains('categories_cache')) {
          keysToRemove.add(key);
        }
      }

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
    } catch (_) {
      // Silent fail - cache clearing is not critical
    }
  }

  /// Open Privacy Policy URL
  static Future<void> openPrivacyPolicy() async {
    const url = 'https://goodnewsapp.lemmecode.com/privacy';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Open Play Store page for rating app
  static Future<void> openPlayStore() async {
    const androidUrl =
        'https://play.google.com/store/apps/details?id=com.joyscroll.app';

    final uri = Uri.parse(androidUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}