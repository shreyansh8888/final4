import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/storage_service.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/phone_otp_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/events/screens/events_list_screen.dart';
import '../features/events/screens/event_details_screen.dart';
import '../features/booking/screens/book_ticket_screen.dart';
import '../features/booking/screens/my_bookings_screen.dart';
import '../features/booking/screens/qr_ticket_screen.dart';
import '../features/ai_trainer/screens/ai_trainer_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/achievements/screens/achievements_screen.dart';
import '../features/leaderboard/screens/leaderboard_screen.dart';
import '../features/reports/screens/performance_reports_screen.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/admin_event_editor_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const phoneOtp = '/phone-otp';
  static const verifyEmail = '/verify-email';
  static const home = '/home';
  static const events = '/events';
  static const eventDetails = '/events/:id';
  static const bookTicket = '/events/:id/book';
  static const myBookings = '/my-bookings';
  static const qrTicket = '/ticket/:id';
  static const aiTrainer = '/ai-trainer';
  static const profile = '/profile';
  static const settings = '/settings';
  static const achievements = '/achievements';
  static const leaderboard = '/leaderboard';
  static const reports = '/reports';
  static const adminDashboard = '/admin';
  static const adminEditEvent = '/admin/events/edit';
}

/// Bridges a Stream (Firebase auth state changes) to something
/// GoRouter's `refreshListenable` can listen to, so the router
/// automatically re-evaluates redirects whenever auth state changes
/// (login, logout, signup) -- no manual context.go() needed.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable:
        GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    redirect: (context, state) {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final isLoggedIn = firebaseUser != null;
      final isOnboarded = StorageService.isOnboardingDone();

      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.phoneOtp;

      final isVerifyEmailRoute =
          state.matchedLocation == AppRoutes.verifyEmail;

      if (state.matchedLocation == AppRoutes.splash) return null;

      if (!isOnboarded) return AppRoutes.onboarding;
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;

      // Only email/password users have a non-null `email` on the
      // FirebaseUser. Phone-auth users are left alone here.
      final needsEmailVerification = isLoggedIn &&
          firebaseUser!.email != null &&
          !firebaseUser.emailVerified;

      if (needsEmailVerification && !isVerifyEmailRoute && !isAuthRoute) {
        return AppRoutes.verifyEmail;
      }

      final isAdminRoute =
          state.matchedLocation.startsWith(AppRoutes.adminDashboard);

      if (isAdminRoute) {
        if (!isLoggedIn) return AppRoutes.login;
        final user = ref.read(currentUserProvider);
        if (user?.isAdmin != true) return AppRoutes.home;
      }

      if (isLoggedIn && !needsEmailVerification &&
          (isAuthRoute || isVerifyEmailRoute)) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.phoneOtp,
        builder: (_, __) => const PhoneOtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, __) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.events,
        builder: (_, __) => const EventsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.eventDetails,
        builder: (context, state) => EventDetailsScreen(
          eventId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.bookTicket,
        builder: (context, state) => BookTicketScreen(
          eventId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.myBookings,
        builder: (_, __) => const MyBookingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.qrTicket,
        builder: (context, state) => QrTicketScreen(
          bookingId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.aiTrainer,
        builder: (_, __) => const AiTrainerScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        builder: (_, __) => const AchievementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        builder: (_, __) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (_, __) => const PerformanceReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminEditEvent,
        builder: (context, state) => AdminEventEditorScreen(
          eventId: state.uri.queryParameters['id'],
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});