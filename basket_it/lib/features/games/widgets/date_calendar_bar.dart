import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/game_providers.dart';

const _cellWidth = 56.0;
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
    _centerOn(normalized, animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedGameDateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _titleFor(selected, _today),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: _openPicker,
                icon: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 68,
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: _itemCount,
            itemExtent: _cellWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemBuilder: (context, index) {
              final date = _rangeStart.add(Duration(days: index));
              final isSelected = _isSameDate(date, selected);
              final isToday = index == _todayIndex;
              return _DateCell(
                date: date,
                selected: isSelected,
                isToday: isToday,
                onTap: () {
                  ref.read(selectedGameDateProvider.notifier).state = date;
                  _centerOn(date, animate: true);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _titleFor(DateTime selected, DateTime today) {
    final label = '${selected.year}년 ${selected.month}월 ${selected.day}일';
    if (_isSameDate(selected, today)) return '$label · 오늘';
    return label;
  }
}

class _DateCell extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  const _DateCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekday = _weekdayLabels[date.weekday - 1];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _cellWidth - 8,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isToday ? AppColors.textTertiary : AppColors.border),
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekday,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white70 : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
