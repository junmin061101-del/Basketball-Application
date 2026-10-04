import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/account_actions.dart';
import '../../providers/auth_providers.dart';
import '../../providers/push_settings.dart';
import '../../services/live_score_push.dart';
import '../legal/policy_detail_screen.dart';
import '../legal/policy_documents.dart';

/// 설정 화면: 계정 정보, 약관 문서, 로그아웃, 회원 탈퇴.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isGuest = user?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: AbsorbPointer(
        absorbing: _working,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _Card(
              children: [
                _AccountRow(
                  title: isGuest ? '게스트로 이용 중' : (user?.email ?? ''),
                  subtitle: isGuest
                      ? '기기를 바꾸면 팔로우·예측 기록이 이어지지 않아요'
                      : '이메일로 로그인했어요',
                ),
              ],
            ),
            if (LiveScorePushService.supported) ...[
              const _SectionLabel('알림'),
              _Card(children: [_PushToggle()]),
            ],
            const _SectionLabel('약관'),
            _Card(
              children: [
                _MenuRow(
                  label: termsOfService.title,
                  onTap: () => _openPolicy(termsOfService),
                ),
                const Divider(height: 1, color: AppColors.border),
                _MenuRow(
                  label: privacyPolicy.title,
                  onTap: () => _openPolicy(privacyPolicy),
                ),
              ],
            ),
            const _SectionLabel('계정'),
            _Card(
              children: [
                _MenuRow(label: '로그아웃', onTap: _confirmSignOut),
                const Divider(height: 1, color: AppColors.border),
                _MenuRow(
                  label: '회원 탈퇴',
                  danger: true,
                  onTap: _confirmDelete,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Baskit · KBL 팬을 위한 앱\n문의: $contactEmail',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.textTertiary,
              ),
            ),
            if (_working) ...[
              const SizedBox(height: 20),
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openPolicy(PolicyDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PolicyDetailScreen(document: document),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final yes = await _confirm(
      title: '로그아웃할까요?',
      body: '다시 로그인하면 팔로우와 예측 기록을 그대로 볼 수 있어요.',
      action: '로그아웃',
    );
    if (!yes) return;
    await _run(() => ref.read(authRepositoryProvider).signOut());
  }

  Future<void> _confirmDelete() async {
    final yes = await _confirm(
      title: '정말 탈퇴할까요?',
      body:
          '계정과 팔로우·예측 기록이 바로 지워지고 되돌릴 수 없어요.\n'
          '커뮤니티에 쓴 글과 댓글은 대화 맥락을 위해 남지만, 글쓴이는 '
          '"$anonymousName"으로 바뀌어 누가 썼는지 알 수 없게 됩니다.',
      action: '탈퇴하기',
      danger: true,
    );
    if (!yes) return;
    await _run(() => deleteAccount(ref));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              action,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: danger ? AppColors.negative : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 처리 중에는 화면을 잠그고, 실패하면 이유를 알려 준다.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
      // 로그인 상태가 바뀌면 AuthGate가 알아서 첫 화면으로 되돌린다.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// 잠금화면 실시간 스코어 알림 켜기/끄기.
class _PushToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(livePushEnabledProvider).valueOrNull ?? true;
    return SwitchListTile.adaptive(
      value: enabled,
      onChanged: (value) =>
          ref.read(livePushEnabledProvider.notifier).set(value),
      activeTrackColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: const Text(
        '실시간 경기 알림',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: const Text(
        '팔로우한 팀 경기가 열리면 잠금화면에 점수를 보여줘요',
        style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AccountRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _MenuRow({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: danger ? AppColors.negative : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: danger ? AppColors.negative : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
