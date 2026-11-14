import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/app_user.dart';
import '../../providers/auth_providers.dart';
import '../../providers/onboarding_providers.dart';
import '../../providers/profile_providers.dart';
import '../main/main_shell.dart';
import '../onboarding/login_screen.dart';
import '../onboarding/nickname_screen.dart';
import '../onboarding/splash_screen.dart';
import '../onboarding/terms_consent_screen.dart';

/// 앱의 맨 아래 화면. 로그인 상태에 따라 무엇을 보여줄지 정한다.
///
/// - 로그인돼 있으면(이메일·게스트 모두) 곧장 앱으로 들어간다. 한 번 로그인한
///   사람에게 다시 로그인하라고 하지 않는다. 게스트도 같은 계정으로 이어져
///   닉네임·예측 기록이 그대로 남는다.
/// - 로그아웃 상태: 로그인한 적이 있으면 로그인 화면, 처음이면 시작 화면.
///
/// 로그인 화면은 로그인만 하고, 그 뒤 화면은 여기가 로그인 상태를 보고 바꾼다.
/// 로그아웃·탈퇴하면 이 화면이 알아서 처음으로 돌아간다.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedCredentialProvider);
    final authState = ref.watch(authStateProvider);

    if (savedAsync.isLoading || authState.isLoading) {
      return const _GateLoading();
    }

    final user = authState.valueOrNull;
    if (user != null) return _SignedIn(key: ValueKey(user.uid), user: user);
    if (savedAsync.valueOrNull != null) return const LoginScreen();
    return const SplashScreen();
  }
}

/// 로그인한 사람을 앱으로 들인다. 처음이면 약관 동의와 닉네임을 한 번 묻는다.
class _SignedIn extends ConsumerStatefulWidget {
  final AppUser user;

  const _SignedIn({super.key, required this.user});

  @override
  ConsumerState<_SignedIn> createState() => _SignedInState();
}

enum _Step { loading, terms, nickname, main }

class _SignedInState extends ConsumerState<_SignedIn> {
  var _step = _Step.loading;

  /// 닉네임을 이미 정했거나 한 번 물어봤는지.
  var _hasNickname = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final uid = widget.user.uid;
    var agreed = true;
    try {
      await _mergeFollows(uid);
      final profile = ref.read(userProfileRepositoryProvider);
      agreed = await profile.hasAgreedTerms(uid);
      _hasNickname = await profile.nicknameAsked(uid);
    } catch (_) {
      // 오프라인 등으로 못 읽으면 앱부터 연다. 처음 가입한 사람은 로그인할 때
      // 이미 온라인이었으므로, 여기 오는 건 동의를 마친 재방문자다.
    }
    if (!mounted) return;
    setState(() {
      _step = !agreed
          ? _Step.terms
          : (_hasNickname ? _Step.main : _Step.nickname);
    });
  }

  /// 서버에 저장된 팔로우를 불러오고, 온보딩에서 새로 고른 게 있으면 합쳐
  /// 저장한다(그냥 덮어쓰면 재로그인 때 기존 팔로우가 지워진다).
  Future<void> _mergeFollows(String uid) async {
    final followRepo = ref.read(userFollowRepositoryProvider);
    final localTeams = ref.read(followedTeamIdsProvider);
    final localPlayers = ref.read(followedPlayerIdsProvider);
    final saved = await followRepo.loadFollows(uid);
    final teamIds = {...saved.teamIds, ...localTeams};
    final playerIds = {...saved.playerIds, ...localPlayers};
    if (localTeams.isNotEmpty || localPlayers.isNotEmpty) {
      await followRepo.saveFollows(
        uid: uid,
        teamIds: teamIds,
        playerIds: playerIds,
      );
    }
    ref.read(followedTeamIdsProvider.notifier).state = teamIds;
    ref.read(followedPlayerIdsProvider.notifier).state = playerIds;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.loading => const _GateLoading(),
      _Step.terms => TermsConsentScreen(
        onAgree: () =>
            ref.read(userProfileRepositoryProvider).agreeTerms(widget.user.uid),
        onDone: () =>
            setState(() => _step = _hasNickname ? _Step.main : _Step.nickname),
      ),
      _Step.nickname => NicknameScreen(
        onDone: () {
          // 정했든 "나중에"를 골랐든 다시 묻지 않는다. 기록이 실패해도 들어간다.
          ref
              .read(userProfileRepositoryProvider)
              .markNicknameAsked(widget.user.uid)
              .catchError((_) {});
          setState(() => _step = _Step.main);
        },
      ),
      _Step.main => const MainShell(),
    };
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    // web/index.html의 첫 로딩 화면과 같은 모양: 로고 + 도는 동그라미.
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(),
            SizedBox(height: 40),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
