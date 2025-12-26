import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:csias_desktop/features/tistory_posting/data/posting_history_service.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:flutter/material.dart';

class AccountSelectorBar extends StatelessWidget {
  final List<TistoryAccount> accounts;
  final String? selectedAccountId;
  final bool disabled;
  final int todayPosts;
  final int remainingPosts;
  final void Function(String?) onSelectAccount;
  final VoidCallback onManageAccounts;

  const AccountSelectorBar({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.disabled,
    required this.todayPosts,
    required this.remainingPosts,
    required this.onSelectAccount,
    required this.onManageAccounts,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedAccount = accounts
        .where((a) => a.id == selectedAccountId)
        .firstOrNull;

    return Row(
      children: [
        // 계정 선택 영역
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_circle,
                size: 28,
                color: accounts.isEmpty ? scheme.outline : scheme.primary,
              ),
              const SizedBox(width: AppSpacing.s12),
              if (accounts.isEmpty)
                Text(
                  '등록된 계정 없음',
                  style: TextStyle(color: scheme.outline, fontSize: 14),
                )
              else
                PopupMenuButton<String>(
                  initialValue: selectedAccountId,
                  onSelected: disabled ? null : onSelectAccount,
                  enabled: !disabled,
                  tooltip: '계정 선택',
                  offset: const Offset(0, 40),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedAccount?.kakaoId ?? '계정을 선택하세요',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (selectedAccount != null)
                            Text(
                              selectedAccount.blogName,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: disabled
                            ? scheme.outline
                            : scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  itemBuilder: (context) => accounts.map((account) {
                    final isSelected = account.id == selectedAccountId;
                    return PopupMenuItem<String>(
                      value: account.id,
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.account_circle_outlined,
                            size: 20,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.kakaoId,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              Text(
                                account.blogName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.s12),

        // 계정 관리 버튼
        OutlinedButton.icon(
          onPressed: disabled ? null : onManageAccounts,
          icon: const Icon(Icons.manage_accounts, size: 18),
          label: const Text('계정 관리'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        const SizedBox(width: AppSpacing.s16),

        // 오늘 포스팅 현황
        if (selectedAccountId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: remainingPosts > 5
                  ? scheme.primaryContainer.withValues(alpha: 0.5)
                  : remainingPosts > 0
                      ? scheme.tertiaryContainer.withValues(alpha: 0.5)
                      : scheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  remainingPosts > 5
                      ? Icons.check_circle_outline
                      : remainingPosts > 0
                          ? Icons.warning_amber_rounded
                          : Icons.block,
                  size: 16,
                  color: remainingPosts > 5
                      ? scheme.primary
                      : remainingPosts > 0
                          ? scheme.tertiary
                          : scheme.error,
                ),
                const SizedBox(width: 6),
                Text(
                  '오늘 $todayPosts/${PostingHistoryService.maxDailyPosts}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: remainingPosts > 5
                        ? scheme.onPrimaryContainer
                        : remainingPosts > 0
                            ? scheme.onTertiaryContainer
                            : scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(남은 $remainingPosts개)',
                  style: TextStyle(
                    fontSize: 12,
                    color: remainingPosts > 5
                        ? scheme.onPrimaryContainer.withValues(alpha: 0.7)
                        : remainingPosts > 0
                            ? scheme.onTertiaryContainer.withValues(alpha: 0.7)
                            : scheme.onErrorContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
