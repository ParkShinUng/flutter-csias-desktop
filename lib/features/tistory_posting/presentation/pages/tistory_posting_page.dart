import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/drop_zone.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/file_list_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:csias_desktop/core/widgets/app_card.dart';
import 'package:csias_desktop/core/widgets/app_button.dart';
import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_controller.dart';

class TistoryPostingPage extends ConsumerWidget {
  const TistoryPostingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tistoryPostingProvider);
    final controller = ref.read(tistoryPostingProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        final leftW = (w * 0.18).clamp(260.0, 360.0);
        final rightW = (w * 0.24).clamp(360.0, 520.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* ================= Left: Account ================= */
            SizedBox(
              width: leftW,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("계정", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.s12),

                    DropdownButton<String>(
                      isExpanded: true,
                      value: state.selectedAccountId,
                      hint: const Text("계정 선택"),
                      items: state.accounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: controller.selectAccountId,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.s16),

            /* ================= Middle: Files & Tags ================= */
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final hasSelected =
                      state.selectedFilePath != null && state.files.isNotEmpty;

                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "파일 & 태그",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.s12),

                        if (!hasSelected) ...[
                          // ✅ 선택된 파일 없으면 DropZone만 크게
                          DropZone(
                            onFilesSelected: controller.addFilesFromPaths,
                            fileCount: state.files.length,
                          ),
                        ] else ...[
                          // ✅ 선택된 파일 있으면 상단 액션 + 리스트
                          Row(
                            children: [
                              Text(
                                "선택된 파일 : ${state.files.length}개",
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const Spacer(),
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

                          // ✅ 파일 리스트
                          Expanded(
                            child: FileListPanel(
                              statusIconBuilder: (status) =>
                                  _statusIcon(status),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: AppSpacing.s16),

            /* ================= Right: Run & Logs ================= */
            SizedBox(
              width: rightW,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("실행", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.s12),

                    Row(
                      children: [
                        FilledButton(
                          style: AppButton.primary(context),
                          onPressed: state.isRunning ? null : controller.start,
                          child: const Text("포스팅 시작"),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: AppButton.ghost(context),
                          onPressed: state.isRunning
                              ? null
                              : controller.retryFailed,
                          child: const Text("실패만 재시도"),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    Text("로그", style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.s8),

                    Expanded(
                      child: ListView(
                        children: state.logs
                            .map(
                              (l) => Text(
                                l,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            )
                            .toList(),
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

  Icon _statusIcon(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return const Icon(Icons.schedule, size: 16);
      case UploadStatus.running:
        return const Icon(Icons.autorenew, size: 16);
      case UploadStatus.success:
        return const Icon(Icons.check_circle, size: 16, color: Colors.green);
      case UploadStatus.failed:
        return const Icon(Icons.error, size: 16, color: Colors.red);
    }
  }
}
