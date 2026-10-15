import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';

export '../../../core/theme/app_theme.dart' show themeModeProvider, ThemeModeNotifier;

// ─── Language ──────────────────────────────────────────────────────────────
class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super(StorageService.getLanguage());

  Future<void> setLanguage(String code) async {
    await StorageService.setLanguage(code);
    state = code;
  }
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, String>((_) => LanguageNotifier());

// ─── Push notifications ─────────────────────────────────────────────────────
class PushNotificationsNotifier extends StateNotifier<bool> {
  PushNotificationsNotifier() : super(StorageService.getPushNotifications());

  Future<void> toggle(bool value) async {
    await StorageService.setPushNotifications(value);
    state = value;
  }
}

final pushNotificationsProvider =
    StateNotifierProvider<PushNotificationsNotifier, bool>(
        (_) => PushNotificationsNotifier());

// ─── Email notifications ────────────────────────────────────────────────────
class EmailNotificationsNotifier extends StateNotifier<bool> {
  EmailNotificationsNotifier() : super(StorageService.getEmailNotifications());

  Future<void> toggle(bool value) async {
    await StorageService.setEmailNotifications(value);
    state = value;
  }
}

final emailNotificationsProvider =
    StateNotifierProvider<EmailNotificationsNotifier, bool>(
        (_) => EmailNotificationsNotifier());
