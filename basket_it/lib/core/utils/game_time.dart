/// 경기 날짜·시각 표기. 기기 시간대 기준으로 앱 어디서나 같은 모양을 쓴다.
const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// "4월 8일 (수)". 올해가 아니면 연도를 붙인다.
String dayLabel(DateTime time, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = '${time.month}월 ${time.day}일 (${_weekdays[time.weekday - 1]})';
  return time.year == today.year ? day : '${time.year}년 $day';
}

/// "8:00 PM".
String timeLabel(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}
