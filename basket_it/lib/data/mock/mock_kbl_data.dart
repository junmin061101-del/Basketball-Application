import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/team.dart';

/// KBL 10개 구단 목업 데이터.
///
/// 실제 로고 에셋이 준비되기 전까지 각 팀의 [Team.primaryColor] +
/// [Team.shortName]으로 카드/로고를 대체 표시한다.
const List<Team> kMockTeams = [
  Team(
    id: 'sk',
    city: '서울',
    name: 'SK',
    shortName: 'SK',
    primaryColor: Color(0xFFF5811F),
  ),
  Team(
    id: 'kgc',
    city: '안양',
    name: '정관장',
    shortName: 'KGC',
    primaryColor: Color(0xFF8E1B3A),
  ),
  Team(
    id: 'db',
    city: '원주',
    name: 'DB',
    shortName: 'DB',
    primaryColor: Color(0xFF0057B8),
  ),
  Team(
    id: 'lg',
    city: '창원',
    name: 'LG',
    shortName: 'LG',
    primaryColor: Color(0xFFC8102E),
  ),
  Team(
    id: 'kcc',
    city: '부산',
    name: 'KCC',
    shortName: 'KCC',
    primaryColor: Color(0xFF1F7A4D),
  ),
  Team(
    id: 'kt',
    city: '수원',
    name: 'KT',
    shortName: 'KT',
    primaryColor: Color(0xFF17A6A0),
  ),
  Team(
    id: 'kogas',
    city: '대구',
    name: '한국가스공사',
    shortName: 'KOGAS',
    primaryColor: Color(0xFF2A3F8F),
  ),
  Team(
    id: 'sono',
    city: '고양',
    name: '소노',
    shortName: 'SONO',
    primaryColor: Color(0xFF3AAEE0),
  ),
  Team(
    id: 'mobis',
    city: '울산',
    name: '현대모비스',
    shortName: 'MOBIS',
    primaryColor: Color(0xFF002856),
  ),
  Team(
    id: 'samsung',
    city: '서울',
    name: '삼성',
    shortName: 'SAMSUNG',
    primaryColor: Color(0xFF4C2A85),
  ),
];

