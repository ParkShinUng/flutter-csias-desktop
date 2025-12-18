import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

class DropZone extends StatelessWidget {
  final void Function(List<String>) onFilesDropped;

  const DropZone({super.key, required this.onFilesDropped});

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) {
        final paths = detail.files.map((f) => f.path).toList();
        onFilesDropped(paths);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.r16),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.upload_file, size: 36),
            SizedBox(height: 8),
            Text("HTML 파일을 여기에 Drag & Drop"),
            SizedBox(height: 4),
            Text(".html / .htm만 허용", style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
