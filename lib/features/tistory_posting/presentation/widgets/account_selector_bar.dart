import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:csias_desktop/features/tistory_posting/data/posting_history_service.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:flutter/material.dart';

class AccountSelectorBar extends StatelessWidget {
  final List<TistoryAccount> accounts;
  final String? selectedAccountId;
  final bool disabled;
  final int remainingPosts;
  final Map<String, int> todayPostCounts;
  final void Function(String?) onSelectAccount;
  final VoidCallback onManageAccounts;

  const AccountSelectorBar({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.disabled,
    required this.remainingPosts,
    required this.todayPostCounts,
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
                              '${selectedAccount.blogName} · $remainingPosts / ${PostingHistoryService.maxDailyPosts}',
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
                    final accountTodayPosts = todayPostCounts[account.id] ?? 0;
                    final accountRemaining =
                        PostingHistoryService.maxDailyPosts - accountTodayPosts;
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
                          Expanded(
                            child: Column(
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
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$accountRemaining/${PostingHistoryService.maxDailyPosts}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
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
      ],
    );
  }
}
