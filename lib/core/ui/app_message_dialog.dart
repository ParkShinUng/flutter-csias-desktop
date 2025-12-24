import 'package:csias_desktop/core/ui/ui_message.dart';
import 'package:flutter/material.dart';

Future<void> showAppMessageDialog(BuildContext context, UiMessage msg) {
  IconData icon;
  switch (msg.type) {
    case UiMessageType.info:
      icon = Icons.info_outline;
      break;
    case UiMessageType.warning:
      icon = Icons.warning_amber_rounded;
      break;
    case UiMessageType.error:
      icon = Icons.error_outline;
      break;
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(msg.title)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.message),
            if (msg.detail != null && msg.detail!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              SelectableText(msg.detail!, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("확인"),
        ),
      ],
    ),
  );
}
