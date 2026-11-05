import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/game_providers.dart';

const _cellWidth = 52.0;
const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 좌우로 스와이프하는 날짜 캘린더 바.
///
/// 과거 10년 ~ 앞으로 1년까지 이동 가능한 구조. 시즌 전체 일정을 받아
/// 두므로 몇 달 뒤 경기도 볼 수 있다. 우측 달력 아이콘으로 먼 날짜로
/// 바로 점프할 수도 있다.
class DateCalendarBar extends ConsumerStatefulWidget {
  const DateCalendarBar({super.key});

  @override
  ConsumerState<DateCalendarBar> createState() => _DateCalendarBarState();
}

class _DateCalendarBarState extends ConsumerState<DateCalendarBar> {
  late final DateTime _today;
  late final DateTime _rangeStart;
  late final DateTime _rangeEnd;
  late final int _itemCount;
  late final int _todayIndex;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _rangeStart = _today.subtract(const Duration(days: 365 * 10));
    // 정규시즌이 10월에 시작해 이듬해 6월 파이널로 끝나므로 1년이면 넉넉하다.
    _rangeEnd = _today.add(const Duration(days: 365));
    _itemCount = _rangeEnd.difference(_rangeStart).inDays + 1;
    _todayIndex = _today.difference(_rangeStart).inDays;

    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOn(_today));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexOf(DateTime date) => date.difference(_rangeStart).inDays;

  void _centerOn(DateTime date, {bool animate = false}) {
    if (!_controller.hasClients) return;
    final index = _indexOf(date).clamp(0, _itemCount - 1);
    final viewport = _controller.position.viewportDimension;
    final offset = (index * _cellWidth) - (viewport / 2 - _cellWidth / 2);
    final clamped = offset.clamp(0.0, _controller.position.maxScrollExtent);
    if (animate) {
      _controller.animateTo(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _controller.jumpTo(clamped);
    }
  }

  Future<void> _openPicker() async {
    final selected = ref.read(selectedGameDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: _rangeStart,
      lastDate: _rangeEnd,
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.background,
            onSurface: AppColors.textPrimary,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.background,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final normalized = DateTime(picked.year, picked.month, picked.day);
    ref.read(selectedGameDateProvider.notifier).state = normalized;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedGameDateProvider);
    // 날짜는 여기(칸·달력)뿐 아니라 "다음 경기" 버튼에서도 바뀐다.
    // 어디서 바뀌든 날짜 바가 그 날로 따라가게 한다.
    ref.listen<DateTime>(selectedGameDateProvider, (previous, next) {
      if (previous != next) _centerOn(next, animate: true);
    });
    final gameDays =
        ref.watch(gameDaysProvider).valueOrNull?.toSet() ?? const <DateTime>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 달 표시를 누르면 달력에서 날짜를 고를 수 있다.
        Center(
          child: GestureDetector(
            onTap: _openPicker,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _titleFor(selected, _today),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 78,
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: _itemCount,
            itemExtent: _cellWidth,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (context, index) {
              final date = _rangeStart.add(Duration(days: index));
              final isSelected = _isSameDate(date, selected);
              final isToday = index == _todayIndex;
              return _DateCell(
                date: date,
                selected: isSelected,
                isToday: isToday,
                hasGames: gameDays.contains(date),
                onTap: () =>
                    ref.read(selectedGameDateProvider.notifier).state = date,
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 달력 위에 적는 달. 디자인처럼 "2025년 11월"만 적는다.
  String _titleFor(DateTime selected, DateTime today) =>
      '${selected.year}년 ${selected.month}월';
}

class _DateCell extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool isToday;

  /// 그날 경기가 있는지. 날짜 아래 점으로 표시해 경기일을 한눈에 찾게 한다.
  final bool hasGames;
  final VoidCallback onTap;

  const _DateCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.hasGames,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekday = _weekdayLabels[date.weekday - 1];
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _cellWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekday,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primarySoft : Colors.transparent,
                border: isToday && !selected
                    ? Border.all(color: AppColors.border)
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 점이 없는 날도 자리를 남겨 칸 높이가 들쭉날쭉하지 않게 한다.
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasGames ? AppColors.primary : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
