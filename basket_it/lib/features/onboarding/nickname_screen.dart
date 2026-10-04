import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/nickname.dart';
import '../../providers/profile_providers.dart';

/// 온보딩 - 닉네임 정하기.
///
/// 처음 들어온 사람에게 한 번 묻는다. 커뮤니티 글과 예측 토론에 이 이름이
/// 그대로 보인다. 나중에 설정에서 바꿀 수 있어서 여기서는 건너뛸 수 있다.
class NicknameScreen extends ConsumerStatefulWidget {
  /// 닉네임을 정했거나 건너뛴 뒤에 할 일(메인으로 들어간다).
  final VoidCallback onDone;

  const NicknameScreen({super.key, required this.onDone});

  @override
  ConsumerState<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends ConsumerState<NicknameScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = normalizeNickname(_controller.text);
    final error = nicknameError(name);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(nicknameProvider.notifier).save(name);
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('닉네임을 저장하지 못했어요: $e')));
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
                '어떤 이름으로 부를까요?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              const Text(
                '커뮤니티 글과 예측 토론에 이 이름이 보여요.\n나중에 설정에서 바꿀 수 있어요.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: nicknameMaxLength,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _save(),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '닉네임',
                  errorText: _error,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '한글·영문·숫자·밑줄 $nicknameMinLength~$nicknameMaxLength자',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('시작하기'),
                ),
              ),
              TextButton(
                onPressed: _saving ? null : widget.onDone,
                child: const Text('나중에 정할게요'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
