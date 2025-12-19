import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:flutter/material.dart';

class FileRowTagEditor extends StatefulWidget {
  final UploadFileItem file;
  final bool disabled;

  final bool isSelected; // ✅ 선택 하이라이트

  final void Function(String tag) onAddTag;
  final void Function(String tag) onRemoveTag;
  final VoidCallback onRemoveFile;
  final VoidCallback onSelect; // ✅ row 클릭 시 선택

  final Widget leadingStatusIcon;

  const FileRowTagEditor({
    super.key,
    required this.file,
    required this.disabled,
    required this.isSelected,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onRemoveFile,
    required this.onSelect,
    required this.leadingStatusIcon,
  });

  @override
  FileRowTagEditorState createState() => FileRowTagEditorState();
}

/// ✅ public State: 부모가 GlobalKey로 접근 가능
class FileRowTagEditorState extends State<FileRowTagEditor> {
  late final TextEditingController _c;
  late final FocusNode _f;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController();
    _f = FocusNode();
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  /// ✅ 부모에서 호출해서 입력창 포커스
  void requestInputFocus() {
    if (widget.disabled) return;
    FocusScope.of(context).requestFocus(_f);
  }

  void _commit(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;

    // ✅ 띄어쓰기 기반 태그 분리
    final parts = text
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (final t in parts) {
      widget.onAddTag(t);
    }

    _c.clear();
    requestInputFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.file.tags;

    final highlight = widget.isSelected
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
        : Colors.transparent;

    final border = widget.isSelected
        ? Border.all(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.35),
            width: 1,
          )
        : Border.all(color: Colors.transparent);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onSelect();
          requestInputFocus(); // ✅ 클릭하면 선택 + 포커스
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: highlight,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.leadingStatusIcon,
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags
                            .map(
                              (t) => InputChip(
                                label: Text(t),
                                onDeleted: widget.disabled
                                    ? null
                                    : () => widget.onRemoveTag(t),
                              ),
                            )
                            .toList(),
                      ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: _c,
                      focusNode: _f,
                      enabled: !widget.disabled,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: "태그 입력 후 Enter (띄어쓰기 구분으로 여러 개 가능)",
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: "추가",
                          onPressed: widget.disabled
                              ? null
                              : () => _commit(_c.text),
                          icon: const Icon(Icons.add),
                        ),
                      ),
                      onSubmitted: _commit,
                      onTap: () {
                        widget.onSelect();
                        requestInputFocus();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              IconButton(
                tooltip: "파일 제거",
                icon: const Icon(Icons.close),
                onPressed: widget.disabled ? null : widget.onRemoveFile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
