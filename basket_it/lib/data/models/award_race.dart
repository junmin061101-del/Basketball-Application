import 'package:flutter/foundation.dart';

/// 수상 레이스를 보여주는 상.
enum AwardType { mvp, dpoy, roy }

extension AwardTypeLabel on AwardType {
  /// 칩에 쓰는 짧은 이름.
  String get label => switch (this) {
    AwardType.mvp => 'MVP',
    AwardType.dpoy => '올해의 수비수',
    AwardType.roy => '신인왕',
  };

  /// 수집기가 쓰는 값.
  String get wireName => switch (this) {
    AwardType.mvp => 'mvp',
    AwardType.dpoy => 'dpoy',
    AwardType.roy => 'roy',
  };
}

/// 지난 사다리 대비 순위 변화.
enum RankMovement { up, down, same, newEntry }

/// 사다리 순위나 수상 후보에 오른 선수 한 명.
@immutable
class AwardCandidate {
  /// 사다리 순위. 수상 결과의 후보에는 없다.
  final int? rank;

  /// 한국어 이름(사전에 없으면 영문).
  final String name;
  final String englishName;

  /// 우리 선수 목록에서 찾은 id. 못 찾으면 null이고 상세 화면으로 못 간다.
  final String? playerId;

  /// 기사가 나올 당시 소속팀. 지금 소속팀과 다를 수 있다.
  final String? teamId;

  final int? previousRank;
  final RankMovement? movement;

  /// 수상 결과에서 이 후보가 수상자인지.
  final bool isWinner;

  const AwardCandidate({
    this.rank,
    required this.name,
    required this.englishName,
    this.playerId,
    this.teamId,
    this.previousRank,
    this.movement,
    this.isWinner = false,
  });

  static AwardCandidate? tryParse(Object? json) {
    if (json is! Map) return null;
    final englishName = json['nameEn'] as String? ?? '';
    final name = json['name'] as String? ?? englishName;
    if (name.isEmpty) return null;
    return AwardCandidate(
      rank: (json['rank'] as num?)?.toInt(),
      name: name,
      englishName: englishName,
      playerId: json['playerId'] as String?,
      teamId: json['teamId'] as String?,
      previousRank: (json['previousRank'] as num?)?.toInt(),
      movement: switch (json['movement']) {
        'up' => RankMovement.up,
        'down' => RankMovement.down,
        'same' => RankMovement.same,
        'new' => RankMovement.newEntry,
        _ => null,
      },
      isWinner: json['isWinner'] == true,
    );
  }
}

/// NBA.com 기자가 발행한 사다리 한 편.
@immutable
class AwardLadder {
  final String title;
  final String url;
  final DateTime publishedAt;

  /// 기사가 속한 시즌. "2025-26".
  final String season;
  final String? author;
  final List<AwardCandidate> entries;

  const AwardLadder({
    required this.title,
    required this.url,
    required this.publishedAt,
    required this.season,
    required this.entries,
    this.author,
  });

  static AwardLadder? tryParse(Object? json) {
    if (json is! Map) return null;
    final url = json['url'] as String?;
    final published = DateTime.tryParse(json['publishedAt'] as String? ?? '');
    if (url == null || published == null) return null;
    final entries =
        (json['entries'] as List? ?? const [])
            .map(AwardCandidate.tryParse)
            .whereType<AwardCandidate>()
            .toList()
          ..sort((a, b) => (a.rank ?? 99).compareTo(b.rank ?? 99));
    if (entries.isEmpty) return null;
    return AwardLadder(
      title: json['title'] as String? ?? '',
      url: url,
      publishedAt: published.toLocal(),
      season: json['season'] as String? ?? '',
      author: json['author'] as String?,
      entries: entries,
    );
  }
}

/// 시즌 공식 수상 결과(수상자와 최종 후보).
@immutable
class AwardResult {
  final String season;
  final String url;

  /// 아직 발표 전이면 null.
  final AwardCandidate? winner;
  final List<AwardCandidate> finalists;

  const AwardResult({
    required this.season,
    required this.url,
    required this.winner,
    required this.finalists,
  });

  static AwardResult? tryParse(Object? json) {
    if (json is! Map) return null;
    final winner = AwardCandidate.tryParse(json['winner']);
    final finalists = (json['finalists'] as List? ?? const [])
        .map(AwardCandidate.tryParse)
        .whereType<AwardCandidate>()
        .toList();
    if (winner == null && finalists.isEmpty) return null;
    return AwardResult(
      season: json['season'] as String? ?? '',
      url: json['url'] as String? ?? '',
      winner: winner,
      finalists: finalists,
    );
  }
}

/// 한 상의 레이스: 최신 사다리와 시즌 수상 결과. 둘 다 없을 수 있다.
@immutable
class AwardRace {
  final AwardType type;
  final AwardLadder? ladder;
  final AwardResult? result;

  const AwardRace({required this.type, this.ladder, this.result});
}

/// 수집기가 만든 ladders.json 전체.
@immutable
class AwardRaces {
  /// 기록 데이터 기준 현재 시즌.
  final String currentSeason;
  final List<AwardRace> races;

  const AwardRaces({required this.currentSeason, required this.races});

  AwardRace raceOf(AwardType type) => races.firstWhere(
    (r) => r.type == type,
    orElse: () => AwardRace(type: type),
  );

  static AwardRaces parse(Map<dynamic, dynamic> json) {
    final races = <AwardRace>[];
    for (final raw in (json['awards'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final type = AwardType.values
          .where((t) => t.wireName == raw['award'])
          .firstOrNull;
      if (type == null) continue;
      races.add(
        AwardRace(
          type: type,
          ladder: AwardLadder.tryParse(raw['ladder']),
          result: AwardResult.tryParse(raw['result']),
        ),
      );
    }
    return AwardRaces(
      currentSeason: json['currentSeason'] as String? ?? '',
      races: races,
    );
  }
}
