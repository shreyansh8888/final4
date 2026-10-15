import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../events/providers/events_provider.dart';
import '../../events/screens/events_list_screen.dart';
import '../../booking/screens/my_bookings_screen.dart';
import '../../ai_trainer/screens/ai_trainer_screen.dart';
import '../../profile/screens/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> get _pages => [
        const _HomeTab(),
        const EventsListScreen(),
        const MyBookingsScreen(),
        // Only built while selected, so the camera is released on leaving.
        _selectedIndex == 3 ? const AiTrainerScreen() : const SizedBox.shrink(),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: context.tr('Home')),
          NavigationDestination(icon: const Icon(Icons.event_outlined), selectedIcon: const Icon(Icons.event), label: context.tr('Events')),
          NavigationDestination(icon: const Icon(Icons.confirmation_number_outlined), selectedIcon: const Icon(Icons.confirmation_number), label: context.tr('Tickets')),
          NavigationDestination(icon: const Icon(Icons.fitness_center_outlined), selectedIcon: const Icon(Icons.fitness_center), label: context.tr('AI Trainer')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: context.tr('Profile')),
        ],
      ),
    );
  }
}

/// The actual home tab content
class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      drawer: _AppDrawer(),
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.festiveGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          context.tr('Jai Mataji!') + ' 🙏',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user != null ? '${context.tr('Hello')}, ${user.name.split(' ').first}!' : context.tr('Welcome!'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions
                  Row(
                    children: [
                      _QuickAction(icon: Icons.event_rounded, label: context.tr('Events'), color: AppColors.primary, onTap: () => context.push(AppRoutes.events)),
                      const SizedBox(width: 12),
                      _QuickAction(icon: Icons.confirmation_number_rounded, label: context.tr('My Tickets'), color: AppColors.secondary, onTap: () => context.push(AppRoutes.myBookings)),
                      const SizedBox(width: 12),
                      _QuickAction(icon: Icons.fitness_center_rounded, label: context.tr('AI Trainer'), color: AppColors.accent, onTap: () => context.push(AppRoutes.aiTrainer)),
                      const SizedBox(width: 12),
                      _QuickAction(icon: Icons.leaderboard_rounded, label: context.tr('Leaderboard'), color: AppColors.info, onTap: () => context.push(AppRoutes.leaderboard)),
                    ],
                  ).animate().fade().slideY(begin: 0.2),
                  const SizedBox(height: 28),
                  // Upcoming Events
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('Upcoming Events'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                          onPressed: () => context.push(AppRoutes.events),
                          child: Text(context.tr('See all'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Events horizontal list
          SliverToBoxAdapter(
            child: SizedBox(
              height: 280,
              child: eventsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (events) => ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: events.take(5).length,
                  itemBuilder: (_, i) {
                    final event = events[i];
                    return GestureDetector(
                      onTap: () => context.push('/events/${event.id}'),
                      child: Container(
                        width: 220,
                        margin: const EdgeInsets.only(right: 16),
                        child: Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 120,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.festiveGradient,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: const Center(
                                  child: Icon(Icons.music_note_rounded, color: Colors.white, size: 48),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(event.venue, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 8),
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Text('₹${event.price.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                      const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                    ]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate(delay: (i * 80).ms).fade().slideX(begin: 0.2),
                    );
                  },
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          // AI Trainer promo
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentDark]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 48),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('AI Garba Trainer'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(context.tr('Get real-time pose feedback'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => context.push(AppRoutes.aiTrainer),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.accent, minimumSize: const Size(100, 36)),
                            child: Text(context.tr('Start Now')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fade().scale(begin: const Offset(0.95, 0.95)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: AppColors.festiveGradient,
            ),
            accountName: Text(user?.name ?? context.tr('User')),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'G',
                style: const TextStyle(fontSize: 24, color: AppColors.primary),
              ),
            ),
          ),
          ListTile(leading: const Icon(Icons.home), title: Text(context.tr('Home')), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.event), title: Text(context.tr('Events')), onTap: () { Navigator.pop(context); context.push(AppRoutes.events); }),
          ListTile(leading: const Icon(Icons.confirmation_number), title: Text(context.tr('My Bookings')), onTap: () { Navigator.pop(context); context.push(AppRoutes.myBookings); }),
          ListTile(leading: const Icon(Icons.fitness_center), title: Text(context.tr('AI Trainer')), onTap: () { Navigator.pop(context); context.push(AppRoutes.aiTrainer); }),
          ListTile(leading: const Icon(Icons.person), title: Text(context.tr('Profile')), onTap: () { Navigator.pop(context); context.push(AppRoutes.profile); }),
          ListTile(leading: const Icon(Icons.settings), title: Text(context.tr('Settings')), onTap: () { Navigator.pop(context); context.push(AppRoutes.settings); }),
          if (user?.isAdmin == true)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: AppColors.secondary),
              title: Text(context.tr('Admin Console')),
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.adminDashboard);
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: Text(context.tr('Logout'), style: const TextStyle(color: AppColors.error)),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }
}