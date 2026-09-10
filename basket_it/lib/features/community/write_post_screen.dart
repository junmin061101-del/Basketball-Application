import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/name_mask.dart';
import '../../data/models/community_post.dart';
import '../../providers/community_providers.dart';
import '../../providers/prediction_providers.dart';

/// 커뮤니티 글쓰기 화면.
class WritePostScreen extends ConsumerStatefulWidget {
  const WritePostScreen({super.key});

  @override
  ConsumerState<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends ConsumerState<WritePostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  PostCategory _category = PostCategory.free;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty && !_submitting;

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    final title = _titleController.text.trim();
    if (user == null || title.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .createPost(
            CommunityPost(
              id: '',
              uid: user.uid,
              // 공용 컬렉션에 원본 이름이 남지 않도록 저장 시점에 마스킹한다.
              displayName: maskDisplayName(user.displayName),
              category: _category,
              title: title,
              body: _bodyController.text.trim(),
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('글을 올리지 못했어요: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('글쓰기'),
        actions: [
          TextButton(
            onPressed: _canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    '등록',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _canSubmit
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text('말머리', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in PostCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: _category == c
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _category == c
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: '제목을 입력하세요',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLength: 2000,
              maxLines: 12,
              minLines: 8,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                hintText: '내용을 자유롭게 적어주세요',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '작성자는 익명으로 표시돼요. 서로 존중하는 대화를 부탁드려요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
