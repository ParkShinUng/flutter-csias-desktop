import 'package:csias_desktop/core/extensions/build_context_extensions.dart';
import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:flutter/material.dart';

typedef FileTagsSubmit = void Function(String filePath, List<String> tags);
typedef FileRemove = void Function(String filePath);

class FileTablePanel extends StatelessWidget {
  final List<UploadFileItem> files;
  final bool disabled;
  final FileTagsSubmit onSubmitTags;
  final FileRemove onRemoveFile;
  final Set<String> duplicateTagFilePaths;

  const FileTablePanel({
    super.key,
    required this.files,
    required this.disabled,
    required this.onSubmitTags,
    required this.onRemoveFile,
    this.duplicateTagFilePaths = const {},
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;

    return Column(
      children: [
        // ===== Header row =====
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s10,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppSpacing.r12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              const Expanded(
                flex: 5,
                child: Text("파일명", overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSpacing.s12),
              const Expanded(
                flex: 5,
                child: Text(
                  "태그 입력 (* 쉼표 구분, 최대 10개, 중복 불가)",
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              SizedBox(
                width: 44,
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.s10),

        // ===== Body list =====
        Expanded(
          child: ListView.separated(
            itemCount: files.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final file = files[index];
              final isDuplicate = duplicateTagFilePaths.contains(file.path);
              return _FileTableRow(
                key: ValueKey(file.path),
                file: file,
                disabled: disabled,
                isDuplicate: isDuplicate,
                onSubmitTags: onSubmitTags,
                onRemoveFile: onRemoveFile,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FileTableRow extends StatefulWidget {
  final UploadFileItem file;
  final bool disabled;
  final bool isDuplicate;
  final FileTagsSubmit onSubmitTags;
  final FileRemove onRemoveFile;

  const _FileTableRow({
    super.key,
    required this.file,
    required this.disabled,
    this.isDuplicate = false,
    required this.onSubmitTags,
    required this.onRemoveFile,
  });

  @override
  State<_FileTableRow> createState() => _FileTableRowState();
}

class _FileTableRowState extends State<_FileTableRow> {
  late final TextEditingController _c;
  late final FocusNode _f;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.file.tags.join(', '));
    _f = FocusNode();
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isDup = widget.isDuplicate;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.r12),
        border: Border.all(
          color: isDup ? Colors.red : Theme.of(context).dividerColor,
          width: isDup ? 2 : 1,
        ),
        color: isDup ? Colors.red.withValues(alpha: 0.08) : scheme.surface,
      ),
      child: Row(
        children: [
          // ===== Column 1: file name =====
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: scheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.s12),

          // ===== Column 2: tag input =====
          Expanded(
            flex: 5,
            child: TextField(
              controller: _c,
              focusNode: _f,
              enabled: !widget.disabled,
              decoration: const InputDecoration(
                hintText: "예) 뷰티, 맛집, 서울",
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (value) {
                final tags = value
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                widget.onSubmitTags(widget.file.path, tags);
              },
            ),
          ),

          const SizedBox(width: AppSpacing.s12),

          // ===== Column 3: delete button =====
          SizedBox(
            width: 44,
            child: IconButton(
              tooltip: "행 삭제",
              onPressed: widget.disabled
                  ? null
                  : () => widget.onRemoveFile(widget.file.path),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
