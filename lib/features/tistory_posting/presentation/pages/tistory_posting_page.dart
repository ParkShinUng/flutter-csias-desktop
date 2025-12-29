import 'package:csias_desktop/core/ui/app_message_dialog.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_provider.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_state.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/account_management_dialog.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/account_selector_bar.dart';
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

    final hasSelected =
        state.files.isNotEmpty && state.selectedFilePath != null;

    // Message Dialog
    ref.listen<TistoryPostingState>(tistoryPostingProvider, (prev, next) async {
      final msg = next.uiMessage;
      if (msg == null) return;

      ref.read(tistoryPostingProvider.notifier).clearUiMessage();

      if (!context.mounted) return;
      await showAppMessageDialog(context, msg);
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // ===================== ROW 1: Account Selector =====================
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: AccountSelectorBar(
                  accounts: state.accounts,
                  selectedAccountId: state.selectedAccountId,
                  disabled: state.isRunning,
                  remainingPosts: state.selectedAccountRemainingPosts,
                  todayPostCounts: state.todayPostCounts,
                  onSelectAccount: controller.selectAccount,
                  onManageAccounts: () => _showAccountManagement(context),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s8),

            // ===================== ROW 2: 파일 선택 & 태그 입력 =====================
            Expanded(
              child: AppCard(
                child: LayoutBuilder(
                  builder: (context, c) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "파일 & 태그",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              // 진행 상태 표시
                              if (state.isRunning) ...[
                                _buildProgressIndicator(context, state),
                                const SizedBox(width: AppSpacing.s16),
                              ],
                              if (state.files.isNotEmpty && !state.isRunning)
                                TextButton.icon(
                                  onPressed: controller.clearFiles,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text("전체 초기화"),
                                ),
                              const SizedBox(width: AppSpacing.s8),
                              // 취소 버튼 (실행 중일 때만 표시)
                              if (state.isRunning) ...[
                                SizedBox(
                                  height: 40,
                                  child: OutlinedButton.icon(
                                    onPressed: controller.cancel,
                                    icon: const Icon(Icons.stop),
                                    label: const Text("취소"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Theme.of(context).colorScheme.error,
                                      side: BorderSide(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                              ],
                              SizedBox(
                                height: 40,
                                child: FilledButton.icon(
                                  onPressed: (state.isRunning ||
                                          state.accounts.isEmpty ||
                                          state.selectedAccountId == null ||
                                          state.files.isEmpty)
                                      ? null
                                      : controller.start,
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
                          const SizedBox(height: AppSpacing.s12),

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

                                        Expanded(
                                          child: FileTablePanel(
                                            files: state.files,
                                            disabled: state.isRunning,
                                            duplicateTagFilePaths:
                                                state.duplicateTagFilePaths,
                                            onSubmitTags: (filePath, tags) {
                                              controller.addTagsToFile(
                                                  filePath, tags);
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

  void _showAccountManagement(BuildContext context) {
    showAccountManagementDialog(context);
  }

  Widget _buildProgressIndicator(BuildContext context, TistoryPostingState state) {
    final theme = Theme.of(context);
    final progressPercent = state.progressPercent;
    final progressText = state.progressText;
    final currentFileName = state.currentFileName;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 진행률 바
        SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressPercent > 0 ? progressPercent : null,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                progressText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // 현재 파일명 표시
        if (currentFileName != null) ...[
          const SizedBox(width: AppSpacing.s12),
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              currentFileName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
