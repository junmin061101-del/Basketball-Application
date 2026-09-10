import '../mock/mock_kbl_data.dart';
import '../models/player.dart';
import '../models/player_bio.dart';
import '../models/player_season_stats.dart';
import '../../core/utils/stable_hash.dart';
import '../../core/utils/stable_random.dart';

/// 선수 데이터 접근을 추상화한 Repository.
///
/// 지금은 [MockPlayerRepository]가 목업 데이터를 반환하지만, 실제 API가
/// 준비되면 이 인터페이스를 구현하는 `ApiPlayerRepository` 하나로 교체하면
/// 앱의 나머지 부분(Provider, UI)은 변경할 필요가 없다.
abstract class PlayerRepository {
  Future<List<Player>> getPlayers();
  Future<Player?> getPlayerById(String id);
  Future<List<Player>> getPlayersByTeam(String teamId);

  /// 팔로워 수 기준 내림차순 정렬. 실제 연동 시에는 Firestore 전체 집계
  /// 값을 서버에서 정렬해 내려주는 API 호출로 교체된다.
  Future<List<Player>> getPlayersSortedByFollowers();

  /// 이름으로 선수를 검색한다.
  Future<List<Player>> searchPlayersByName(String query);

  /// 프로필 헤더에 쓰이는 신상 정보(키/몸무게/생년월일/드래프트 등).
  Future<PlayerBio> getPlayerBio(Player player);

  /// 시즌별 전체 스탯(최근 시즌이 0번 인덱스). 선수 상세 화면 필수 스펙의
  /// 모든 항목을 담고 있다.
  Future<List<PlayerSeasonStats>> getSeasonStatsHistory(Player player);

  /// 전체 선수의 이번 시즌 스탯. 스탯 리더 화면에서 부문별 랭킹을 낼 때 쓴다.
  Future<List<PlayerSeasonStats>> getCurrentSeasonStatsForAllPlayers();
}

/// 최신 시즌이 맨 앞에 오는 시즌 목록.
const kSeasons = ['2025-26', '2024-25', '2023-24'];

