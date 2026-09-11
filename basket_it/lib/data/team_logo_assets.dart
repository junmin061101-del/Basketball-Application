/// KBL 구단 공식 아이콘(앱에 넣은 PNG). 키는 앱 팀 id.
///
/// KBL 홈페이지의 PNG 엠블럼은 가로로 긴 워드마크(예: 1620×296)라 동그란
/// 로고 자리에서는 점처럼 작아진다. 홈페이지가 순위표 등에 쓰는 정사각
/// 아이콘(/assets/img/ico/logo/ic-*.svg)을 그대로 PNG로 옮겨 넣었다.
/// 원격으로 받지 않아 CORS·핫링크 제한 없이 모바일과 웹에서 똑같이 그린다.
const kblLogoAssets = <String, String>{
  'sk': 'assets/logos/kbl/sk.png',
  'kgc': 'assets/logos/kbl/kgc.png',
  'db': 'assets/logos/kbl/db.png',
  'lg': 'assets/logos/kbl/lg.png',
  'kcc': 'assets/logos/kbl/kcc.png',
  'kt': 'assets/logos/kbl/kt.png',
  'kogas': 'assets/logos/kbl/kogas.png',
  'sono': 'assets/logos/kbl/sono.png',
  'mobis': 'assets/logos/kbl/mobis.png',
  'samsung': 'assets/logos/kbl/samsung.png',
};
