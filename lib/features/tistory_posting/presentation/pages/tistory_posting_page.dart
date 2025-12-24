import 'package:csias_desktop/core/ui/app_message_dialog.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_provider.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_state.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/account_inline_input_bar.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/drop_zone.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/file_table_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:csias_desktop/core/widgets/app_card.dart';
import 'package:csias_desktop/core/theme/app_spacing.dart';

class TistoryPostingPage extends ConsumerWidget {
  const TistoryPostingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tistoryPostingProvider);
    final controller = ref.read(tistoryPostingProvider.notifier);

    // DropZone Mode flag
    final hasSelected =
        state.files.isNotEmpty && state.selectedFilePath != null;

    // Message Dialog
    ref.listen<TistoryPostingState>(tistoryPostingProvider, (prev, next) async {
      final msg = next.uiMessage;
      if (msg == null) return;

      // 중복 호출 방지: 먼저 clear 한 다음 다이얼로그
      ref.read(tistoryPostingProvider.notifier).clearUiMessage();

      if (!context.mounted) return;
      await showAppMessageDialog(context, msg);
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        // ✅ 3행 비율 (원하면 숫자만 조정)
        final row1 = (h * 0.1).clamp(120.0, 120.0);
        final row2 = (h - row1) - (AppSpacing.s16 * 2);

        return Column(
          children: [
            // ===================== ROW 1: Top Bar (Account + Actions) =====================
            SizedBox(
              height: row1,
              child: AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: 12,
                  ),
                  child: AccountInlineInputBar(
                    disabled: state.isRunning,
                    isRunning: state.isRunning,
                    kakaoId: state.draftKakaoId ?? "",
                    password: state.draftPassword ?? "",
                    blogName: state.draftBlogName ?? "",
                    onStart: controller.start,
                    onChangedId: controller.setDraftKakaoId,
                    onChangedPw: controller.setDraftPassword,
                    onChangedBlogName: controller.setDraftBlogName,
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
                                          child: FileTablePanel(
                                            files: state.files,
                                            disabled: state.isRunning,
                                            duplicateTagFilePaths: state.duplicateTagFilePaths,
                                            onSubmitTags: (filePath, tags) {
                                              // ✅ 컨트롤러에 "파일별 태그 추가" 메서드 연결
                                              // 아래 메서드명이 너 프로젝트에 없으면 Step 3에서 추가해줄게.
                                              controller.addTagsToFile(
                                                filePath,
                                                tags,
                                              );
                                            },
                                            onRemoveFile: (filePath) {
                                              controller.removeFile(filePath);
                                            },
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
          ],
        );
      },
    );
  }
}
