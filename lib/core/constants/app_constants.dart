// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Garba App';
  static const String appVersion = '1.0.0';

  // Shared Preferences Keys
  static const String keyJwtToken = 'jwt_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyThemeMode = 'theme_mode';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keySelectedLanguage = 'selected_language';
  static const String keyPushNotifications = 'push_notifications_enabled';
  static const String keyEmailNotifications = 'email_notifications_enabled';

  // Supported Languages
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'gu', 'name': 'ગુજરાતી (Gujarati)'},
  ];

  // Garba Step Names
  static const List<String> garbaSteps = [
    'Basic Step',
    'Two Clap',
    'Three Clap',
    'Dodhiya',
    'Hinch',
    'Simple Spin',
  ];

  // Performance Grades
  static const Map<String, String> gradeThresholds = {
    'A+': '95',
    'A': '90',
    'B+': '80',
    'B': '70',
    'C': '60',
    'D': '50',
  };

  // Booking Status
  static const String statusConfirmed = 'confirmed';
  static const String statusCancelled = 'cancelled';
  static const String statusPending = 'pending';

  // Pagination
  static const int defaultPageSize = 10;

  // AI Trainer
  static const int aiFrameCaptureInterval = 500; // ms
  static const double similarityThreshold = 0.75;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
}