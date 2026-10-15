FONTS — PLACEHOLDER INSTRUCTIONS
=================================

The app uses Google Sans (Regular + Bold) declared in pubspec.yaml.

To add the real font files:
  1. Download from https://fonts.google.com/specimen/Google+Sans
     or use the free alternative "Nunito" / "Poppins" which look identical.

  2. Place the files here as:
       assets/fonts/GoogleSans-Regular.ttf
       assets/fonts/GoogleSans-Bold.ttf

  3. Run: flutter pub get

Alternatively, swap to a Google Fonts package font (already in pubspec.yaml):
  In lib/core/theme/app_theme.dart, replace the fontFamily references with
  any font from the `google_fonts` package — no local files needed.
  Example: GoogleFonts.poppinsTextTheme() or GoogleFonts.nunitoTextTheme()
