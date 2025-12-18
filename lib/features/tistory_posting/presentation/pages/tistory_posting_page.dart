import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/drop_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:csias_desktop/core/widgets/app_card.dart';
import 'package:csias_desktop/core/widgets/app_button.dart';
import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_controller.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/widgets/tag_chip.dart';

class TistoryPostingPage extends ConsumerWidget {
  const TistoryPostingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tistoryPostingProvider);
    final controller = ref.read(tistoryPostingProvider.notifier);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /* ================= Left: Account ================= */
        SizedBox(
          width: 260,
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
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("파일 & 태그", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.s12),

                DropZone(onFilesDropped: controller.addFilesFromPaths),

                const SizedBox(height: AppSpacing.s12),

                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text("파일 선택"),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      allowMultiple: true,
                      type: FileType.custom,
                      allowedExtensions: ['html', 'htm'],
                    );
                    if (result == null) return;

                    controller.addFilesFromPaths(
                      result.files
                          .where((f) => f.path != null)
                          .map((f) => f.path!)
                          .toList(),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.s12),

                ...state.files.map(
                  (f) => ListTile(
                    dense: true,
                    leading: _statusIcon(f.status),
                    title: Text(f.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: f.status == UploadStatus.running
                          ? null
                          : () => controller.removeFile(f.path),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.s16),

        /* ================= Right: Run & Logs ================= */
        SizedBox(
          width: 360,
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
                      onPressed: state.isRunning ? controller.stop : null,
                      child: const Text("중지"),
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