/// 팀별 선수단 목업 데이터. 팔로워 수는 Firestore 전체 집계를 대신하는
/// 목업 값으로, 실제 API 연동 시 서버 집계 값으로 교체된다.
const List<Player> kMockPlayers = [
  // 서울 SK
  Player(id: 'sk-1', name: '김선우', teamId: 'sk', position: PlayerPosition.sg, backNumber: 7, followerCount: 15200),
  Player(id: 'sk-2', name: '이재헌', teamId: 'sk', position: PlayerPosition.pf, backNumber: 23, followerCount: 9800),
  Player(id: 'sk-3', name: '박도윤', teamId: 'sk', position: PlayerPosition.pg, backNumber: 3, followerCount: 6400),
  Player(id: 'sk-4', name: '최현우', teamId: 'sk', position: PlayerPosition.c, backNumber: 51, followerCount: 5100),
  Player(id: 'sk-5', name: '정승민', teamId: 'sk', position: PlayerPosition.sf, backNumber: 11, followerCount: 3200),
  Player(id: 'sk-6', name: '강태양', teamId: 'sk', position: PlayerPosition.sg, backNumber: 9, followerCount: 1800),

  // 안양 정관장
  Player(id: 'kgc-1', name: '오지훈', teamId: 'kgc', position: PlayerPosition.pf, backNumber: 10, followerCount: 13700),
  Player(id: 'kgc-2', name: '조민재', teamId: 'kgc', position: PlayerPosition.pg, backNumber: 1, followerCount: 8600),
  Player(id: 'kgc-3', name: '윤성훈', teamId: 'kgc', position: PlayerPosition.c, backNumber: 44, followerCount: 5700),
  Player(id: 'kgc-4', name: '장동현', teamId: 'kgc', position: PlayerPosition.sg, backNumber: 21, followerCount: 4300),
  Player(id: 'kgc-5', name: '임재영', teamId: 'kgc', position: PlayerPosition.sf, backNumber: 8, followerCount: 2600),
  Player(id: 'kgc-6', name: '한도현', teamId: 'kgc', position: PlayerPosition.pg, backNumber: 6, followerCount: 1200),

  // 원주 DB
  Player(id: 'db-1', name: '서준영', teamId: 'db', position: PlayerPosition.sf, backNumber: 32, followerCount: 16800),
  Player(id: 'db-2', name: '신우진', teamId: 'db', position: PlayerPosition.pg, backNumber: 4, followerCount: 10200),
  Player(id: 'db-3', name: '권민준', teamId: 'db', position: PlayerPosition.c, backNumber: 55, followerCount: 6100),
  Player(id: 'db-4', name: '황시우', teamId: 'db', position: PlayerPosition.sg, backNumber: 13, followerCount: 4700),
  Player(id: 'db-5', name: '안준서', teamId: 'db', position: PlayerPosition.pf, backNumber: 25, followerCount: 3000),
  Player(id: 'db-6', name: '송지환', teamId: 'db', position: PlayerPosition.sg, backNumber: 17, followerCount: 1500),

  // 창원 LG
  Player(id: 'lg-1', name: '전현식', teamId: 'lg', position: PlayerPosition.c, backNumber: 41, followerCount: 12400),
  Player(id: 'lg-2', name: '홍준우', teamId: 'lg', position: PlayerPosition.pg, backNumber: 2, followerCount: 9100),
  Player(id: 'lg-3', name: '김태민', teamId: 'lg', position: PlayerPosition.sf, backNumber: 15, followerCount: 5900),
  Player(id: 'lg-4', name: '이원준', teamId: 'lg', position: PlayerPosition.sg, backNumber: 24, followerCount: 4100),
  Player(id: 'lg-5', name: '박건우', teamId: 'lg', position: PlayerPosition.pf, backNumber: 33, followerCount: 2400),
  Player(id: 'lg-6', name: '최은우', teamId: 'lg', position: PlayerPosition.pg, backNumber: 5, followerCount: 1100),

  // 부산 KCC
  Player(id: 'kcc-1', name: '정승우', teamId: 'kcc', position: PlayerPosition.pf, backNumber: 20, followerCount: 18500),
  Player(id: 'kcc-2', name: '강도현', teamId: 'kcc', position: PlayerPosition.pg, backNumber: 0, followerCount: 11300),
  Player(id: 'kcc-3', name: '조현우', teamId: 'kcc', position: PlayerPosition.c, backNumber: 50, followerCount: 7200),
  Player(id: 'kcc-4', name: '윤재현', teamId: 'kcc', position: PlayerPosition.sg, backNumber: 12, followerCount: 4900),
  Player(id: 'kcc-5', name: '임시윤', teamId: 'kcc', position: PlayerPosition.sf, backNumber: 27, followerCount: 2900),
  Player(id: 'kcc-6', name: '한유진', teamId: 'kcc', position: PlayerPosition.sg, backNumber: 14, followerCount: 1400),

  // 수원 KT
  Player(id: 'kt-1', name: '오태민', teamId: 'kt', position: PlayerPosition.sg, backNumber: 9, followerCount: 10600),
  Player(id: 'kt-2', name: '서동현', teamId: 'kt', position: PlayerPosition.pg, backNumber: 1, followerCount: 8300),
  Player(id: 'kt-3', name: '신재영', teamId: 'kt', position: PlayerPosition.c, backNumber: 45, followerCount: 5400),
  Player(id: 'kt-4', name: '권준서', teamId: 'kt', position: PlayerPosition.pf, backNumber: 31, followerCount: 3700),
  Player(id: 'kt-5', name: '황민준', teamId: 'kt', position: PlayerPosition.sf, backNumber: 18, followerCount: 2200),
  Player(id: 'kt-6', name: '안현우', teamId: 'kt', position: PlayerPosition.sg, backNumber: 22, followerCount: 900),

  // 대구 한국가스공사
  Player(id: 'kogas-1', name: '송민석', teamId: 'kogas', position: PlayerPosition.c, backNumber: 42, followerCount: 9700),
  Player(id: 'kogas-2', name: '전준영', teamId: 'kogas', position: PlayerPosition.pg, backNumber: 3, followerCount: 7500),
  Player(id: 'kogas-3', name: '홍시우', teamId: 'kogas', position: PlayerPosition.sf, backNumber: 19, followerCount: 4600),
  Player(id: 'kogas-4', name: '김도윤', teamId: 'kogas', position: PlayerPosition.pf, backNumber: 29, followerCount: 3100),
  Player(id: 'kogas-5', name: '이승민', teamId: 'kogas', position: PlayerPosition.sg, backNumber: 8, followerCount: 1900),
  Player(id: 'kogas-6', name: '박재헌', teamId: 'kogas', position: PlayerPosition.pg, backNumber: 6, followerCount: 700),

  // 고양 소노
  Player(id: 'sono-1', name: '최준우', teamId: 'sono', position: PlayerPosition.sf, backNumber: 30, followerCount: 8900),
  Player(id: 'sono-2', name: '정도현', teamId: 'sono', position: PlayerPosition.pg, backNumber: 2, followerCount: 6800),
  Player(id: 'sono-3', name: '강현식', teamId: 'sono', position: PlayerPosition.c, backNumber: 40, followerCount: 4200),
  Player(id: 'sono-4', name: '조태양', teamId: 'sono', position: PlayerPosition.sg, backNumber: 16, followerCount: 2800),
  Player(id: 'sono-5', name: '윤민재', teamId: 'sono', position: PlayerPosition.pf, backNumber: 26, followerCount: 1600),
  Player(id: 'sono-6', name: '장시우', teamId: 'sono', position: PlayerPosition.pg, backNumber: 4, followerCount: 600),

  // 울산 현대모비스
  Player(id: 'mobis-1', name: '임도윤', teamId: 'mobis', position: PlayerPosition.pf, backNumber: 34, followerCount: 14300),
  Player(id: 'mobis-2', name: '한재현', teamId: 'mobis', position: PlayerPosition.pg, backNumber: 5, followerCount: 9400),
  Player(id: 'mobis-3', name: '오승우', teamId: 'mobis', position: PlayerPosition.c, backNumber: 53, followerCount: 6600),
  Player(id: 'mobis-4', name: '서민준', teamId: 'mobis', position: PlayerPosition.sg, backNumber: 10, followerCount: 4000),
  Player(id: 'mobis-5', name: '신동현', teamId: 'mobis', position: PlayerPosition.sf, backNumber: 21, followerCount: 2500),
  Player(id: 'mobis-6', name: '권현우', teamId: 'mobis', position: PlayerPosition.sg, backNumber: 15, followerCount: 1000),

  // 서울 삼성
  Player(id: 'samsung-1', name: '황준서', teamId: 'samsung', position: PlayerPosition.sg, backNumber: 11, followerCount: 11900),
  Player(id: 'samsung-2', name: '안태민', teamId: 'samsung', position: PlayerPosition.pg, backNumber: 7, followerCount: 8100),
  Player(id: 'samsung-3', name: '송현우', teamId: 'samsung', position: PlayerPosition.c, backNumber: 47, followerCount: 5300),
  Player(id: 'samsung-4', name: '전재영', teamId: 'samsung', position: PlayerPosition.pf, backNumber: 28, followerCount: 3400),
  Player(id: 'samsung-5', name: '김시윤', teamId: 'samsung', position: PlayerPosition.sf, backNumber: 13, followerCount: 2000),
  Player(id: 'samsung-6', name: '이도현', teamId: 'samsung', position: PlayerPosition.pg, backNumber: 1, followerCount: 800),
];
