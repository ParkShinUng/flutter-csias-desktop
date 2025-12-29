import 'package:flutter/material.dart';

/// 비밀번호 입력 필드 위젯
///
/// 기본적으로 obscureText가 활성화되어 있으며,
/// 눈 아이콘을 통해 비밀번호 표시/숨기기를 토글할 수 있습니다.
class PasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const PasswordTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.errorText,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscurePassword = true;

  void _toggleVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscurePassword,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.labelText,
        isDense: true,
        errorText: widget.errorText,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: _toggleVisibility,
          tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
        ),
      ),
    );
  }
}
