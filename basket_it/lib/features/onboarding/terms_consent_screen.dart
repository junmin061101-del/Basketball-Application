import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../legal/policy_detail_screen.dart';
import '../legal/policy_documents.dart';

/// 온보딩 - 이용약관·개인정보처리방침 동의.
///
/// 커뮤니티·예측 토론처럼 사용자가 글을 쓰는 앱은, 부적절한 콘텐츠를 허용하지
/// 않는다는 약관에 동의를 받아야 한다(App Store 심사 기준 1.2). 로그인 뒤
/// 아직 동의하지 않은 사람에게 한 번 보여주고, 두 항목에 모두 동의해야 들어간다.
class TermsConsentScreen extends StatefulWidget {
  /// 동의를 저장한다. 실패하면 던진다.
  final Future<void> Function() onAgree;

  /// 저장한 뒤 다음 화면으로.
  final VoidCallback onDone;

  const TermsConsentScreen({
    super.key,
    required this.onAgree,
    required this.onDone,
  });

  @override
  State<TermsConsentScreen> createState() => _TermsConsentScreenState();
}

class _TermsConsentScreenState extends State<TermsConsentScreen> {
  var _terms = false;
  var _privacy = false;
  var _saving = false;

  Future<void> _agree() async {
    setState(() => _saving = true);
    try {
      await widget.onAgree();
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('동의를 저장하지 못했어요: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                '약관에 동의해 주세요',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              const Text(
                'Baskit은 욕설·혐오·음란·괴롭힘 등 부적절한 게시물을 허용하지 않아요. '
                '신고된 게시물은 24시간 안에 확인해 삭제하고, 작성자의 이용을 제한할 수 있어요.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              _ConsentRow(
                label: '[필수] 이용약관 동의',
                value: _terms,
                onChanged: (v) => setState(() => _terms = v),
                document: termsOfService,
              ),
              _ConsentRow(
                label: '[필수] 개인정보처리방침 동의',
                value: _privacy,
                onChanged: (v) => setState(() => _privacy = v),
                document: privacyPolicy,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _terms && _privacy && !_saving ? _agree : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('동의하고 시작하기'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final PolicyDocument document;

  const _ConsentRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            title: Text(label, style: const TextStyle(fontSize: 15)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PolicyDetailScreen(document: document),
            ),
          ),
          child: const Text('보기'),
        ),
      ],
    );
  }
}
