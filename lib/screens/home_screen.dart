import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/theme.dart';
import '../services/data_service.dart';
import '../widgets/progress_card.dart';
import '../widgets/streak_card.dart';
import '../widgets/calendar_view.dart';
import 'workout_screen.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();

  @override
  Widget build(BuildContext context) {
    final currentDay = _dataService.currentDay;
    final completedDays = _dataService.completedDays;
    final progress = _dataService.progressPercent;
    final currentStreak = _dataService.currentStreak;
    final bestStreak = _dataService.bestStreak;
    final todayPlan = _dataService.getDayPlan(currentDay);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Layered header: AppBar + Red Card ──
              _buildLayeredHeader(context, currentDay, todayPlan),
              const SizedBox(height: 20),

              // Everything below gets horizontal padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Streak
                    StreakCard(
                      currentStreak: currentStreak,
                      bestStreak: bestStreak,
                    ),
                    const SizedBox(height: 20),

                    // Progress
                    ProgressCard(
                      progress: progress,
                      completedDays: completedDays.length,
                    ),
                    const SizedBox(height: 20),

                    // Calendar
                    CalendarView(
                      completedDays: completedDays,
                      currentDay: currentDay,
                    ),
                    const SizedBox(height: 24),

                    // Leaderboard
                    _buildLeaderboard(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the two-layer header: secondary AppBar flowing into the red card.
  Widget _buildLayeredHeader(BuildContext context, int currentDay, dayPlan) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // ── Layer 1: Secondary background that extends behind the card ──
        Container(
          // This stretches down far enough so the rounded bottom peeks
          // below the red card, creating a "second layer" effect.
          height: topPadding + 400,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(36),
              bottomRight: Radius.circular(36),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryDark.withAlpha(40),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        ),

        // ── Layer 2: Content on top ──
        Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: Column(
            children: [
              // AppBar row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              color: Colors.black.withAlpha(180),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'GlowUp-Challenge',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(120),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Red card — edge-to-edge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTodayCard(context, currentDay, dayPlan),
              ),
              const SizedBox(height: 10),
              // Decorative lines below card
              Container(
                width: 50,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(180),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(120),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(70),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayCard(BuildContext context, int currentDay, dayPlan) {
    final isPostChallenge = _dataService.isInPostChallengeMode;
    final dayLabel = isPostChallenge ? 'Daily Workout' : 'Day $currentDay of 30';
    final phaseLabel =
        isPostChallenge ? 'Personalized for you' : dayPlan?.phaseLabel ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFD32F2F), Color(0xFF1A1A1A)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(80),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Character image on the right ──
            Positioned(
              right: -10,
              bottom: -10,
              child: Image.asset(
                'assets/images/glowup-humans.png',
                height: 240,
                fit: BoxFit.contain,
              ),
            ),
            // ── Card content on the left ──
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phase tags
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          dayLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (phaseLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withAlpha(50),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            phaseLabel,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Ready to\nGlow?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dayPlan != null
                        ? '${dayPlan.totalExercises} exercises • ~30 min'
                        : 'Get your personalized workout',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => WorkoutScreen(day: currentDay),
                              ),
                            )
                            .then((_) => setState(() {}));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 22),
                          SizedBox(width: 6),
                          Text(
                            "Start Workout",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard() {
    final user = FirebaseAuth.instance.currentUser;
    final bool isSignedIn = user != null;

    final leaderboardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.leaderboard_rounded, color: AppColors.secondary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Leaderboard',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: context.appCardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appDivider),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: isSignedIn
                ? FirebaseFirestore.instance
                    .collection('users')
                    .orderBy('points', descending: true)
                    .limit(50)
                    .snapshots()
                : Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      'Leaderboard loading...',
                      style: TextStyle(color: context.appTextSecondary),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(child: Text('No entries yet.', style: TextStyle(color: context.appTextHint))),
                );
              }

              final List<Map<String, dynamic>> leaderboard = [];
              for (int i = 0; i < docs.length; i++) {
                final data = docs[i].data() as Map<String, dynamic>;
                String avatar = '⭐';
                if (i == 0) {
                  avatar = '🏆';
                } else if (i == 1) {
                  avatar = '🥈';
                } else if (i == 2) {
                  avatar = '🥉';
                }

                leaderboard.add({
                  'rank': i + 1,
                  'uid': docs[i].id,
                  'name': data['name'] ?? 'User',
                  'points': data['points'] ?? 0,
                  'streak': data['streak'] ?? 0,
                  'avatar': avatar,
                });
              }

              return Column(
                children: [
                  if (leaderboard.length >= 3)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondary.withAlpha(15),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _podiumItem(leaderboard[1], 60, AppColors.textSecondary, user?.uid),
                          _podiumItem(leaderboard[0], 80, AppColors.secondary, user?.uid),
                          _podiumItem(leaderboard[2], 50, AppColors.warning, user?.uid),
                        ],
                      ),
                    ),
                  if (leaderboard.length >= 3) const Divider(height: 1),
                  ...leaderboard.skip(leaderboard.length >= 3 ? 3 : 0).map((entry) => _leaderboardRow(entry, user?.uid)),
                ],
              );
            },
          ),
        ),
      ],
    );

    if (isSignedIn) {
      return leaderboardContent;
    } else {
      return Stack(
        children: [
          // Blurred background
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Opacity(
              opacity: 0.6,
              child: IgnorePointer(child: leaderboardContent),
            ),
          ),
          // Overlay card — centered but scrollable to avoid bottom overflow on small screens or when keyboard is present
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewPadding.bottom + 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.appCardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 48, color: AppColors.secondary),
                    const SizedBox(height: 16),
                    Text(
                      'Sign in to unlock leaderboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Compete with friends and track your ranking!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.appTextHint,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AuthScreen()),
                          ).then((_) => setState(() {}));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _podiumItem(Map<String, dynamic> entry, double height, Color color, String? currentUserId) {
    final isYou = entry['uid'] == currentUserId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry['avatar'] as String,
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 6),
        Text(
          isYou ? 'You' : entry['name'] as String,
          style: TextStyle(
            color: isYou ? AppColors.secondary : context.appTextPrimary,
            fontSize: 13,
            fontWeight: isYou ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withAlpha(60), color.withAlpha(25)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#${entry['rank']}',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${entry['points']} pts',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _leaderboardRow(Map<String, dynamic> entry, String? currentUserId) {
    final isYou = entry['uid'] == currentUserId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isYou ? AppColors.secondary.withAlpha(10) : null,
        border: Border(
          bottom: BorderSide(color: context.appDivider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${entry['rank']}',
              style: TextStyle(
                color: context.appTextHint,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            entry['avatar'] as String,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isYou ? 'You' : entry['name'] as String,
                  style: TextStyle(
                    color: isYou ? AppColors.secondary : context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: isYou ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                Text(
                  '🔥 ${entry['streak']} streak',
                  style: TextStyle(
                    color: context.appTextHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isYou
                  ? AppColors.secondary.withAlpha(25)
                  : context.appSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${entry['points']} pts',
              style: TextStyle(
                color: isYou ? AppColors.secondary : context.appTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ';
    if (hour < 17) return 'Good Afternoon ';
    return 'Good Evening ';
  }
}
