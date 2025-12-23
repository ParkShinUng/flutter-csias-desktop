import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccountInlineInputBar extends StatefulWidget {
  final bool disabled;
  final bool isRunning;

  final String kakaoId;
  final String password;
  final String blogName;

  final void Function(String) onChangedId;
  final void Function(String) onChangedPw;
  final void Function(String) onChangedBlogName;

  final VoidCallback onStart;

  const AccountInlineInputBar({
    super.key,
    required this.disabled,
    required this.isRunning,
    required this.kakaoId,
    required this.password,
    required this.blogName,
    required this.onStart,
    required this.onChangedId,
    required this.onChangedPw,
    required this.onChangedBlogName,
  });

  @override
  State<AccountInlineInputBar> createState() => _AccountInlineInputBarState();
}

class _AccountInlineInputBarState extends State<AccountInlineInputBar> {
  late final TextEditingController _idC;
  late final TextEditingController _pwC;
  late final TextEditingController _blogC;

  late final FocusNode _idF;
  late final FocusNode _pwF;
  late final FocusNode _blogF;

  bool get _valid =>
      _idC.text.trim().isNotEmpty &&
      _pwC.text.trim().isNotEmpty &&
      _blogC.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    _idC = TextEditingController(text: widget.kakaoId);
    _pwC = TextEditingController();
    _blogC = TextEditingController(text: widget.blogName);

    _idF = FocusNode();
    _pwF = FocusNode();
    _blogF = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onChangedId(_idC.text);
      widget.onChangedBlogName(_blogC.text);
    });
  }

  @override
  void dispose() {
    _idC.dispose();
    _pwC.dispose();
    _blogC.dispose();
    _idF.dispose();
    _pwF.dispose();
    _blogF.dispose();
    super.dispose();
  }

  void _tryStart() {
    if (widget.disabled) return;
    if (!_valid) return;
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cs) {
        final isNarrow = cs.maxWidth < 900;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isNarrow ? 220 : 220,
                    child: TextField(
                      controller: _idC,
                      focusNode: _idF,
                      enabled: !widget.disabled,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "ID(Kakao)",
                        isDense: true,
                      ),
                      onChanged: widget.onChangedId,
                      onSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_pwF),
                    ),
                  ),

                  SizedBox(
                    width: isNarrow ? 220 : 220,
                    child: TextField(
                      controller: _pwC,
                      focusNode: _pwF,
                      enabled: !widget.disabled,

                      // ✅ 한글 입력 차단 (영문/숫자/특수문자만 허용)
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(
                          RegExp(r'[ㄱ-ㅎㅏ-ㅣ가-힣]'),
                        ),
                      ],

                      decoration: InputDecoration(
                        labelText: "PW(Kakao)",
                        isDense: true,
                      ),
                      onChanged: widget.onChangedPw,
                      onSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_blogF),
                    ),
                  ),

                  SizedBox(
                    width: isNarrow ? 260 : 260,
                    child: TextField(
                      controller: _blogC,
                      focusNode: _blogF,
                      enabled: !widget.disabled,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: "Blog Name",
                        hintText: "예) korea-beauty-editor-best",
                        isDense: true,
                      ),
                      onChanged: widget.onChangedBlogName,
                      onSubmitted: (_) => _tryStart(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.s12),

            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: (widget.disabled || !_valid) ? null : _tryStart,
                icon: widget.isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(widget.isRunning ? "실행 중" : "포스팅 시작"),
              ),
            ),
          ],
        );
      },
    );
  }
}