class MockPlayerRepository implements PlayerRepository {
  @override
  Future<List<Player>> getPlayers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return kMockPlayers;
  }

  @override
  Future<Player?> getPlayerById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return kMockPlayers.firstWhere((player) => player.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Player>> getPlayersByTeam(String teamId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return kMockPlayers.where((player) => player.teamId == teamId).toList();
  }

  @override
  Future<List<Player>> getPlayersSortedByFollowers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final sorted = [...kMockPlayers]
      ..sort((a, b) => b.followerCount.compareTo(a.followerCount));
    return sorted;
  }

  @override
  Future<List<Player>> searchPlayersByName(String query) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final sorted = [...kMockPlayers]
      ..sort((a, b) => b.followerCount.compareTo(a.followerCount));
    if (query.trim().isEmpty) return sorted;
    return sorted
        .where((player) => player.name.contains(query.trim()))
        .toList();
  }

  static const _colleges = [
    '연세대학교',
    '고려대학교',
    '중앙대학교',
    '경희대학교',
    '동국대학교',
    '한양대학교',
    '성균관대학교',
    '건국대학교',
  ];

  /// 포지션별 신장/체중 대략 범위 (cmMin, cmMax, kgMin, kgMax).
  (int, int, int, int) _bodyRangeFor(PlayerPosition position) =>
      switch (position) {
        PlayerPosition.pg => (178, 188, 75, 86),
        PlayerPosition.sg => (185, 193, 82, 90),
        PlayerPosition.sf => (193, 200, 88, 97),
        PlayerPosition.pf => (197, 205, 94, 104),
        PlayerPosition.c => (200, 210, 100, 116),
      };

  @override
  Future<PlayerBio> getPlayerBio(Player player) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final rng = StableRandom(stableSeed(['bio', player.id]));
    final (hMin, hMax, wMin, wMax) = _bodyRangeFor(player.position);
    final heightCm = hMin + rng.nextInt(hMax - hMin + 1);
    final weightKg = wMin + rng.nextInt(wMax - wMin + 1);

    final now = DateTime.now();
    final age = 21 + rng.nextInt(14); // 21 ~ 34세
    final birthMonth = 1 + rng.nextInt(12);
    final birthDay = 1 + rng.nextInt(28);
    final birthDate = DateTime(now.year - age, birthMonth, birthDay);

    final draftAge = 20 + rng.nextInt(3); // 보통 20~22세에 드래프트
    final draftYear = (now.year - age + draftAge).clamp(2008, now.year);

    return PlayerBio(
      heightCm: heightCm,
      weightKg: weightKg,
      birthDate: birthDate,
      country: '대한민국',
      college: _colleges[rng.nextInt(_colleges.length)],
      draftYear: draftYear,
      draftRound: 1 + rng.nextInt(2),
      draftPick: 1 + rng.nextInt(10),
    );
  }

  /// 포지션별 리바운드/어시스트/블록 가중치. 빅맨은 리바운드·블록이,
  /// 가드는 어시스트가 더 많게 만들어 그럴듯한 값을 낸다.
  (double, double, double) _positionWeights(PlayerPosition position) =>
      switch (position) {
        PlayerPosition.pg => (0.6, 1.8, 0.3),
        PlayerPosition.sg => (0.7, 1.1, 0.4),
        PlayerPosition.sf => (0.9, 0.9, 0.6),
        PlayerPosition.pf => (1.3, 0.6, 1.2),
        PlayerPosition.c => (1.5, 0.5, 1.6),
      };

  PlayerSeasonStats _seasonStatsFor(Player player, String season) {
    final rng = StableRandom(stableSeed(['season', player.id, season]));
    final tier = (player.followerCount / 4000).clamp(0, 4).toDouble();
    final (boardMult, astMult, blkMult) = _positionWeights(player.position);

    final fga = 2 + tier * 1.2 + rng.nextDouble() * 8;
    final fgPct = 0.38 + rng.nextDouble() * 0.14;
    final fgm = fga * fgPct;

    final tpa = rng.nextDouble() * (2 + tier);
    final tpPct = 0.24 + rng.nextDouble() * 0.16;
    var tpm = tpa * tpPct;
    if (tpm > fgm) tpm = fgm; // 3점 성공은 필드골 성공을 넘을 수 없다

    final fta = rng.nextDouble() * (1.5 + tier);
    final ftPct = 0.62 + rng.nextDouble() * 0.3;
    final ftm = fta * ftPct;

    final points = 2 * fgm + tpm + ftm;

    return PlayerSeasonStats(
      playerId: player.id,
      season: season,
      teamId: player.teamId,
      gamesPlayed: 28 + rng.nextInt(20),
      minutes: 8 + tier * 3 + rng.nextDouble() * 14,
      points: points,
      fgm: fgm,
      fga: fga,
      tpm: tpm,
      tpa: tpa,
      ftm: ftm,
      fta: fta,
      oreb: (0.5 + rng.nextDouble() * 2.5) * boardMult,
      dreb: (1.5 + rng.nextDouble() * 4.5) * boardMult,
      ast: (0.8 + rng.nextDouble() * 4) * astMult,
      tov: 0.5 + rng.nextDouble() * 2.5,
      stl: 0.3 + rng.nextDouble() * 1.4,
      blk: (0.1 + rng.nextDouble() * 1.3) * blkMult,
      pf: 1.0 + rng.nextDouble() * 2.8,
      plusMinus: -8 + rng.nextDouble() * 16 + tier * 1.5,
    );
  }

  @override
  Future<List<PlayerSeasonStats>> getSeasonStatsHistory(Player player) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return kSeasons.map((s) => _seasonStatsFor(player, s)).toList();
  }

  @override
  Future<List<PlayerSeasonStats>> getCurrentSeasonStatsForAllPlayers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return kMockPlayers
        .map((p) => _seasonStatsFor(p, kSeasons.first))
        .toList();
  }
}
