import '../models/player.dart';
import '../models/player_bio.dart';
import '../models/player_season_stats.dart';
import 'collected_repositories.dart';

/// KBL 선수. 명단·사진·기록 모두 KBL 공식 홈페이지 데이터다.
class KblPlayerRepository extends CollectedPlayerRepository {
  KblPlayerRepository(super.source);

  /// KBL 홈페이지 API에는 선수 신상(키·몸무게·생년월일·출신교·드래프트)이
  /// 없다. 지어내지 않고 모른다고 둔다. 선수 상세는 신상 칸을 숨긴다.
  @override
  Future<PlayerBio> getPlayerBio(Player player) async {
    return const PlayerBio.unknown();
  }

  /// 수집기가 최근 정규시즌마다 모아 둔 기록. 최근 시즌이 맨 앞이다.
  /// 한 경기도 뛰지 않은 선수(신인 등)는 빈 목록이다.
  @override
  Future<List<PlayerSeasonStats>> getSeasonStatsHistory(Player player) async {
    final byPlayer = await source.playerSeasons();
    return byPlayer[player.id] ?? const [];
  }
}
