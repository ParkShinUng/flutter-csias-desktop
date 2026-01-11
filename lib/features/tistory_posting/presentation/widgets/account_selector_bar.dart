import 'package:csias_desktop/core/extensions/build_context_extensions.dart';
import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:csias_desktop/features/tistory_posting/data/unified_storage_service.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:flutter/material.dart';

class AccountSelectorBar extends StatelessWidget {
  final List<TistoryAccount> accounts;
  final String? selectedAccountId;
  final String? selectedBlogName;
  final bool disabled;
  final int remainingPosts;
  final Map<String, int> todayPostCounts;
  final void Function(String?) onSelectAccount;
  final void Function(String) onSelectBlog;
  final VoidCallback onManageAccounts;

  const AccountSelectorBar({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.selectedBlogName,
    required this.disabled,
    required this.remainingPosts,
    required this.todayPostCounts,
    required this.onSelectAccount,
    required this.onSelectBlog,
    required this.onManageAccounts,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final selectedAccount =
        accounts.where((a) => a.id == selectedAccountId).firstOrNull;

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
                            Tooltip(
                              message: '일일 포스팅 한도 (자정 00:00 리셋)',
                              child: Text(
                                '${selectedAccount.blogNames.length}개 블로그 · $remainingPosts/${UnifiedStorageService.maxDailyPosts}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color:
                            disabled ? scheme.outline : scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  itemBuilder: (context) => accounts.map((account) {
                    final isSelected = account.id == selectedAccountId;
                    final accountTodayPosts = todayPostCounts[account.id] ?? 0;
                    final accountRemaining =
                        UnifiedStorageService.maxDailyPosts - accountTodayPosts;
                    final blogCount = account.blogNames.length;
                    final blogText = blogCount == 1
                        ? account.blogNames.first
                        : '$blogCount개 블로그';
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
                                  blogText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tooltip(
                            message: '자정 00:00 리셋',
                            child: Text(
                              '$accountRemaining/${UnifiedStorageService.maxDailyPosts}',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
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

        // 블로그 선택 영역 (블로그가 2개 이상일 때만 표시)
        if (selectedAccount != null && selectedAccount.blogNames.length > 1) ...[
          const SizedBox(width: AppSpacing.s12),
          _buildBlogSelector(context, scheme, selectedAccount),
        ],

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

  Widget _buildBlogSelector(
    BuildContext context,
    ColorScheme scheme,
    TistoryAccount account,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: PopupMenuButton<String>(
        initialValue: selectedBlogName,
        onSelected: disabled ? null : onSelectBlog,
        enabled: !disabled,
        tooltip: '블로그 선택',
        offset: const Offset(0, 40),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 20,
              color: scheme.primary,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              selectedBlogName ?? '블로그 선택',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: disabled ? scheme.outline : scheme.onSurfaceVariant,
            ),
          ],
        ),
        itemBuilder: (context) => account.blogNames.map((blogName) {
          final isSelected = blogName == selectedBlogName;
          return PopupMenuItem<String>(
            value: blogName,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check : Icons.book_outlined,
                  size: 18,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  blogName,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
