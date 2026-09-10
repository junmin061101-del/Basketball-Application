import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/award_race.dart';
import 'repository_providers.dart';

/// NBA 수상 레이스. KBL에는 이런 사다리가 없어 NBA 데이터만 읽는다.
final awardRacesProvider = FutureProvider<AwardRaces>((ref) {
  return ref.watch(nbaSourceProvider).awardRaces();
});
