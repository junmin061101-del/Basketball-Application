import 'dart:convert';
import 'dart:io';

import 'package:basket_it/data/repositories/league_data_source.dart';
import 'package:basket_it/data/team_logo_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('KBL 10개 구단 로고 파일이 모두 앱에 들어 있다', () {
    expect(
      kblLogoAssets.keys,
      unorderedEquals([
        'sk',
        'kgc',
        'db',
        'lg',
        'kcc',
        'kt',
        'kogas',
        'sono',
        'mobis',
        'samsung',
      ]),
    );
    for (final path in kblLogoAssets.values) {
      expect(File(path).existsSync(), isTrue, reason: '$path 파일이 없다');
    }
  });

  test('KBL 팀은 앱 로고를, NBA 팀은 원격 로고를 쓴다', () async {
    final body = {
      'teams': [
        {
          'id': 'lg',
          'city': '창원',
          'name': 'LG',
          'shortName': 'LG',
          'color': '#550E10',
          'logo': 'https://www.kbl.or.kr/assets/img/club/lg/emblem-lg01.png',
        },
        {
          'id': '13',
          'city': 'LA',
          'name': '레이커스',
          'shortName': 'LA 레이커스',
          'color': '#552583',
          'logo': 'https://a.espncdn.com/i/teamlogos/nba/500/lal.png',
        },
      ],
    };
    final source = LeagueDataSource(
      baseUrl: 'https://example.test/x',
      leagueLabel: 'TEST',
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode(jsonEncode(body)), 200),
      ),
    );
    final teams = await source.teams();
    expect(teams.first.logoAsset, 'assets/logos/kbl/lg.png');
    expect(teams.last.logoAsset, isNull);
    expect(teams.last.logoUrl, endsWith('lal.png'));
  });
}
