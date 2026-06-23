import 'package:flutter/material.dart';
import '../config/theme.dart';

class CalendarView extends StatefulWidget {
  final Set<int> completedDays;
  final int currentDay;

  const CalendarView({
    super.key,
    required this.completedDays,
    required this.currentDay,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late PageController _pageController;
  late int _currentPage;

  static const int _daysPerPage = 7;
  static const int _totalDays = 30;
  static const List<String> _weekLabels = [
    'M', 'T', 'W', 'T', 'F', 'S', 'S',
  ];

  int get _pageCount => (_totalDays / _daysPerPage).ceil();

  @override
  void initState() {
    super.initState();
    _currentPage = ((widget.currentDay - 1) / _daysPerPage).floor().clamp(0, _pageCount - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                '30 Day Calendar',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 2),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekLabels
                .map(
                  (label) => SizedBox(
                    width: 40,
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: context.appTextHint,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: _pageCount,
              itemBuilder: (context, pageIndex) {
                final startDay = pageIndex * _daysPerPage + 1;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_daysPerPage, (i) {
                    final day = startDay + i;
                    if (day > _totalDays) {
                      return const SizedBox(width: 40, height: 40);
                    }
                    return _buildDayCircle(context, day);
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pageCount, (index) {
              final isActive = index == _currentPage;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 24 : 8,
                height: 4,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : context.appDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCircle(BuildContext context, int day) {
    final isCompleted = widget.completedDays.contains(day);
    final isCurrent = day == widget.currentDay && !isCompleted;
    final isSunday = day % 7 == 0;

    Color bgColor;
    if (isCompleted) {
      bgColor = AppColors.primary;
    } else if (isCurrent) {
      bgColor = Colors.transparent;
    } else if (isSunday) {
      bgColor = AppColors.primary.withAlpha(20);
    } else {
      bgColor = context.isDark
          ? context.appSurface
          : const Color(0xFFF0F0F0);
    }

    return SizedBox(
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: isCurrent
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: Center(
          child: isCompleted
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : Text(
                  '$day',
                  style: TextStyle(
                    color: isCurrent
                        ? AppColors.primary
                        : isSunday
                            ? AppColors.primary
                            : context.appTextSecondary,
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
