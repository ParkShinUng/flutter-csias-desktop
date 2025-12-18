import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_row_tag_editor.dart';

class FileListPanel extends ConsumerStatefulWidget {
  final Widget Function(UploadStatus status) statusIconBuilder;

  const FileListPanel({super.key, required this.statusIconBuilder});

  @override
  ConsumerState<FileListPanel> createState() => _FileListPanelState();
}

class _FileListPanelState extends ConsumerState<FileListPanel> {
  final _listFocus = FocusNode();
  final _scroll = ScrollController();

  // filePath -> row key
  final Map<String, GlobalKey<FileRowTagEditorState>> _rowKeys = {};

  @override
  void dispose() {
    _listFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ensureKeys(List<UploadFileItem> files) {
    // 신규 파일 키 생성
    for (final f in files) {
      _rowKeys.putIfAbsent(f.path, () => GlobalKey<FileRowTagEditorState>());
    }
    // 제거된 파일 키 정리
    final existing = files.map((f) => f.path).toSet();
    _rowKeys.removeWhere((k, _) => !existing.contains(k));
  }

  void _focusSelected(List<UploadFileItem> files, String? selectedPath) {
    if (selectedPath == null) return;

    final key = _rowKeys[selectedPath];
    final ctx = key?.currentContext;
    if (ctx == null) return;

    // ✅ 1) 스크롤 정확도 100% 보장
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.15, // 위쪽 여백 조금
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );

    key?.currentState?.requestInputFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tistoryPostingProvider);
    final controller = ref.read(tistoryPostingProvider.notifier);

    final files = state.files;
    _ensureKeys(files);

    // 단축키 처리
    return Focus(
      focusNode: _listFocus,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          controller.selectNext();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final s = ref.read(tistoryPostingProvider);
            _focusSelected(s.files, s.selectedFilePath);
          });
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          controller.selectPrev();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final s = ref.read(tistoryPostingProvider);
            _focusSelected(s.files, s.selectedFilePath);
          });
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: ListView.builder(
        controller: _scroll,
        itemCount: files.length,
        itemBuilder: (context, index) {
          final f = files[index];
          final disabled = state.isRunning || f.status == UploadStatus.running;
          final isSelected = state.selectedFilePath == f.path;

          return FileRowTagEditor(
            key: _rowKeys[f.path],
            file: f,
            disabled: disabled,
            isSelected: isSelected,
            leadingStatusIcon: widget.statusIconBuilder(f.status),
            onSelect: () {
              controller.selectFile(f.path);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final s = ref.read(tistoryPostingProvider);
                _focusSelected(s.files, s.selectedFilePath);
              });
            },
            onAddTag: (tag) => controller.addFileTag(f.path, tag),
            onRemoveTag: (tag) => controller.removeFileTag(f.path, tag),
            onRemoveFile: () => controller.removeFile(f.path),
          );
        },
      ),
    );
  }
}
