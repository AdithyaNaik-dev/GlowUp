import 'package:flutter/material.dart';
import '../config/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _effectiveDate = 'May 3, 2026';
  static const _contactEmail = 'adithya2005an@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Text(
            'Privacy Policy',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Effective date: $_effectiveDate',
            style: TextStyle(
              fontSize: 13,
              color: context.appTextHint,
            ),
          ),
          const SizedBox(height: 24),

          _body(context, '''
This Privacy Policy explains how GlowUp ("we", "us", or "our") collects, uses, and protects your information when you use our mobile application.'''),

          _heading(context, '1. Information We Collect'),
          _body(context, '''
We may collect the following information:

• Account Information: Email, display name, and profile photo when you sign in via Google or Email.
• Usage & Progress Data: Workout progress, streaks, points, and activity logs.
• Device/App Data: Basic device and app information for performance and analytics via Firebase and ads SDKs.'''),

          _heading(context, '2. How We Use Your Information'),
          _body(context, '''
We use your data to:

• Authenticate users and sync progress
• Maintain leaderboard and app features
• Improve app performance and stability
• Serve advertisements (via Google AdMob)'''),

          _heading(context, '3. Third-Party Services'),
          _body(context, '''
We use third-party services that may process data:

• Firebase Authentication
• Cloud Firestore
• Google Sign-In
• Google Mobile Ads (AdMob)

These services operate under their own privacy policies.'''),

          _heading(context, '4. Ads'),
          _body(context, '''
GlowUp uses Google AdMob to display ads. AdMob may use device identifiers and usage data to serve personalized or non-personalized ads.'''),

          _heading(context, '5. Data Retention'),
          _body(context, '''
We retain your data as long as your account is active or as needed to provide services. You may request deletion of your data at any time.'''),

          _heading(context, '6. User Rights & Data Deletion'),
          _body(context, '''
You can request to delete your account and all associated data by contacting us at: adithya2005an@gmail.com'''),

          _heading(context, '7. Children\'s Privacy'),
          _body(context, '''
GlowUp is not intended for children under the age of 13. We do not knowingly collect personal data from children.'''),

          _heading(context, '8. No Sale of Personal Data'),
          _body(context, '''
We do not sell your personal information.'''),

          _heading(context, '9. Contact Us'),
          _body(context, '''
For any questions: adithya2005an@gmail.com'''),
          _body(context, '''
We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy within the App and updating the "Effective date" at the top. You are advised to review this Privacy Policy periodically for any changes.'''),

          _heading(context, '10. Contact Us'),
          _body(context, '''
If you have any questions or suggestions about our Privacy Policy, do not hesitate to contact us:

Email: $_contactEmail'''),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _body(BuildContext context, String text) {
    return Text(
      text.trim(),
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: context.appTextSecondary,
      ),
    );
  }
}
