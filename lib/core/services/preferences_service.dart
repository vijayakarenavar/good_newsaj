import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PreferencesService {
  static SharedPreferences? _prefs;
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Secure keys — token aani sensitive data
  static const _keyToken = 'user_token';
  static const _keyFCMToken = 'fcm_token';

  // Non-sensitive keys — SharedPreferences madhe rahil
  static const _keyUserId = 'user_id';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyIsLoggedIn = 'is_logged_in';
  static const _keyOnboarding = 'onboarding_completed';
  static const _keyCategories = 'selected_categories';

  static Future<void> saveFCMToken(String token) async {
    await _secure.write(key: _keyFCMToken, value: token);
  }

  static Future<String?> getFCMToken() async {
    return await _secure.read(key: _keyFCMToken);
  }

  static Future<void> saveUserData({
    required String token,
    required int userId,
    required String name,
    required String email,
  }) async {
    await _init();
    // Token — secure storage madhe
    await _secure.write(key: _keyToken, value: token);
    // Baaki info — SharedPreferences madhe (sensitive nahi)
    await _prefs!.setInt(_keyUserId, userId);
    await _prefs!.setString(_keyUserName, name);
    await _prefs!.setString(_keyUserEmail, email);
    await _prefs!.setBool(_keyIsLoggedIn, true);
  }

  static Future<String?> getUserToken() async {
    return await _secure.read(key: _keyToken);
  }

  static Future<String?> getToken() async {
    return await getUserToken();
  }

  static Future<String?> getAuthToken() async {
    return await getUserToken();
  }

  static Future<String?> getUserDisplayName() async {
    await _init();
    return _prefs!.getString(_keyUserName);
  }

  static Future<String?> getUserEmail() async {
    await _init();
    return _prefs!.getString(_keyUserEmail);
  }

  static Future<int?> getUserId() async {
    await _init();
    return _prefs!.getInt(_keyUserId);
  }

  static Future<bool> isLoggedIn() async {
    await _init();
    return _prefs!.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<void> setOnboardingCompleted(bool completed) async {
    await _init();
    await _prefs!.setBool(_keyOnboarding, completed);
  }

  static Future<bool> isOnboardingCompleted() async {
    await _init();
    return _prefs!.getBool(_keyOnboarding) ?? false;
  }

  static Future<void> saveSelectedCategories(List<int> categoryIds) async {
    await _init();
    await _prefs!.setStringList(
      _keyCategories,
      categoryIds.map((e) => e.toString()).toList(),
    );
  }

  static Future<List<int>> getSelectedCategories() async {
    await _init();
    final categories = _prefs!.getStringList(_keyCategories) ?? [];
    return categories.map((e) => int.parse(e)).toList();
  }

  static Future<void> saveLikedPost(int postId) async {
    await _init();
    final userId = await getUserId();
    if (userId == null) return;
    final key = 'liked_posts_$userId';
    final likedPosts = await getLikedPosts();
    if (!likedPosts.contains(postId)) {
      likedPosts.add(postId);
      await _prefs!.setStringList(
        key,
        likedPosts.map((e) => e.toString()).toList(),
      );
    }
  }

  static Future<void> removeLikedPost(int postId) async {
    await _init();
    final userId = await getUserId();
    if (userId == null) return;
    final key = 'liked_posts_$userId';
    final likedPosts = await getLikedPosts();
    likedPosts.remove(postId);
    await _prefs!.setStringList(
      key,
      likedPosts.map((e) => e.toString()).toList(),
    );
  }

  static Future<List<int>> getLikedPosts() async {
    await _init();
    final userId = await getUserId();
    if (userId == null) return [];
    final key = 'liked_posts_$userId';
    final list = _prefs!.getStringList(key) ?? [];
    return list
        .map((e) => int.tryParse(e))
        .where((e) => e != null)
        .map((e) => e!)
        .toList();
  }

  static Future<bool> isPostLiked(int postId) async {
    final liked = await getLikedPosts();
    return liked.contains(postId);
  }

  static Future<void> clearLikedPosts() async {
    await _init();
    final userId = await getUserId();
    if (userId == null) return;
    await _prefs!.remove('liked_posts_$userId');
  }

  static Future<void> clearToken() async {
    await _secure.delete(key: _keyToken);
  }

  static Future<void> clearUserData() async {
    await _init();
    await _prefs!.remove(_keyUserId);
    await _prefs!.remove(_keyUserName);
    await _prefs!.remove(_keyUserEmail);
    await _prefs!.remove(_keyIsLoggedIn);
  }

  static Future<void> logout() async {
    await _init();
    await clearLikedPosts();
    // Secure storage madhe je ahe te delete karo
    await _secure.deleteAll();
    // SharedPreferences clear karo
    await _prefs!.clear();
  }

  static Future<bool?> getBool(String key) async {
    await _init();
    return _prefs!.getBool(key);
  }

  static Future<bool> setBool(String key, bool value) async {
    await _init();
    return await _prefs!.setBool(key, value);
  }

  static Future<int?> getInt(String key) async {
    await _init();
    return _prefs!.getInt(key);
  }

  static Future<void> setInt(String key, int value) async {
    await _init();
    await _prefs!.setInt(key, value);
  }

  static Future<double?> getDouble(String key) async {
    await _init();
    return _prefs!.getDouble(key);
  }

  static Future<bool> setDouble(String key, double value) async {
    await _init();
    return await _prefs!.setDouble(key, value);
  }
}