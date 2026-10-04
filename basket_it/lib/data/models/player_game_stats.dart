import 'package:flutter/foundation.dart';

/// 한 경기에서의 선수 기록(박스스코어 한 줄).
///
/// 필드 구성은 선수 상세 화면(4단계)의 시즌 스탯 표와 동일한 항목의
/// 단일 경기 버전이다 — 시즌 평균은 결국 이 값들의 누적/평균이 된다.
@immutable
class PlayerGameStats {
  final String playerId;
  final String gameId;
  final String teamId;

  final int minutes;
  final int points;
  final int fgm; // 필드골 성공
  final int fga; // 필드골 시도
  final int tpm; // 3점 성공
  final int tpa; // 3점 시도
  final int ftm; // 자유투 성공
  final int fta; // 자유투 시도
  final int oreb; // 공격 리바운드
  final int dreb; // 수비 리바운드
  final int ast;
  final int tov; // 턴오버
  final int stl;
  final int blk;
  final int pf; // 개인 파울

  /// 득실마진. 원본이 모르면(KBL 999) null이고 화면에는 "-"로 보인다.
  final int? plusMinus;

  /// 출전 시간(초). KBL은 초까지 오고, NBA(ESPN)는 분 단위만 와서 null이다.
  final int? seconds;

  /// 선발 출전인지. 선발 표시가 없는 예전 기록이면 null.
  final bool? starter;

  /// 박스스코어에 적힌 선수 이름·사진. 지난 시즌 경기에는 지금 명단에 없는
  /// 선수(은퇴·이적)도 나오므로, 명단에서 못 찾으면 이 값으로 보여준다.
  final String? name;
  final String? photoUrl;

  const PlayerGameStats({
    required this.playerId,
    required this.gameId,
    required this.teamId,
    required this.minutes,
    required this.points,
    required this.fgm,
    required this.fga,
    required this.tpm,
    required this.tpa,
    required this.ftm,
    required this.fta,
    required this.oreb,
    required this.dreb,
    required this.ast,
    required this.tov,
    required this.stl,
    required this.blk,
    required this.pf,
    required this.plusMinus,
    this.seconds,
    this.starter,
    this.name,
    this.photoUrl,
  });

  /// 수집기와 서버가 같은 모양으로 적어 둔 한 줄을 읽는다.
  /// (정적 JSON의 boxscores/*.json, Firestore의 liveBoxScores 둘 다 이 모양이다)
  factory PlayerGameStats.fromMap(Map<dynamic, dynamic> row, String gameId) {
    int i(String key) => (row[key] as num?)?.toInt() ?? 0;
    return PlayerGameStats(
      playerId: row['playerId'] as String? ?? '',
      gameId: gameId,
      teamId: row['teamId'] as String? ?? '',
      minutes: i('minutes'),
      points: i('points'),
      fgm: i('fgm'),
      fga: i('fga'),
      tpm: i('tpm'),
      tpa: i('tpa'),
      ftm: i('ftm'),
      fta: i('fta'),
      oreb: i('oreb'),
      dreb: i('dreb'),
      ast: i('ast'),
      tov: i('tov'),
      stl: i('stl'),
      blk: i('blk'),
      pf: i('pf'),
      plusMinus: (row['plusMinus'] as num?)?.toInt(),
      seconds: (row['seconds'] as num?)?.toInt(),
      starter: row['starter'] as bool?,
      name: row['name'] as String?,
      photoUrl: row['headshot'] as String?,
    );
  }

  int get reb => oreb + dreb;

  /// 출전 시간 표기. 초를 알면 "31:04", 분만 알면(NBA) "22분".
  /// 초를 모르는데 ":00"을 붙이면 실제와 다른 시간이 되므로 붙이지 않는다.
  String get playTimeLabel {
    final s = seconds;
    if (s == null) return '$minutes분';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  double get fgPct => fga == 0 ? 0 : fgm / fga;
  double get tpPct => tpa == 0 ? 0 : tpm / tpa;
  double get ftPct => fta == 0 ? 0 : ftm / fta;
}
