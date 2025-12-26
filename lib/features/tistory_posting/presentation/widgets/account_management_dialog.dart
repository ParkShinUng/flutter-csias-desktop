import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountManagementDialog extends ConsumerStatefulWidget {
  const AccountManagementDialog({super.key});

  @override
  ConsumerState<AccountManagementDialog> createState() => _AccountManagementDialogState();
}

class _AccountManagementDialogState extends ConsumerState<AccountManagementDialog> {
  String? _editingId;
  bool _isAdding = false;
  bool _hasKoreanInPassword = false;

  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _blogController = TextEditingController();

  static final _koreanRegex = RegExp(r'[ㄱ-ㅎㅏ-ㅣ가-힣]');

  @override
  void initState() {
    super.initState();
    _pwController.addListener(_checkKoreanInPassword);
  }

  void _checkKoreanInPassword() {
    final hasKorean = _koreanRegex.hasMatch(_pwController.text);
    if (hasKorean != _hasKoreanInPassword) {
      setState(() {
        _hasKoreanInPassword = hasKorean;
      });
    }
  }

  @override
  void dispose() {
    _pwController.removeListener(_checkKoreanInPassword);
    _idController.dispose();
    _pwController.dispose();
    _blogController.dispose();
    super.dispose();
  }

  void _startAdding() {
    setState(() {
      _isAdding = true;
      _editingId = null;
      _idController.clear();
      _pwController.clear();
      _blogController.clear();
    });
  }

  void _startEditing(TistoryAccount account) {
    setState(() {
      _isAdding = false;
      _editingId = account.id;
      _idController.text = account.kakaoId;
      _pwController.text = account.password;
      _blogController.text = account.blogName;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isAdding = false;
      _editingId = null;
      _hasKoreanInPassword = false;
      _idController.clear();
      _pwController.clear();
      _blogController.clear();
    });
  }

  Future<void> _save() async {
    final kakaoId = _idController.text.trim();
    final password = _pwController.text.trim();
    final blogName = _blogController.text.trim();

    if (kakaoId.isEmpty || password.isEmpty || blogName.isEmpty) {
      return;
    }

    if (_hasKoreanInPassword) {
      return;
    }

    final controller = ref.read(tistoryPostingProvider.notifier);

    if (_isAdding) {
      await controller.addAccount(TistoryAccount(
        id: '',
        kakaoId: kakaoId,
        password: password,
        blogName: blogName,
      ));
    } else if (_editingId != null) {
      await controller.updateAccount(TistoryAccount(
        id: _editingId!,
        kakaoId: kakaoId,
        password: password,
        blogName: blogName,
      ));
    }

    _cancelEdit();
  }

  Future<void> _delete(String accountId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 삭제'),
        content: const Text('이 계정을 삭제하시겠습니까?\n저장된 로그인 정보도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(tistoryPostingProvider.notifier).deleteAccount(accountId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accounts = ref.watch(tistoryPostingProvider).accounts;

    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  '계정 관리',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),

            // Account List
            Flexible(
              child: accounts.isEmpty && !_isAdding
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_circle_outlined,
                            size: 48,
                            color: scheme.outline,
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Text(
                            '등록된 계정이 없습니다',
                            style: TextStyle(color: scheme.outline),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        ...accounts.map((account) {
                          final isEditing = _editingId == account.id;
                          return _buildAccountTile(account, isEditing);
                        }),
                        if (_isAdding) _buildEditForm(null),
                      ],
                    ),
            ),

            const SizedBox(height: AppSpacing.s16),

            // Add Button
            if (!_isAdding && _editingId == null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _startAdding,
                  icon: const Icon(Icons.add),
                  label: const Text('새 계정 추가'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTile(TistoryAccount account, bool isEditing) {
    if (isEditing) {
      return _buildEditForm(account);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: ListTile(
        leading: const Icon(Icons.account_circle),
        title: Text(account.kakaoId),
        subtitle: Text(account.blogName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _startEditing(account),
              icon: const Icon(Icons.edit_outlined),
              tooltip: '수정',
            ),
            IconButton(
              onPressed: () => _delete(account.id),
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(TistoryAccount? account) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account == null ? '새 계정 추가' : '계정 수정',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Kakao ID',
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _pwController,
              decoration: InputDecoration(
                labelText: 'Password',
                isDense: true,
                errorText: _hasKoreanInPassword ? '영문, 숫자, 특수문자만 입력 가능합니다' : null,
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _blogController,
              decoration: const InputDecoration(
                labelText: 'Blog Name',
                hintText: '예) my-blog-name',
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _cancelEdit,
                  child: const Text('취소'),
                ),
                const SizedBox(width: AppSpacing.s8),
                FilledButton(
                  onPressed: _save,
                  child: Text(account == null ? '추가' : '저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAccountManagementDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const AccountManagementDialog(),
  );
}
