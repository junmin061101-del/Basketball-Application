import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/onboarding_providers.dart';
import '../../services/live_score_push.dart';
import '../community/community_tab.dart';
import '../explore/explore_tab.dart';
import '../games/games_tab.dart';
import '../home/home_tab.dart';
import '../prediction/prediction_tab.dart';

/// 로그인 이후 항상 고정으로 보여지는 하단 탭 5개(홈/게임/예측/커뮤니티/탐색) 뼈대.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 팔로우한 팀 경기가 진행 중이면 잠금화면에 스코어가 뜨도록 기기를 등록한다.
    // Firebase가 없는 환경(웹·테스트)에서는 아무것도 하지 않는다.
    if (Firebase.apps.isEmpty) return;
    final push = LiveScorePushService.start();
    if (push == null) return;
    push.updateTeams(ref.read(followedTeamIdsProvider));
    ref.listenManual(
      followedTeamIdsProvider,
      (_, next) => push.updateTeams(next),
    );
  }

  static const _tabs = [
    HomeTab(),
    GamesTab(),
    PredictionTab(),
    CommunityTab(),
    ExploreTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _tabs),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_basketball_outlined),
            activeIcon: Icon(Icons.sports_basketball),
            label: '게임',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_vote_outlined),
            activeIcon: Icon(Icons.how_to_vote),
            label: '예측',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: '커뮤니티',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: '탐색',
          ),
        ],
      ),
    );
  }
}
