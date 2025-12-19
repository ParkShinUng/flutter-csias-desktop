import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/account_manager_dialog.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/drop_zone.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/file_list_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:csias_desktop/core/widgets/app_card.dart';
import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_controller.dart';

class TistoryPostingPage extends ConsumerWidget {
  const TistoryPostingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tistoryPostingProvider);
    final controller = ref.read(tistoryPostingProvider.notifier);

    // ✅ 파일이 없거나 선택이 없으면 DropZone 모드
    final hasSelected =
        state.files.isNotEmpty && state.selectedFilePath != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        // ✅ 3행 비율 (원하면 숫자만 조정)
        final row1 = (h * 0.12).clamp(96.0, 120.0);
        final row3 = (h * 0.28).clamp(220.0, 360.0);
        final row2 = h - row1 - row3 - (AppSpacing.s16 * 2); // 카드 사이 간격 2개

        return Column(
          children: [
            // ===================== ROW 1: Top Bar (Account + Actions) =====================
            SizedBox(
              height: 100,
              child: AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ===== Left: Account selector (compact) =====
                      SizedBox(
                        width: 300,
                        child: DropdownButtonFormField<String>(
                          // 🔽 드롭다운 목록 (기존 그대로)
                          items: state.accounts
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          a.kakaoId,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),

                          // ✅ 선택된 값 표시를 "중앙 정렬"로 커스터마이즈
                          selectedItemBuilder: (context) {
                            return state.accounts.map((a) {
                              return Center(
                                child: Text(
                                  a.kakaoId,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              );
                            }).toList();
                          },

                          onChanged: state.isRunning
                              ? null
                              : controller.selectAccountId,

                          decoration: const InputDecoration(
                            labelText: "계정",
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: AppSpacing.s8),

                      OutlinedButton.icon(
                        icon: const Icon(Icons.manage_accounts_outlined),
                        label: const Text("계정 관리"),
                        onPressed: state.isRunning
                            ? null
                            : () => showDialog(
                                context: context,
                                builder: (_) => const AccountManagerDialog(),
                              ),
                      ),

                      const Spacer(),

                      // ===== Right: Primary action(s) =====
                      SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: state.isRunning ? null : controller.start,
                          icon: state.isRunning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_arrow),
                          label: Text(state.isRunning ? "실행 중" : "포스팅 시작"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s8),

            // ===================== ROW 2: 파일 선택 & 태그 입력 =====================
            SizedBox(
              height: row2,
              child: AppCard(
                child: LayoutBuilder(
                  builder: (context, c) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 헤더 + 우측 액션
                          Row(
                            children: [
                              Text(
                                "파일 & 태그",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              if (state.files.isNotEmpty)
                                TextButton.icon(
                                  onPressed: state.isRunning
                                      ? null
                                      : controller.clearFiles,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text("전체 초기화"),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12),

                          // 본문: DropZone 또는 리스트
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: !hasSelected
                                  ? DropZone(
                                      key: const ValueKey("drop"),
                                      onFilesSelected:
                                          controller.addFilesFromPaths,
                                      fileCount: state.files.length,
                                    )
                                  : Column(
                                      key: const ValueKey("list"),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 선택된 파일이 있는 상태에서 상단 가이드/상태
                                        Row(
                                          children: [
                                            Text(
                                              "총 ${state.files.length}개",
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                            const SizedBox(width: 10),
                                            const Spacer(),
                                            // 전역 태그(원하면 제거 가능)
                                            SizedBox(
                                              width: 360,
                                              child: TextField(
                                                enabled: !state.isRunning,
                                                decoration: const InputDecoration(
                                                  hintText:
                                                      "전역 태그 입력 후 Enter (띄어쓰기로 여러 개)",
                                                  isDense: true,
                                                ),
                                                onSubmitted: (v) {
                                                  // 띄어쓰기 기반 다중 입력
                                                  final parts = v
                                                      .trim()
                                                      .split(RegExp(r'\s+'))
                                                      .where(
                                                        (e) => e.isNotEmpty,
                                                      );
                                                  for (final t in parts) {
                                                    controller.addTag(t);
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.s12),

                                        // 전역 태그 chip
                                        if (state.tags.isNotEmpty) ...[
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: state.tags
                                                .map(
                                                  (t) => InputChip(
                                                    label: Text(t),
                                                    onDeleted: state.isRunning
                                                        ? null
                                                        : () => controller
                                                              .removeTag(t),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                          const SizedBox(
                                            height: AppSpacing.s12,
                                          ),
                                        ],

                                        // 파일 리스트(파일별 태그 + 선택 하이라이트 + ↑↓ 이동)
                                        Expanded(
                                          child: FileListPanel(
                                            statusIconBuilder: (status) =>
                                                _statusIcon(context, status),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s8),

            // ===================== ROW 3: 로그 =====================
            SizedBox(
              height: row3,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "로그",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          "${state.logs.length} lines",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSpacing.r12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          itemCount: state.logs.length,
                          itemBuilder: (context, i) {
                            final line = state.logs[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                line,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusIcon(BuildContext context, UploadStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case UploadStatus.pending:
        return Icon(Icons.schedule, size: 18, color: scheme.outline);
      case UploadStatus.running:
        return SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        );
      case UploadStatus.success:
        return Icon(Icons.check_circle, size: 18, color: scheme.tertiary);
      case UploadStatus.failed:
        return Icon(Icons.error, size: 18, color: scheme.error);
    }
  }
}
