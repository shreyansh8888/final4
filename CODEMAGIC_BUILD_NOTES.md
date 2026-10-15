# Codemagic build notes

This package preserves the app source and features. Only Android CI/build configuration was adjusted:
- Android Gradle Plugin set to 8.10.1 and Gradle wrapper to 8.11.1 (API 36 capable toolchain).
- Kotlin Android plugin explicitly applied to the app module.
- Removed an AGP-internal `BaseExtension` compileSdk override that can break builds; app compileSdk remains 36.
- Dart analysis is diagnostic in Codemagic; `flutter build apk --release --split-per-abi` remains the required build step.

Firebase configuration is preserved. Firebase Phone OTP requires the signing certificate SHA-1/SHA-256 registered in the Firebase console.

## Update: Gradle fix
- Gradle wrapper -> 8.14.3 (Flutter requires >= 8.14.0), AGP -> 8.11.1, Kotlin -> 2.2.20.
- Removed AGP-9-only flags (`android.newDsl`, `android.builtInKotlin`) from gradle.properties.
- Build with the `codemagic.yaml` workflow (APK). If you use the Codemagic UI workflow instead, choose Android + APK, not "appbundle --debug".
