import 'package:basket_it/services/live_score_push.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('팀 id 모양으로 리그를 가른다: 숫자는 NBA, 영문은 KBL', () {
    expect(liveTeamKeys(['13', 'sk', '', '2', 'kogas']),
        {'nba:13', 'kbl:sk', 'nba:2', 'kbl:kogas'});
  });

  group('구독 문서 쓰기', () {
    late List<(String, Map<String, Object?>)> writes;
    LiveScoreSubscription make(String platform) {
      writes = [];
      return LiveScoreSubscription(
        platform: platform,
        write: (token, fields) async => writes.add((token, fields)),
      );
    }

    test('토큰이 생기기 전에는 쓰지 않고, 생기면 기억한 팀을 한 번에 쓴다', () async {
      final sub = make('android');
      await sub.setTeams(['sk', '13']);
      expect(writes, isEmpty);

      await sub.setFcmToken('fcm-1');
      expect(writes, hasLength(1));
      expect(writes.single.$1, 'fcm-1');
      expect(writes.single.$2, {
        'teamKeys': ['kbl:sk', 'nba:13'],
      });
    });

    test('팀이 같으면 다시 쓰지 않고, 바뀐 것만 쓴다', () async {
      final sub = make('android');
      await sub.setFcmToken('fcm-1');
      await sub.setTeams(['sk']);
      await sub.setTeams(['sk']);
      await sub.setTeams([]);
      expect(writes.map((w) => w.$2['teamKeys']).toList(), [
        <String>[],
        ['kbl:sk'],
        <String>[],
      ]);
      // Android 문서에는 iPhone 전용 필드를 넣지 않는다
      expect(writes.every((w) => !w.$2.containsKey('activityTokens')), isTrue);
    });

    test('토큰이 바뀌면 새 문서에 모든 값을 다시 쓴다', () async {
      final sub = make('ios');
      await sub.setFcmToken('fcm-1');
      await sub.setTeams(['13']);
      await sub.setPushToStartToken('p2s');
      await sub.setActivityTokens({'ABC-UUID': 'act-1'});
      writes.clear();

      await sub.setFcmToken('fcm-2');
      expect(writes.single.$1, 'fcm-2');
      expect(writes.single.$2, {
        'teamKeys': ['nba:13'],
        'pushToStartToken': 'p2s',
        'activityTokens': {'abc-uuid': 'act-1'},
      });
    });

    test('iPhone 활동 토큰은 attributes.id 소문자로, 끝난 활동은 빠진 채 통째로 쓴다', () async {
      final sub = make('ios');
      await sub.setFcmToken('fcm-1');
      writes.clear();

      await sub.setActivityTokens({'AAA': 't1', 'BBB': 't2'});
      await sub.setActivityTokens({'aaa': 't1', 'bbb': 't2'});
      await sub.setActivityTokens({'bbb': 't2'});
      expect(writes.map((w) => w.$2['activityTokens']).toList(), [
        {'aaa': 't1', 'bbb': 't2'},
        {'bbb': 't2'},
      ]);
    });
  });
}
