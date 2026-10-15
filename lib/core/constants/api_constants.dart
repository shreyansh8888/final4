// API endpoint constants
class ApiConstants {
  ApiConstants._();

  // Change this to your backend server URL
  static const String baseUrl = 'http://localhost:8000';

  // Auth Endpoints
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String refreshToken = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';

  // User Endpoints
  static const String profile = '/api/users/me';
  static const String updateProfile = '/api/users/me';
  static const String deleteAccount = '/api/users/me';
  static const String uploadPhoto = '/api/users/me/photo';

  // Event Endpoints
  static const String events = '/api/events';
  static const String eventDetail = '/api/events/'; // + id
  static const String searchEvents = '/api/events/search';

  // Booking Endpoints
  static const String bookTicket = '/api/bookings';
  static const String myBookings = '/api/bookings/my';
  static const String cancelBooking = '/api/bookings/'; // + id + /cancel
  static const String ticketDetail = '/api/bookings/'; // + id

  // Admin Endpoints
  static const String adminDashboard = '/api/admin/dashboard';
  static const String adminUsers = '/api/admin/users';
  static const String adminEvents = '/api/admin/events';
  static const String adminBookings = '/api/admin/bookings';
  static const String createEvent = '/api/admin/events';
  static const String updateEvent = '/api/admin/events/'; // + id
  static const String deleteEvent = '/api/admin/events/'; // + id

  // AI Trainer Endpoints
  static const String aiUploadVideo = '/api/ai/upload-video';
  static const String aiLiveAnalysis = '/api/ai/live-analysis';
  static const String aiGetScore = '/api/ai/get-score';
  static const String aiGetReport = '/api/ai/get-report';
  static const String performanceHistory = '/api/ai/performance/history';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 60);
}
