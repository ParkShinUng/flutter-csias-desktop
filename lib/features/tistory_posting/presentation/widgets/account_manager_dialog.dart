import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountManagerDialog extends ConsumerStatefulWidget {
  const AccountManagerDialog({super.key});

  @override
  ConsumerState<AccountManagerDialog> createState() =>
      _AccountManagerDialogState();
}

class _AccountManagerDialogState extends ConsumerState<AccountManagerDialog> {
  TistoryAccount? _selected;

  final _kakaoId = TextEditingController();
  final _pw = TextEditingController();
  final _blog = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _kakaoId.dispose();
    _pw.dispose();
    _blog.dispose();
    super.dispose();
  }

  void _fill(TistoryAccount? a) {
    _selected = a;
    _kakaoId.text = a?.kakaoId ?? "";
    _blog.text = a?.blogName ?? "";
    _pw.text = a?.password ?? "";
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(tistoryPostingProvider);

      final preferred = state.selectedAccountId == null
          ? null
          : state.accounts.cast<TistoryAccount?>().firstWhere(
              (a) => a!.id == state.selectedAccountId,
              orElse: () => null,
            );

      _fill(
        preferred ?? (state.accounts.isNotEmpty ? state.accounts.first : null),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tistoryPostingProvider);
    final controller = ref.read(tistoryPostingProvider.notifier);

    final isEdit = _selected != null;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    "티스토리 계정 관리",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: "닫기",
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 10),

              Expanded(
                child: Row(
                  children: [
                    // LEFT: account list
                    SizedBox(
                      width: 320,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "계정 목록",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              FilledButton.tonalIcon(
                                onPressed: () => _fill(null), // ✅ 새 계정 모드
                                icon: const Icon(Icons.add),
                                label: const Text("새 계정"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: ListView.separated(
                                itemCount: state.accounts.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final a = state.accounts[i];
                                  final selected = _selected?.id == a.id;

                                  return ListTile(
                                    dense: true,
                                    selected: selected,
                                    leading: const Icon(
                                      Icons.person_outline,
                                      size: 18,
                                    ),
                                    title: Text(
                                      a.kakaoId,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      a.blogName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _fill(a),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // RIGHT: form
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? "계정 수정" : "새 계정 등록",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _kakaoId,
                              decoration: const InputDecoration(
                                labelText: "카카오 ID",
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? "카카오 ID를 입력하세요"
                                  : null,
                            ),
                            const SizedBox(height: 10),

                            TextFormField(
                              controller: _pw,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: isEdit
                                    ? "카카오 PW (변경 시에만 입력)"
                                    : "카카오 PW",
                                isDense: true,
                              ),
                              validator: (v) {
                                if (!isEdit &&
                                    (v == null || v.trim().isEmpty)) {
                                  return "비밀번호를 입력하세요";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            TextFormField(
                              controller: _blog,
                              decoration: const InputDecoration(
                                labelText: "Blog Name",
                                hintText: "예) korea-beauty-editor-best",
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? "블로그 이름을 입력하세요"
                                  : null,
                            ),

                            const Spacer(),

                            Row(
                              children: [
                                if (isEdit)
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text("삭제"),
                                    onPressed: () async {
                                      final ok = await _confirmDelete(context);
                                      if (!ok) return;

                                      final deletingId = _selected!.id;
                                      await controller.deleteAccount(
                                        deletingId,
                                      );
                                      if (!mounted) return;

                                      final s2 = ref.read(
                                        tistoryPostingProvider,
                                      );
                                      _fill(
                                        s2.accounts.isNotEmpty
                                            ? s2.accounts.first
                                            : null,
                                      );
                                    },
                                  ),

                                const Spacer(),

                                OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("닫기"),
                                ),
                                const SizedBox(width: 10),

                                FilledButton.icon(
                                  icon: const Icon(Icons.save),
                                  label: Text(isEdit ? "수정 저장" : "등록"),
                                  onPressed: () async {
                                    if (!_formKey.currentState!.validate())
                                      return;

                                    if (isEdit) {
                                      await controller.updateAccount(
                                        id: _selected!.id,
                                        kakaoId: _kakaoId.text,
                                        password: _pw.text,
                                        blogName: _blog.text,
                                      );
                                      if (!mounted) return;

                                      final s2 = ref.read(
                                        tistoryPostingProvider,
                                      );
                                      final updated = s2.accounts.firstWhere(
                                        (a) => a.id == _selected!.id,
                                      );
                                      _fill(updated);
                                    } else {
                                      await controller.addAccount(
                                        kakaoId: _kakaoId.text,
                                        password: _pw.text,
                                        blogName: _blog.text,
                                      );
                                      if (!mounted) return;

                                      final s2 = ref.read(
                                        tistoryPostingProvider,
                                      );
                                      _fill(
                                        s2.accounts.firstWhere(
                                          (a) =>
                                              a.kakaoId == _kakaoId.text.trim(),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("계정을 삭제할까요?"),
            content: const Text("삭제하면 저장된 비밀번호도 함께 제거됩니다."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("취소"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("삭제"),
              ),
            ],
          ),
        )) ??
        false;
  }
}
