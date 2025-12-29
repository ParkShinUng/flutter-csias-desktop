import 'package:csias_desktop/core/extensions/build_context_extensions.dart';
import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

class DropZone extends StatefulWidget {
  final void Function(List<String>) onFilesSelected;
  final int fileCount;

  const DropZone({
    super.key,
    required this.onFilesSelected,
    required this.fileCount,
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _isDragging = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['html', 'htm'],
    );
    if (result == null) return;

    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();

    if (paths.isNotEmpty) {
      widget.onFilesSelected(paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;

    final borderColor = _isDragging
        ? scheme.primary
        : Theme.of(context).dividerColor;

    final backgroundColor = _isDragging
        ? scheme.primaryContainer.withValues(alpha: 0.18)
        : Colors.transparent;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) {
        setState(() => _isDragging = false);
        widget.onFilesSelected(detail.files.map((f) => f.path).toList());
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pickFiles,
          borderRadius: BorderRadius.circular(AppSpacing.r16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: SizedBox.expand(
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(AppSpacing.r16),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, size: 48, color: scheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        _isDragging
                            ? "여기에 놓으면 추가됩니다"
                            : "Drag & Drop 또는 클릭해서 파일 선택",
                        textAlign: TextAlign.center,
                        style: context.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ".html / .htm 파일만 허용",
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "선택됨: ${widget.fileCount}개",
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
