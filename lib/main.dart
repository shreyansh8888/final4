import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/settings_provider.dart' show languageProvider;
import 'core/services/storage_service.dart';
import 'core/services/firebase_service.dart';
import 'navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await _initApp();

  runApp(
    const ProviderScope(
      child: GarbaApp(),
    ),
  );
}

Future<void> _initApp() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize your Firebase service
  await FirebaseService.initialize();

  // Initialize local storage
  await StorageService.init();
}

class GarbaApp extends ConsumerWidget {
  const GarbaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final lang = ref.watch(languageProvider);

    return MaterialApp.router(
      title: 'Garba App',
      debugShowCheckedModeBanner: false,
      locale: Locale(lang),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: AppTheme.light(lang),
      darkTheme: AppTheme.dark(lang),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}