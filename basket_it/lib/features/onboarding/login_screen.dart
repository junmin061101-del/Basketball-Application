import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/auth_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/credential_store.dart';
import '../../providers/auth_providers.dart';
import '../../providers/onboarding_providers.dart';
import '../main/main_shell.dart';
import 'signup_screen.dart';

/// 온보딩 - 로그인 화면.
///
/// Firebase Authentication(이메일/비밀번호)으로 로그인하거나, 계정 없이
/// 게스트(익명)로 둘러볼 수 있다. 어느 쪽이든 온보딩 중 선택한 팔로우
/// 팀/선수를 Firestore에 저장하고 메인으로 진입한다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _guestSubmitting = false;

  /// 아이디·비밀번호 저장 여부. 저장된 값이 있으면 켠 상태로 시작한다.
  bool _rememberMe = true;
  bool _prefilled = false;

  /// 저장된 자격증명을 입력칸에 한 번만 채워 넣는다.
  void _prefill(SavedCredential? saved) {
    if (_prefilled) return;
    _prefilled = true;
    // 저장된 값이 없으면 입력칸만 비워두고, 저장 옵션은 켠 상태로 둔다.
    if (saved == null) return;
    _emailController.text = saved.email;
    _passwordController.text = saved.password;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _busy => _submitting || _guestSubmitting;

  Future<void> _finishLogin(AppUser user) async {
    final followRepo = ref.read(userFollowRepositoryProvider);
    final localTeams = ref.read(followedTeamIdsProvider);
    final localPlayers = ref.read(followedPlayerIdsProvider);

    // 온보딩을 건너뛴 재로그인이면 서버에 저장된 팔로우를 그대로 불러오고,
    // 온보딩에서 새로 고른 게 있으면 기존 값과 합쳐서 저장한다.
    // (그냥 덮어쓰면 재로그인 때 기존 팔로우가 지워진다)
    final saved = await followRepo.loadFollows(user.uid);
    final teamIds = {...saved.teamIds, ...localTeams};
    final playerIds = {...saved.playerIds, ...localPlayers};

    if (localTeams.isNotEmpty || localPlayers.isNotEmpty) {
      await followRepo.saveFollows(
        uid: user.uid,
        teamIds: teamIds,
        playerIds: playerIds,
      );
    }
    ref.read(followedTeamIdsProvider.notifier).state = teamIds;
    ref.read(followedPlayerIdsProvider.notifier).state = playerIds;

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _showError(AuthException e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final user = await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);

      // 로그인에 성공한 자격증명만 저장한다.
      final store = ref.read(credentialStoreProvider);
      if (_rememberMe) {
        await store.save(SavedCredential(email: email, password: password));
      } else {
        await store.clear();
      }
      await _finishLogin(user);
    } on AuthException catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _guestSubmitting = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInAnonymously();
      await _finishLogin(user);
    } on AuthException catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _guestSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 저장된 자격증명이 있으면 입력칸을 미리 채워, 로그인 버튼만 누르면 되게 한다.
    ref.listen(savedCredentialProvider, (_, next) {
      final saved = next.valueOrNull;
      if (next.hasValue) setState(() => _prefill(saved));
    });
    final savedAsync = ref.watch(savedCredentialProvider);
    if (savedAsync.hasValue && !_prefilled) {
      _prefill(savedAsync.valueOrNull);
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('로그인', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  '팔로우한 팀과 선수를 계정에 저장해요',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: '이메일'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이메일을 입력해주세요';
                    }
                    if (!value.contains('@')) return '올바른 이메일 형식이 아니에요';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return '비밀번호는 6자 이상이어야 해요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _busy
                      ? null
                      : () => setState(() => _rememberMe = !_rememberMe),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: _busy
                                ? null
                                : (v) =>
                                      setState(() => _rememberMe = v ?? false),
                            activeColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '아이디·비밀번호 저장',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text('로그인'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _continueAsGuest,
                    icon: _guestSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : const Icon(Icons.person_outline, size: 20),
                    label: const Text('게스트로 둘러보기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    '게스트도 승부예측·팔로우를 쓸 수 있어요. 기기를 바꾸면 기록이 이어지지 않아요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(text: '계정이 없으신가요? '),
                          TextSpan(
                            text: '회원가입',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
