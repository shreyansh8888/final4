import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../navigation/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../../auth/screens/privacy_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final lang = ref.watch(languageProvider);
    final pushEnabled = ref.watch(pushNotificationsProvider);
    final emailEnabled = ref.watch(emailNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Settings'))),
      body: ListView(
        children: [
          // Appearance
          const _SectionHeader('Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(context.tr('Dark Mode')),
            value: isDark,
            onChanged: (_) =>
                ref.read(themeModeProvider.notifier).toggleTheme(),
            activeThumbColor: AppColors.primary,
          ),
          // Language
          const _SectionHeader('Language'),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.tr('App Language')),
            trailing: DropdownButton<String>(
              value: lang,
              underline: const SizedBox.shrink(),
              items: AppConstants.supportedLanguages
                  .map((l) => DropdownMenuItem(
                        value: l['code'],
                        child: Text(l['name']!),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(languageProvider.notifier).setLanguage(v);
                }
              },
            ),
          ),
          // Notifications
          const _SectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(context.tr('Push Notifications')),
            subtitle: Text(context.tr('Event reminders and updates')),
            value: pushEnabled,
            onChanged: (v) =>
                ref.read(pushNotificationsProvider.notifier).toggle(v),
            activeThumbColor: AppColors.primary,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.email_outlined),
            title: Text(context.tr('Email Notifications')),
            subtitle: Text(context.tr('Booking confirmations')),
            value: emailEnabled,
            onChanged: (v) =>
                ref.read(emailNotificationsProvider.notifier).toggle(v),
            activeThumbColor: AppColors.primary,
          ),
          // AI Trainer
          const _SectionHeader('AI Trainer'),
          ListTile(
            leading: const Icon(Icons.speed),
            title: Text(context.tr('Analysis Frequency')),
            subtitle: Text(context.tr('How often frames are analysed')),
            trailing: const Text('500ms',
                style: TextStyle(color: AppColors.primary)),
            onTap: () {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(context.tr('Voice Feedback')),
            subtitle: Text(context.tr('Spoken corrections during training')),
            value: false,
            onChanged: (_) {},
            activeThumbColor: AppColors.primary,
          ),
          // Account
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(context.tr('Change Password')),
            subtitle: Text(context.tr('Sends a reset link to your email')),
            trailing:
                const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.push(AppRoutes.forgotPassword),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(context.tr('Privacy Policy')),
            trailing:
                const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.tr('About')),
            subtitle: const Text('Garba App v${AppConstants.appVersion}'),
            onTap: () {},
          ),
          const Divider(),
          // Danger zone
          const _SectionHeader('Danger Zone'),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.error),
            title: Text(context.tr('Delete Account'),
                style: const TextStyle(color: AppColors.error)),
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: Text(context.tr('Logout'),
                style: const TextStyle(color: AppColors.error)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Delete Account?')),
        content: Text(
          context.tr('This will permanently delete your account and all associated data. This action cannot be undone.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    // Show a loading indicator while deletion happens
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(authProvider.notifier).deleteAccount();
      if (!context.mounted) return;
      Navigator.pop(context); // close loading dialog
      context.go(AppRoutes.login);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        context.tr(title).toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}