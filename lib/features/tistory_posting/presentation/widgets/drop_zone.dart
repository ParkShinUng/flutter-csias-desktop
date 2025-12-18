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

    if (paths.isNotEmpty) widget.onFilesSelected(paths);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _isDragging
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).dividerColor;

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
          borderRadius: BorderRadius.circular(AppSpacing.r16),
          onTap: _pickFiles,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 150,
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.r16),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.upload_file, size: 38),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isDragging
                            ? "여기에 놓으면 추가됩니다"
                            : "Drag & Drop 또는 클릭해서 파일 선택",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ".html / .htm만 허용",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "선택됨: ${widget.fileCount}개",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
