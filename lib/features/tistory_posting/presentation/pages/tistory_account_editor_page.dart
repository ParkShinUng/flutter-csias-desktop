import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:flutter/material.dart';

class TistoryAccountEditorResult {
  final TistoryAccount account;
  final String? password; // credentials일 때만
  TistoryAccountEditorResult(this.account, this.password);
}

class TistoryAccountEditorPage extends StatefulWidget {
  final TistoryAccount? initial;
  final String newId;

  const TistoryAccountEditorPage({
    super.key,
    required this.initial,
    required this.newId,
  });

  @override
  State<TistoryAccountEditorPage> createState() =>
      _TistoryAccountEditorPageState();
}

class _TistoryAccountEditorPageState extends State<TistoryAccountEditorPage> {
  late TistoryAuthType authType;
  final displayName = TextEditingController();

  // credentials
  final loginId = TextEditingController();
  final password = TextEditingController();
  final blogName = TextEditingController();

  // cookies
  final tsSession = TextEditingController();
  final tAno = TextEditingController();

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    authType = a?.authType ?? TistoryAuthType.credentials;

    displayName.text = a?.displayName ?? "";

    loginId.text = a?.loginId ?? "";
    blogName.text = a?.blogName ?? "";

    tsSession.text = a?.tsSession ?? "";
    tAno.text = a?.tAno ?? "";
  }

  void _save() {
    final name = displayName.text.trim();
    if (name.isEmpty) {
      _alert("표시 이름은 필수입니다.");
      return;
    }

    final id = widget.initial?.id ?? widget.newId;

    if (authType == TistoryAuthType.credentials) {
      if (loginId.text.trim().isEmpty || password.text.isEmpty) {
        _alert("ID/PW는 필수입니다.");
        return;
      }

      final account = TistoryAccount(
        id: id,
        displayName: name,
        authType: authType,
        loginId: loginId.text.trim(),
        blogName: blogName.text.trim().isEmpty ? null : blogName.text.trim(),
        passwordKey: widget.initial?.passwordKey, // 유지
      );

      Navigator.pop(
        context,
        TistoryAccountEditorResult(account, password.text),
      );
      return;
    }

    // cookies
    if (tsSession.text.trim().isEmpty || tAno.text.trim().isEmpty) {
      _alert("TSSESSION, _T_ANO는 필수입니다.");
      return;
    }

    final account = TistoryAccount(
      id: id,
      displayName: name,
      authType: authType,
      tsSession: tsSession.text.trim(),
      tAno: tAno.text.trim(),
    );

    Navigator.pop(context, TistoryAccountEditorResult(account, null));
  }

  void _alert(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("확인"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("계정 편집")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: displayName,
              decoration: const InputDecoration(labelText: "표시 이름"),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<TistoryAuthType>(
              value: authType,
              items: const [
                DropdownMenuItem(
                  value: TistoryAuthType.credentials,
                  child: Text("ID / PW 방식"),
                ),
                DropdownMenuItem(
                  value: TistoryAuthType.cookies,
                  child: Text("Cookie 방식"),
                ),
              ],
              onChanged: (v) =>
                  setState(() => authType = v ?? TistoryAuthType.credentials),
              decoration: const InputDecoration(labelText: "인증 방식"),
            ),

            const SizedBox(height: 16),

            if (authType == TistoryAuthType.credentials) ...[
              TextField(
                controller: loginId,
                decoration: const InputDecoration(labelText: "ID"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: "PW"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: blogName,
                decoration: const InputDecoration(labelText: "Blog Name (옵션)"),
              ),
            ] else ...[
              TextField(
                controller: tsSession,
                decoration: const InputDecoration(labelText: "TSSESSION"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tAno,
                decoration: const InputDecoration(labelText: "_T_ANO"),
              ),
            ],

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소"),
                ),
                const SizedBox(width: 10),
                FilledButton(onPressed: _save, child: const Text("저장")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
