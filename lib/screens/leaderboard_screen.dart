import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _tabIndex = 0;
  bool _showConfetti = false;
  final Set<String> _celebratedKeys = {};

  static const _tabs = ['All Time', 'Weekly', 'Monthly'];
  static const _orderFields = ['points', 'weeklyPoints', 'monthlyPoints'];
  static const _tabKeys = ['alltime', 'weekly', 'monthly'];

  @override
  void initState() {
    super.initState();
    _loadCelebratedKeys();
  }

  Future<void> _loadCelebratedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('celebrated_leaderboard') ?? [];
    _celebratedKeys.addAll(saved);
  }

  Future<void> _triggerConfetti(int rank) async {
    final key = '${_tabKeys[_tabIndex]}_top$rank';
    if (_celebratedKeys.contains(key)) return;

    _celebratedKeys.add(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('celebrated_leaderboard', _celebratedKeys.toList());

    if (!mounted) return;
    setState(() => _showConfetti = true);
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) setState(() => _showConfetti = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.appBackground,
        body: Stack(
          children: [
            Column(children: [
            // ── Gradient header ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 16,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFBF360C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.emoji_events_rounded,
                          color: Colors.white, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        'Leaderboard',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Tab bar ──
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: List.generate(_tabs.length, (i) {
                        final selected = _tabIndex == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _tabIndex = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _tabs[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.white.withAlpha(180),
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .orderBy(_orderFields[_tabIndex], descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load leaderboard.',
                          style: TextStyle(color: context.appTextSecondary)),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.leaderboard_rounded,
                              color: context.appTextHint, size: 48),
                          const SizedBox(height: 12),
                          Text('No entries yet.',
                              style: TextStyle(color: context.appTextHint)),
                        ],
                      ),
                    );
                  }

                  final pointsKey = _orderFields[_tabIndex];

                  final List<Map<String, dynamic>> leaderboard = [];
                  for (int i = 0; i < docs.length; i++) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final pts = data[pointsKey] as int? ?? 0;
                    if (_tabIndex > 0 && pts == 0) continue;
                    leaderboard.add({
                      'rank': leaderboard.length + 1,
                      'firebaseUid': data['firebaseUid'] ?? '',
                      'displayName':
                          data['displayName'] ?? data['name'] ?? 'User',
                      'points': pts,
                      'streak': data['streak'] ?? 0,
                      'totalWorkouts': data['totalWorkouts'] ?? 0,
                    });
                  }

                  if (leaderboard.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.leaderboard_rounded,
                              color: context.appTextHint, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _tabIndex == 1
                                ? 'No workouts this week yet.'
                                : 'No workouts this month yet.',
                            style: TextStyle(color: context.appTextHint),
                          ),
                        ],
                      ),
                    );
                  }

                  Map<String, dynamic>? myEntry;
                  if (user != null) {
                    for (final e in leaderboard) {
                      if (e['firebaseUid'] == user.uid) {
                        myEntry = e;
                        break;
                      }
                    }
                  }

                  // Trigger confetti for top 5, 3, or 1
                  if (myEntry != null) {
                    final rank = myEntry['rank'] as int;
                    if (rank == 1) {
                      _triggerConfetti(1);
                    } else if (rank <= 3) {
                      _triggerConfetti(3);
                    } else if (rank <= 5) {
                      _triggerConfetti(5);
                    }
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        if (leaderboard.length >= 3)
                          _buildPodium(context, leaderboard, user?.uid),

                        if (myEntry != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: _buildMyRankCard(context, myEntry),
                          ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.appCardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.appDivider),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Column(
                                children: [
                                  for (int i = 0;
                                      i < leaderboard.length;
                                      i++)
                                    _leaderboardRow(context, leaderboard[i],
                                        user?.uid, i == leaderboard.length - 1),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Scoring rules ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                          child: _buildScoringRules(context),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ]),

            // ── Confetti overlay ──
            if (_showConfetti)
              Positioned.fill(
                child: IgnorePointer(
                  child: DotLottieLoader.fromAsset(
                    'assets/animation/Confetti - Full Screen.lottie',
                    frameBuilder: (ctx, dotlottie) {
                      if (dotlottie != null) {
                        return Lottie.memory(
                          dotlottie.animations.values.single,
                          fit: BoxFit.cover,
                          repeat: false,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Podium
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPodium(BuildContext context,
      List<Map<String, dynamic>> leaderboard, String? currentUserId) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      transform: Matrix4.translationValues(0, -14, 0),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: context.appDivider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _podiumSlot(context, leaderboard[1], currentUserId,
              pillarHeight: 70, avatarSize: 48, crownSize: 0),
          _podiumSlot(context, leaderboard[0], currentUserId,
              pillarHeight: 90, avatarSize: 58, crownSize: 24),
          _podiumSlot(context, leaderboard[2], currentUserId,
              pillarHeight: 56, avatarSize: 44, crownSize: 0),
        ],
      ),
    );
  }

  Widget _podiumSlot(
    BuildContext context,
    Map<String, dynamic> entry,
    String? currentUserId, {
    required double pillarHeight,
    required double avatarSize,
    required double crownSize,
  }) {
    final rank = entry['rank'] as int;
    final isYou = entry['firebaseUid'] == currentUserId;
    final name = isYou ? 'You' : entry['displayName'] as String;
    final points = entry['points'] as int;

    final Color color;
    final Color bgColor;
    final IconData icon;
    if (rank == 1) {
      color = const Color(0xFFFFC107);
      bgColor = const Color(0xFFFFF8E1);
      icon = Icons.emoji_events_rounded;
    } else if (rank == 2) {
      color = const Color(0xFF90A4AE);
      bgColor = const Color(0xFFECEFF1);
      icon = Icons.workspace_premium_rounded;
    } else {
      color = const Color(0xFFFF8A65);
      bgColor = const Color(0xFFFBE9E7);
      icon = Icons.military_tech_rounded;
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return SizedBox(
      width: 90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (crownSize > 0)
            Icon(icon, color: color, size: crownSize)
          else
            SizedBox(height: crownSize > 0 ? crownSize : 10),
          const SizedBox(height: 4),
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.isDark ? color.withAlpha(40) : bgColor,
              border: Border.all(color: color, width: 2.5),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: color,
                  fontSize: avatarSize * 0.38,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              color: isYou ? AppColors.primary : context.appTextPrimary,
              fontSize: 13,
              fontWeight: isYou ? FontWeight.w800 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
          Text(
            '$points pts',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 56,
            height: pillarHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withAlpha(70), color.withAlpha(20)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: color.withAlpha(50)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Your rank card
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMyRankCard(BuildContext context, Map<String, dynamic> entry) {
    final rank = entry['rank'] as int;
    final points = entry['points'] as int;
    final streak = entry['streak'] as int;
    final workouts = entry['totalWorkouts'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(25),
            AppColors.primary.withAlpha(8),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Rank',
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Keep going! You\'re doing great.',
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$points pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statChip(context, Icons.local_fire_department_rounded,
                  '$streak streak', const Color(0xFFFF9800)),
              const SizedBox(width: 10),
              _statChip(context, Icons.fitness_center_rounded,
                  '$workouts workouts', AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  List rows
  // ═══════════════════════════════════════════════════════════════════

  Widget _leaderboardRow(BuildContext context, Map<String, dynamic> entry,
      String? currentUserId, bool isLast) {
    final isYou = entry['firebaseUid'] == currentUserId;
    final rank = entry['rank'] as int;
    final name = isYou ? 'You' : entry['displayName'] as String;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final Color rankColor;
    final IconData? rankIcon;
    if (rank == 1) {
      rankColor = const Color(0xFFFFC107);
      rankIcon = Icons.emoji_events_rounded;
    } else if (rank == 2) {
      rankColor = const Color(0xFF90A4AE);
      rankIcon = Icons.workspace_premium_rounded;
    } else if (rank == 3) {
      rankColor = const Color(0xFFFF8A65);
      rankIcon = Icons.military_tech_rounded;
    } else {
      rankColor = context.appTextHint;
      rankIcon = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isYou ? AppColors.primary.withAlpha(12) : null,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: context.appDivider, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: rankIcon != null
                ? Icon(rankIcon, color: rankColor, size: 22)
                : Text(
                    '#$rank',
                    style: TextStyle(
                      color: context.appTextHint,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isYou
                  ? AppColors.primary.withAlpha(20)
                  : context.appSurface,
              border: Border.all(
                color: isYou
                    ? AppColors.primary.withAlpha(60)
                    : context.appDivider,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: isYou ? AppColors.primary : context.appTextSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
                  name,
                  style: TextStyle(
                    color: isYou ? AppColors.primary : context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: isYou ? FontWeight.w800 : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Color(0xFFFF9800), size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '${entry['streak']} streak',
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Scoring rules
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildScoringRules(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'How Points Work',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _ruleItem(context, Icons.fitness_center_rounded,
              'Complete a workout', '+100 base points', AppColors.primary),
          const SizedBox(height: 12),

          _ruleDivider(context),
          const SizedBox(height: 12),

          Text(
            'Streak Multipliers',
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _streakRow(context, '4-6 days', '1.5x', '150 pts'),
          const SizedBox(height: 6),
          _streakRow(context, '7-13 days', '2.0x', '200 pts'),
          const SizedBox(height: 6),
          _streakRow(context, '14-29 days', '2.5x', '250 pts'),
          const SizedBox(height: 6),
          _streakRow(context, '30+ days', '3.0x', '300 pts'),

          const SizedBox(height: 14),
          _ruleDivider(context),
          const SizedBox(height: 14),

          _ruleItem(context, Icons.block_rounded,
              'Daily cap', '1 workout per day counts', const Color(0xFFFF9800)),
          const SizedBox(height: 12),
          _ruleItem(context, Icons.trending_down_rounded,
              'Inactivity decay', '-5% per week if inactive', const Color(0xFFEF5350)),
          const SizedBox(height: 12),
          _ruleItem(context, Icons.calendar_today_rounded,
              'Weekly & Monthly', 'Reset every week/month', const Color(0xFF42A5F5)),
        ],
      ),
    );
  }

  Widget _ruleItem(BuildContext context, IconData icon, String title,
      String subtitle, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _streakRow(
      BuildContext context, String days, String multiplier, String pts) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Icon(Icons.local_fire_department_rounded,
            color: const Color(0xFFFF9800), size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            days,
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withAlpha(15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            multiplier,
            style: const TextStyle(
              color: Color(0xFFFF9800),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        Text(
          pts,
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _ruleDivider(BuildContext context) {
    return Divider(color: context.appDivider, height: 1);
  }
}
