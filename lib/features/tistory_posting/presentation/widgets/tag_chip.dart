import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';

class TagChip extends StatelessWidget {
  final String text;
  final VoidCallback onRemove;

  const TagChip({super.key, required this.text, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.r12),
      ),
    );
  }
}
