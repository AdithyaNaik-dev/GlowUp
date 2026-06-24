import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),
            Text(
              'Settings',
              style: GoogleFonts.poppins(
                color: context.appTextPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customize your app experience',
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),

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

            _sectionTitle('Account'),
            const SizedBox(height: 14),
            _buildAccountSection(context),
            const SizedBox(height: 32),

            _sectionTitle('Customer Support'),
            const SizedBox(height: 14),
            _buildCustomerSupportSection(context),
            const SizedBox(height: 32),

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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    );
  }

  Widget _supportCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 60,
      color: context.appDivider,
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
    final effectiveIconColor = iconColor ?? AppColors.primary;
    final effectiveTextColor = textColor ?? context.appTextPrimary;

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

  Widget _buildAccountSection(BuildContext context) {
    final authService = AuthService();
    final isSignedIn = authService.isSignedIn;
    final userName = DataService().userName;

    if (isSignedIn) {
      final displayName = userName.isNotEmpty
          ? userName
          : authService.displayName.isNotEmpty
              ? authService.displayName
              : 'User';

      return _supportCard(context, [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withAlpha(25),
                child: Text(
                  displayName[0].toUpperCase(),
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
                      displayName,
                      style: TextStyle(
                        color: context.appTextPrimary,
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

  Widget _buildCustomerSupportSection(BuildContext context) {
    final authService = AuthService();
    final isSignedIn = authService.isSignedIn;

    String? userId;
    if (isSignedIn) {
      final userName = DataService().userName;
      final displayName = userName.isNotEmpty
          ? userName
          : authService.displayName.isNotEmpty
              ? authService.displayName
              : 'User';
      userId = displayName.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');
      userId = userId.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    }

    return _supportCard(context, [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Contact Support',
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isSignedIn)
              _supportInfoTile(
                context,
                label: 'Your ID',
                value: userId!,
                icon: Icons.badge_rounded,
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.appDivider),
                ),
                child: Row(
                  children: [
                    Icon(Icons.badge_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sign in to see your ID',
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _supportInfoTile(
              context,
              label: 'Support Email',
              value: 'glowup.officialapp@gmail.com',
              icon: Icons.mail_outline_rounded,
            ),
            const SizedBox(height: 12),
            Text(
              'Include your ID when contacting support for faster assistance.',
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _supportInfoTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appDivider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  void _navigateToSignIn(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out?',
          style: TextStyle(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'You can sign back in anytime. Your local progress will be kept.',
          style: TextStyle(color: context.appTextSecondary),
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
        backgroundColor: context.appCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Text(
              'Delete Account?',
              style: TextStyle(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete your account and all associated data. '
          'Your local progress will also be erased.\n\n'
          'This action cannot be undone.',
          style: TextStyle(color: context.appTextSecondary),
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
      await DataService().clearAuthState();
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
        _showErrorSnackbar(context, AuthService.friendlyError(e));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorSnackbar(
            context, e.toString().contains('cancelled')
                ? 'Account deletion cancelled.'
                : 'Failed to delete account. Please try again.');
      }
    }
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
              : context.appCardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.appDivider,
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
                    : context.appDivider.withAlpha(60),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : context.appTextHint,
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
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.appTextSecondary,
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
                  color: isSelected ? AppColors.primary : context.appTextHint,
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
      backgroundColor: context.appCardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sentiment_very_satisfied_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'We are working hard for a better user experience.\nWe\'d greatly appreciate if you can rate us.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'The best we can get :)',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.south_east_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),

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

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedStars > 0
                    ? () async {
                        Navigator.of(context).pop();
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withAlpha(80),
                  disabledForegroundColor: Colors.white38,
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
