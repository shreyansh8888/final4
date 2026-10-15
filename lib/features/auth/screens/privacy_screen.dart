import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Policy"),
        centerTitle: true,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: SelectableText(
          '''
PRIVACY POLICY

Last Updated: July 2026

Welcome to Garba Verse.

Your privacy is important to us. This Privacy Policy explains how Garba Verse collects, uses, and protects your information when you use our application.

1. Information We Collect

Depending on the features you use, Garba Verse may collect:

• Basic device information (Android version, device model).
• Crash logs and diagnostic information.
• App usage statistics.
• Information you voluntarily provide.

Garba Verse does not intentionally collect sensitive personal information unless required for a specific feature.

2. Camera Access

If you use features that require the camera (such as dance practice or AI pose detection), camera permission is requested.

Camera frames are processed only for providing the feature.

Garba Verse does not record or store your camera footage unless explicitly stated.

3. Storage Permission

Storage permission may be used to:

• Save downloaded content.
• Cache app resources.
• Store user preferences.

The app never accesses unrelated files on your device.

4. Internet Access

Garba Verse requires an internet connection for:

• Downloading updates.
• Loading online content.
• Accessing cloud services.
• Bug reporting and analytics.

5. Analytics

We may collect anonymous analytics to improve the application.

This may include:

• App version
• Device type
• Screen usage
• Crash reports

These analytics do not personally identify you.

6. Third-Party Services

Garba Verse may use trusted third-party services including:

• Firebase
• Google Play Services
• Vercel-hosted resources

These services have their own privacy policies.

7. Data Security

We take reasonable security measures to protect user information.

However, no internet transmission or electronic storage method is completely secure.

8. Children's Privacy

Garba Verse is not intended for children under 13 years of age.

We do not knowingly collect personal information from children.

9. Your Rights

You may:

• Request deletion of your data (where applicable).
• Contact us regarding privacy concerns.
• Stop using the application at any time.

10. Changes to this Policy

This Privacy Policy may be updated periodically.

Changes become effective immediately after publication within the app or on our website.

11. Contact Us

If you have any questions regarding this Privacy Policy, please contact us using the support information provided within Garba Verse.

By using Garba Verse, you agree to this Privacy Policy.
''',
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}