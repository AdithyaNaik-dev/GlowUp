import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/theme.dart';
import '../main.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  // ── Constants ──
  static const _appVersion = 'Beta 1.0.0';
  static const _packageName = 'com.adithya.glowup';
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=$_packageName';
  static const _feedbackEmail = 'support@glowupapp.com';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customize your app experience',
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withAlpha(160),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),

            // ── Appearance ──
            _sectionTitle('Appearance'),
            const SizedBox(height: 14),
            ListenableBuilder(
              listenable: themeNotifier,
              builder: (context, _) {
                return Column(
                  children: [
                    _buildThemeOption(
                      context,
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      subtitle: 'Dark background with light text',
                      isSelected: themeNotifier.isDarkMode,
                      onTap: () => themeNotifier.setThemeMode(ThemeMode.dark),
                    ),
                    const SizedBox(height: 12),
                    _buildThemeOption(
                      context,
                      icon: Icons.light_mode_rounded,
                      title: 'Light Mode',
                      subtitle: 'Light background with dark text',
                      isSelected: !themeNotifier.isDarkMode,
                      onTap: () => themeNotifier.setThemeMode(ThemeMode.light),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // ── Account ──
            _sectionTitle('Account'),
            const SizedBox(height: 14),
            _buildAccountSection(context),
            const SizedBox(height: 32),

            // ── Support Us ──
            _sectionTitle('Support us'),
            const SizedBox(height: 14),
            _supportCard(context, [
              _supportTile(
                context,
                icon: Icons.ios_share_rounded,
                label: 'Share App',
                onTap: () => _shareApp(),
              ),
              _divider(context),
              _supportTile(
                context,
                icon: Icons.thumb_up_outlined,
                label: 'Rate us',
                onTap: () => _rateApp(context),
              ),
              _divider(context),
              _supportTile(
                context,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Feedback',
                onTap: () => _sendFeedback(),
              ),
              _divider(context),
              _supportTile(
                context,
                icon: Icons.description_outlined,
                label: 'Privacy Policy',
                onTap: () => _openPrivacyPolicy(context),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Danger Zone ──
            _supportCard(context, [
              _supportTile(
                context,
                icon: Icons.delete_outline_rounded,
                label: 'Delete all data',
                iconColor: AppColors.primary,
                textColor: AppColors.primary,
                onTap: () => _confirmDeleteAll(context),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Version ──
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Text(
                  'Version ${SettingsScreen._appVersion}',
                  style: TextStyle(
                    color: context.appTextHint,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ────────────────────────── Section Helpers ──────────────────────────

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    );
  }

  Widget _supportCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 60,
      color: Theme.of(context).dividerColor,
    );
  }

  Widget _supportTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final effectiveIconColor = iconColor ?? AppColors.secondary;
    final effectiveTextColor = textColor ?? Theme.of(context).textTheme.bodyLarge?.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: effectiveIconColor, size: 24),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: effectiveTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appTextHint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────── Account Section ──────────────────────────

  Widget _buildAccountSection(BuildContext context) {
    final authService = AuthService();
    final isSignedIn = authService.isSignedIn;

    if (isSignedIn) {
      return _supportCard(context, [
        // User info row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withAlpha(25),
                child: Text(
                  authService.displayName.isNotEmpty
                      ? authService.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authService.displayName.isNotEmpty
                          ? authService.displayName
                          : 'User',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (authService.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        authService.email,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.verified_rounded,
                color: AppColors.success,
                size: 22,
              ),
            ],
          ),
        ),
        _divider(context),
        _supportTile(
          context,
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          onTap: () => _confirmSignOut(context),
        ),
        _divider(context),
        _supportTile(
          context,
          icon: Icons.person_remove_outlined,
          label: 'Delete Account',
          iconColor: AppColors.primary,
          textColor: AppColors.primary,
          onTap: () => _confirmDeleteAccount(context),
        ),
      ]);
    } else {
      return _supportCard(context, [
        _supportTile(
          context,
          icon: Icons.login_rounded,
          label: 'Sign In',
          iconColor: AppColors.success,
          onTap: () => _navigateToSignIn(context),
        ),
      ]);
    }
  }

  // ────────────────────────── Actions ──────────────────────────

  void _shareApp() {
    SharePlus.instance.share(
      ShareParams(
        text: 'Check out GlowUp — 30 Day Glow Up Challenge!\n${SettingsScreen._playStoreUrl}',
      ),
    );
  }

  void _rateApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _RateUsDialog(),
    );
  }

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: SettingsScreen._feedbackEmail,
      queryParameters: {
        'subject': 'GlowUp App Feedback',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openPrivacyPolicy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete all data?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will reset all your progress, streaks, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.appTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await DataService().clearAllData();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const OnboardingScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── Auth Actions ──────────────────────────

  void _navigateToSignIn(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    ).then((_) {
      // Refresh UI after returning from auth screen
      if (mounted) setState(() {});
    });
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'You can sign back in anytime. Your local progress will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.appTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService().signOut();
              await DataService().clearAuthState();
              if (context.mounted && mounted) setState(() {});
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text(
              'Delete Account?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete your account and all associated data. '
          'Your local progress will also be erased.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.appTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _executeDeleteAccount(context);
            },
            child: const Text(
              'Delete Forever',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAccount(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      await AuthService().deleteAccount();
      await DataService().clearAllData();
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthService.friendlyError(e)),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete account. Please try again.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(20)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withAlpha(30)
                    : Theme.of(context).dividerColor.withAlpha(60),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textHint,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(140),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textHint,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 18)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Rate Us Dialog — custom star-rating popup
// ══════════════════════════════════════════════════════════════════════

class _RateUsDialog extends StatefulWidget {
  const _RateUsDialog();

  @override
  State<_RateUsDialog> createState() => _RateUsDialogState();
}

class _RateUsDialogState extends State<_RateUsDialog> {
  int _selectedStars = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Theme.of(context).cardTheme.color ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji
            const Text('😃', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),

            // Message
            Text(
              'We are working hard for a better user experience.\nWe\'d greatly appreciate if you can rate us.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),

            // "The best we can get" hint with arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'The best we can get :)',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '↘',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Star row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNum = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStars = starNum),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      _selectedStars >= starNum
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 42,
                      color: _selectedStars >= starNum
                          ? Colors.amber
                          : context.appTextHint,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Rate button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedStars > 0
                    ? () async {
                        Navigator.of(context).pop();
                        // If 4-5 stars, send to Play Store
                        if (_selectedStars >= 4) {
                          final uri = Uri.parse(
                            'https://play.google.com/store/apps/details?id=${SettingsScreen._packageName}',
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.secondary.withAlpha(80),
                  disabledForegroundColor: Colors.black38,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'RATE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
