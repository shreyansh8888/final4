import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Handles secure JWT storage and regular preferences.
class StorageService {
  StorageService._();

  static late SharedPreferences _prefs;
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── JWT ────────────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) =>
      _secure.write(key: AppConstants.keyJwtToken, value: token);

  static Future<String?> getToken() =>
      _secure.read(key: AppConstants.keyJwtToken);

  static Future<void> saveRefreshToken(String token) =>
      _secure.write(key: AppConstants.keyRefreshToken, value: token);

  static Future<String?> getRefreshToken() =>
      _secure.read(key: AppConstants.keyRefreshToken);

  static Future<void> deleteToken() =>
      _secure.delete(key: AppConstants.keyJwtToken);

  // ─── User metadata (non-sensitive) ──────────────────────────────────────────
  static Future<void> saveUserId(String id) =>
      _prefs.setString(AppConstants.keyUserId, id);

  static String? getUserId() => _prefs.getString(AppConstants.keyUserId);

  static Future<void> saveUserEmail(String email) =>
      _prefs.setString(AppConstants.keyUserEmail, email);

  static String? getUserEmail() =>
      _prefs.getString(AppConstants.keyUserEmail);

  // ─── Onboarding ─────────────────────────────────────────────────────────────
  static Future<void> setOnboardingDone() =>
      _prefs.setBool(AppConstants.keyOnboardingDone, true);

  static bool isOnboardingDone() =>
      _prefs.getBool(AppConstants.keyOnboardingDone) ?? false;

  // ─── Language ────────────────────────────────────────────────────────────────
  static Future<void> setLanguage(String code) =>
      _prefs.setString(AppConstants.keySelectedLanguage, code);

  static String getLanguage() =>
      _prefs.getString(AppConstants.keySelectedLanguage) ?? 'en';

  // ─── Notification preferences ───────────────────────────────────────────────
  static Future<void> setPushNotifications(bool value) =>
      _prefs.setBool(AppConstants.keyPushNotifications, value);

  static bool getPushNotifications() =>
      _prefs.getBool(AppConstants.keyPushNotifications) ?? true;

  static Future<void> setEmailNotifications(bool value) =>
      _prefs.setBool(AppConstants.keyEmailNotifications, value);

  static bool getEmailNotifications() =>
      _prefs.getBool(AppConstants.keyEmailNotifications) ?? true;

  // ─── Theme Mode ─────────────────────────────────────────────────────────────
  static Future<void> setThemeMode(String mode) =>
      _prefs.setString(AppConstants.keyThemeMode, mode);

  static String getThemeMode() =>
      _prefs.getString(AppConstants.keyThemeMode) ?? 'light';

  // ─── Clear all (logout) ──────────────────────────────────────────────────────
  static Future<void> clearAll() async {
    await _secure.deleteAll();
    await _prefs.clear();
  }

  // ─── Auth check ─────────────────────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}