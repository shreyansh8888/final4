import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../stats/providers/stats_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl.text = user?.name ?? '';
    _phoneCtrl.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) setState(() => _pickedImage = File(img.path));
  }

  Future<void> _saveProfile() async {
    await ref.read(authProvider.notifier).updateProfile(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
        );
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(userStatsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Profile')),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _editing = !_editing),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            GestureDetector(
              onTap: _editing ? _pickPhoto : null,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!) as ImageProvider
                        : user?.photo != null
                            ? CachedNetworkImageProvider(user!.photo!)
                            : null,
                    child: _pickedImage == null && user?.photo == null
                        ? Text(
                            user?.name.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : 'G',
                            style: const TextStyle(
                                fontSize: 40, color: AppColors.primary),
                          )
                        : null,
                  ),
                  if (_editing)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_editing) ...[
              Text(
                user?.name ?? '—',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '—',
                style: const TextStyle(color: Colors.grey),
              ),
              if (user?.phone != null && user!.phone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(user.phone!,
                    style: const TextStyle(color: Colors.grey)),
              ],
              const SizedBox(height: 8),
              if (user?.isAdmin == true)
                Chip(
                  label: Text(context.tr('Admin')),
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                  avatar: const Icon(Icons.admin_panel_settings,
                      size: 16, color: AppColors.secondary),
                ),
            ] else ...[
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                    labelText: context.tr('Full Name'),
                    prefixIcon: const Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    labelText: context.tr('Phone'),
                    prefixIcon: const Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveProfile,
                child: Text(context.tr('Save Changes')),
              ),
            ],
            const SizedBox(height: 28),
            // Stats Row
            Row(
              children: [
                _StatCard(
                    label: context.tr('Events\nBooked'),
                    value: stats == null ? '–' : '${stats.eventsBooked}'),
                const SizedBox(width: 12),
                _StatCard(
                    label: context.tr('Practice\nSessions'),
                    value: stats == null ? '–' : '${stats.sessions}'),
                const SizedBox(width: 12),
                _StatCard(
                    label: context.tr('Best\nAccuracy'),
                    value: stats == null
                        ? '–'
                        : '${stats.bestAccuracy.toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 24),
            // Menu items
            if (user?.isAdmin == true)
              _ProfileMenuItem(
                icon: Icons.admin_panel_settings_outlined,
                label: context.tr('Admin Console'),
                color: AppColors.secondary,
                onTap: () => context.push(AppRoutes.adminDashboard),
              ),
            _ProfileMenuItem(
                icon: Icons.confirmation_number_outlined,
                label: context.tr('My Bookings'),
                onTap: () => context.push(AppRoutes.myBookings)),
            _ProfileMenuItem(
                icon: Icons.insights_outlined,
                label: context.tr('Performance Reports'),
                onTap: () => context.push(AppRoutes.reports)),
            _ProfileMenuItem(
                icon: Icons.emoji_events_outlined,
                label: context.tr('Achievements'),
                onTap: () => context.push(AppRoutes.achievements)),
            _ProfileMenuItem(
                icon: Icons.leaderboard_outlined,
                label: context.tr('Leaderboard'),
                onTap: () => context.push(AppRoutes.leaderboard)),
            _ProfileMenuItem(
                icon: Icons.settings_outlined,
                label: context.tr('Settings'),
                onTap: () => context.push(AppRoutes.settings)),
            const Divider(),
            _ProfileMenuItem(
              icon: Icons.logout,
              label: context.tr('Logout'),
              color: AppColors.error,
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go(AppRoutes.login);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: Icon(icon, color: color ?? AppColors.primary),
      title: Text(label,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }
}
