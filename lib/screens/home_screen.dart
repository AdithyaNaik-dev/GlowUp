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
import 'leaderboard_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationUpdate);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationUpdate);
    super.dispose();
  }

  void _onNotificationUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentDay = _dataService.currentDay;
    final completedDays = _dataService.completedDays;
    final progress = _dataService.progressPercent;
    final currentStreak = _dataService.currentStreak;
    final bestStreak = _dataService.bestStreak;
    final todayPlan = _dataService.getDayPlan(currentDay);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.appBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(context),
                  const SizedBox(height: 20),
                  _buildTodayCard(context, currentDay, todayPlan),
                  const SizedBox(height: 20),
                  StreakCard(
                    currentStreak: currentStreak,
                    bestStreak: bestStreak,
                  ),
                  const SizedBox(height: 16),
                  ProgressCard(
                    progress: progress,
                    completedDays: completedDays.length,
                  ),
                  const SizedBox(height: 24),
                  _buildLeaderboard(),
                  const SizedBox(height: 16),
                  CalendarView(
                    completedDays: completedDays,
                    currentDay: currentDay,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'GlowUp-Challenge',
                style: GoogleFonts.poppins(
                  color: context.appTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.appCardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ))
                      .then((_) => setState(() {}));
                },
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: context.appTextPrimary,
                  size: 24,
                ),
              ),
            ),
            if (_notificationService.hasUnread)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.appCardColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayCard(BuildContext context, int currentDay, dayPlan) {
    final isPostChallenge = _dataService.isInPostChallengeMode;
    final dayLabel =
        isPostChallenge ? 'Daily Workout' : 'Day $currentDay of 30';
    final phaseLabel =
        isPostChallenge ? 'Personalized' : dayPlan?.phaseLabel ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A65), Color(0xFFE53935), Color(0xFFBF360C)],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Image.asset(
                'assets/images/glowup-humans.png',
                height: 230,
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(45),
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
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withAlpha(60),
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
                  const SizedBox(height: 20),
                  const Text(
                    'Ready to\nGlow?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white.withAlpha(200),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dayPlan != null
                            ? '${dayPlan.totalExercises} exercises  •  ~30 min'
                            : 'Get your personalized workout',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    WorkoutScreen(day: currentDay),
                              ),
                            )
                            .then((_) => setState(() {}));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2332),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Start Workout',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.leaderboard_rounded,
                color: AppColors.primary, size: 22),
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
        if (isSignedIn)
          _buildSignedInLeaderboard(user)
        else
          _buildLockedLeaderboard(),
      ],
    );
  }

  Widget _buildSignedInLeaderboard(User user) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('points', descending: true)
            .limit(50)
            .snapshots(),
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
                child: Text('Leaderboard loading...',
                    style: TextStyle(color: context.appTextSecondary)),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Text('No entries yet.',
                    style: TextStyle(color: context.appTextHint)),
              ),
            );
          }

          final List<Map<String, dynamic>> allEntries = [];
          for (int i = 0; i < docs.length; i++) {
            final data = docs[i].data() as Map<String, dynamic>;
            allEntries.add({
              'rank': i + 1,
              'firebaseUid': data['firebaseUid'] ?? '',
              'displayName': data['displayName'] ?? data['name'] ?? 'User',
              'points': data['points'] ?? 0,
              'streak': data['streak'] ?? 0,
            });
          }

          final top5 = allEntries.take(5).toList();

          // Find current user's rank in the full list
          Map<String, dynamic>? myEntry;
          for (final e in allEntries) {
            if (e['firebaseUid'] == user.uid) {
              myEntry = e;
              break;
            }
          }

          return Column(
            children: [
              // Podium for top 3
              if (top5.length >= 3)
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withAlpha(15),
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
                      _podiumItem(top5[1], 60, const Color(0xFFB0BEC5),
                          user.uid),
                      _podiumItem(
                          top5[0], 80, AppColors.primary, user.uid),
                      _podiumItem(top5[2], 50, const Color(0xFFFF8A65),
                          user.uid),
                    ],
                  ),
                ),
              // Your rank card
              if (myEntry != null) _buildMyRankCard(myEntry),
              if (top5.length >= 3) const Divider(height: 1),
              // Rows 4 & 5
              for (final entry
                  in top5.skip(top5.length >= 3 ? 3 : 0))
                _topLeaderboardRow(entry, user.uid),
              _viewAllButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _podiumItem(Map<String, dynamic> entry, double height, Color color,
      String currentUid) {
    final isYou = entry['firebaseUid'] == currentUid;
    final rank = entry['rank'] as int;
    final Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFC107);
    } else if (rank == 2) {
      rankColor = const Color(0xFFB0BEC5);
    } else {
      rankColor = const Color(0xFFFF8A65);
    }
    final IconData icon;
    if (rank == 1) {
      icon = Icons.emoji_events_rounded;
    } else if (rank == 2) {
      icon = Icons.workspace_premium_rounded;
    } else {
      icon = Icons.military_tech_rounded;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: rankColor, size: 30),
        const SizedBox(height: 6),
        Text(
          isYou ? 'You' : entry['displayName'] as String,
          style: TextStyle(
            color: isYou ? AppColors.primary : context.appTextPrimary,
            fontSize: 13,
            fontWeight: isYou ? FontWeight.w800 : FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
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
                '#$rank',
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

  Widget _buildMyRankCard(Map<String, dynamic> entry) {
    final rank = entry['rank'] as int;
    final points = entry['points'] as int;
    final streak = entry['streak'] as int;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(20),
            AppColors.primary.withAlpha(8),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Rank',
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Color(0xFFFF9800), size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '$streak streak',
                      style: TextStyle(
                        color: context.appTextHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$points pts',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topLeaderboardRow(Map<String, dynamic> entry, String currentUid) {
    final isYou = entry['firebaseUid'] == currentUid;
    final rank = entry['rank'] as int;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isYou ? AppColors.primary.withAlpha(10) : null,
        border: Border(
          bottom: BorderSide(color: context.appDivider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: context.appTextHint,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.star_rounded, color: context.appTextHint, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isYou ? 'You' : entry['displayName'] as String,
              style: TextStyle(
                color: isYou ? AppColors.primary : context.appTextPrimary,
                fontSize: 14,
                fontWeight: isYou ? FontWeight.w800 : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isYou
                  ? AppColors.primary.withAlpha(25)
                  : context.appSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${entry['points']} pts',
              style: TextStyle(
                color: isYou ? AppColors.primary : context.appTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewAllButton() {
    return InkWell(
      onTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(
                builder: (_) => const LeaderboardScreen()))
            .then((_) => setState(() {}));
      },
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View All',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded,
                color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedLeaderboard() {
    final fakeNames = ['Alex', 'Jordan', 'Sam', 'Riley', 'Morgan'];
    final fakePoints = [1240, 980, 870, 650, 420];
    final fakeStreaks = [14, 10, 7, 5, 3];

    Widget fakeRow(int i) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.appDivider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('#${i + 1}',
                  style: TextStyle(
                      color: context.appTextHint,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.star_rounded, color: context.appTextHint, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fakeNames[i],
                      style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Row(children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Color(0xFFFF9800), size: 13),
                    const SizedBox(width: 3),
                    Text('${fakeStreaks[i]} streak',
                        style: TextStyle(
                            color: context.appTextHint, fontSize: 11)),
                  ]),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${fakePoints[i]} pts',
                  style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    final fakeContent = Container(
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider),
      ),
      child: Column(
        children: [
          // Fake podium
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withAlpha(15),
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
                _fakePodiumItem(fakeNames[1], fakePoints[1], 2, 60),
                _fakePodiumItem(fakeNames[0], fakePoints[0], 1, 80),
                _fakePodiumItem(fakeNames[2], fakePoints[2], 3, 50),
              ],
            ),
          ),
          const Divider(height: 1),
          fakeRow(3),
          fakeRow(4),
        ],
      ),
    );

    return Stack(
      children: [
        IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: fakeContent,
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      size: 32, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                Text(
                  'Sign in to access Leaderboard',
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Compete with others and track your rank',
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => const AuthScreen()))
                        .then((_) => setState(() {}));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fakePodiumItem(String name, int points, int rank, double height) {
    final Color color;
    final IconData icon;
    if (rank == 1) {
      color = const Color(0xFFFFC107);
      icon = Icons.emoji_events_rounded;
    } else if (rank == 2) {
      color = const Color(0xFFB0BEC5);
      icon = Icons.workspace_premium_rounded;
    } else {
      color = const Color(0xFFFF8A65);
      icon = Icons.military_tech_rounded;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 6),
        Text(name,
            style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
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
              Text('#$rank',
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Text('$points pts',
                  style: TextStyle(
                      color: context.appTextSecondary, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = _dataService.userName;
    final suffix = name.isNotEmpty ? ', $name' : '';
    if (hour < 12) return 'Hello$suffix';
    if (hour < 17) return 'Hello$suffix';
    return 'Hello$suffix';
  }
}
