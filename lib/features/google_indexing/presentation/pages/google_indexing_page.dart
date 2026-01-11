import 'package:csias_desktop/core/extensions/build_context_extensions.dart';
import 'package:csias_desktop/core/theme/app_spacing.dart';
import 'package:csias_desktop/core/widgets/app_card.dart';
import 'package:csias_desktop/features/google_indexing/data/indexing_storage_service.dart';
import 'package:csias_desktop/features/google_indexing/domain/models/indexing_result.dart';
import 'package:csias_desktop/features/google_indexing/presentation/state/google_indexing_provider.dart';
import 'package:csias_desktop/features/google_indexing/presentation/state/google_indexing_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoogleIndexingPage extends ConsumerWidget {
  const GoogleIndexingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(googleIndexingProvider);
    final controller = ref.read(googleIndexingProvider.notifier);
    final scheme = context.colorScheme;

    return Column(
      children: [
        // 설정 카드
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, size: 20, color: scheme.primary),
                    const SizedBox(width: AppSpacing.s8),
                    Text('설정', style: context.textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      onPressed: state.isRunning ? null : controller.refresh,
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: '새로고침',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: AppSpacing.s16),

                // 서비스 계정 & OAuth 상태 (가로 배치)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 서비스 계정 JSON 파일 상태
                    Expanded(child: _buildServiceAccountStatus(context, state)),
                    const SizedBox(width: AppSpacing.s16),
                    // OAuth 인증 상태
                    Expanded(
                        child: _buildOAuthStatus(context, state, controller)),
                  ],
                ),

                const SizedBox(height: AppSpacing.s16),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: AppSpacing.s16),

                // 등록된 블로그 & 할당량 (가로 배치)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 등록된 블로그 목록
                    Expanded(child: _buildBlogList(context, state)),
                    const SizedBox(width: AppSpacing.s16),
                    // 일일 할당량 표시
                    Expanded(child: _buildQuotaStatus(context, state)),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.s8),

        // 실행 카드
        Expanded(
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Row(
                    children: [
                      Icon(Icons.send, size: 20, color: scheme.primary),
                      const SizedBox(width: AppSpacing.s8),
                      Text('색인 요청', style: context.textTheme.titleMedium),
                      const Spacer(),

                      // 현재 단계 표시
                      if (state.currentPhase != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s8,
                            vertical: AppSpacing.s4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            state.currentPhase!,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                      ],

                      // 진행 상태
                      if (state.isRunning || state.results.isNotEmpty) ...[
                        _buildProgressIndicator(context, state),
                        const SizedBox(width: AppSpacing.s16),
                      ],

                      // 취소 버튼
                      if (state.isRunning) ...[
                        OutlinedButton.icon(
                          onPressed: controller.cancel,
                          icon: const Icon(Icons.stop),
                          label: const Text('취소'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            side: BorderSide(color: scheme.error),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                      ],

                      // 전체 색인 요청 버튼
                      FilledButton.icon(
                        onPressed: state.canStartIndexing
                            ? controller.startIndexing
                            : null,
                        icon: state.isRunning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.playlist_add_check),
                        label: Text(state.isRunning ? '요청 중...' : '전체 색인 요청'),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.s12),
                  Divider(height: 1, color: scheme.outlineVariant),
                  const SizedBox(height: AppSpacing.s12),

                  // 상태/에러 메시지 영역
                  if (state.statusMessage != null ||
                      state.errorMessage != null) ...[
                    // 상태 메시지
                    if (state.statusMessage != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: scheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(
                                state.statusMessage!,
                                style: TextStyle(color: scheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (state.statusMessage != null &&
                        state.errorMessage != null)
                      const SizedBox(height: AppSpacing.s8),

                    // 에러 메시지
                    if (state.errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: scheme.error),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: scheme.error),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(
                                state.errorMessage!,
                                style:
                                    TextStyle(color: scheme.onErrorContainer),
                              ),
                            ),
                            IconButton(
                              onPressed: controller.clearError,
                              icon: const Icon(Icons.close),
                              iconSize: 18,
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: AppSpacing.s12),
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: AppSpacing.s12),
                  ],

                  // 결과 요약
                  if (state.results.isNotEmpty && !state.isRunning) ...[
                    _buildResultSummary(context, state),
                    const SizedBox(height: AppSpacing.s12),
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: AppSpacing.s12),
                  ],

                  // 결과 목록 헤더
                  if (state.results.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.list_alt, size: 18, color: scheme.primary),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          '결과 목록',
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${state.results.length}개',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                  ],

                  // 결과 목록
                  Expanded(
                    child: state.results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.playlist_add_check_outlined,
                                  size: 48,
                                  color: scheme.outline,
                                ),
                                const SizedBox(height: AppSpacing.s12),
                                Text(
                                  '"전체 색인 요청" 버튼을 클릭하면\n등록된 모든 블로그의 색인되지 않은 URL을 색인 요청합니다.',
                                  style: TextStyle(color: scheme.outline),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: scheme.outlineVariant,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildResultList(context, state),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.s8),
      ],
    );
  }

  Widget _buildServiceAccountStatus(BuildContext context, GoogleIndexingState state) {
    final scheme = context.colorScheme;
    final hasServiceAccount = state.hasServiceAccount;
    final path = IndexingStorageService.serviceAccountPath;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: hasServiceAccount
            ? Colors.green.withValues(alpha: 0.1)
            : scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasServiceAccount ? Colors.green : scheme.error,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasServiceAccount ? Icons.check_circle : Icons.error_outline,
                color: hasServiceAccount ? Colors.green : scheme.error,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                '서비스 계정 (Indexing API)',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                hasServiceAccount ? '설정됨' : '없음',
                style: context.textTheme.bodySmall?.copyWith(
                  color: hasServiceAccount ? Colors.green : scheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: Text(
                  path,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: path));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('경로가 클립보드에 복사되었습니다.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                tooltip: '경로 복사',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (!hasServiceAccount) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              '위 경로에 Google Cloud 서비스 계정 JSON 파일을 복사해주세요.',
              style: context.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOAuthStatus(
      BuildContext context, GoogleIndexingState state, dynamic controller) {
    final scheme = context.colorScheme;
    final authStatus = state.authStatus;
    final oauthPath = IndexingStorageService.oauthCredentialsPath;

    final isAuthenticated = authStatus == AuthStatus.authenticated;
    final isAuthenticating = authStatus == AuthStatus.authenticating;
    final needsCredentials = authStatus == AuthStatus.notConfigured;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isAuthenticated) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = '인증됨';
    } else if (isAuthenticating) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
      statusText = '인증 중...';
    } else if (needsCredentials) {
      statusColor = scheme.error;
      statusIcon = Icons.error_outline;
      statusText = '자격증명 없음';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = '인증 필요';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isAuthenticated
            ? Colors.green.withValues(alpha: 0.1)
            : needsCredentials
                ? scheme.errorContainer.withValues(alpha: 0.5)
                : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'OAuth 2.0 (URL Inspection)',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                statusText,
                style: context.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          if (needsCredentials) ...[
            Text(
              oauthPath,
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              '위 경로에 OAuth 자격증명 JSON 파일을 복사해주세요.',
              style: context.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ] else if (isAuthenticating) ...[
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  '브라우저에서 인증을 완료해주세요...',
                  style: context.textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => controller.cancelAuthentication(),
                  child: const Text('취소'),
                ),
              ],
            ),
          ] else if (isAuthenticated) ...[
            Row(
              children: [
                Text(
                  'Google 계정으로 인증됨',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => controller.logout(),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('로그아웃'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // notAuthenticated
            Row(
              children: [
                Expanded(
                  child: Text(
                    'URL Inspection API 사용을 위해 인증이 필요합니다.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => controller.startAuthentication(),
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('인증'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlogList(BuildContext context, GoogleIndexingState state) {
    final scheme = context.colorScheme;
    final blogNames = state.blogNames;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.web, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.s8),
              Text(
                '등록된 블로그',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${blogNames.length}개',
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (blogNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: blogNames.map((name) {
                return Chip(
                  label: Text(name, style: const TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Tistory 계정을 먼저 추가해주세요.',
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuotaStatus(BuildContext context, GoogleIndexingState state) {
    final scheme = context.colorScheme;
    final remainingIndexing = state.remainingIndexingQuota;
    final remainingInspection = state.remainingInspectionQuota;
    final usedIndexing =
        IndexingStorageService.defaultDailyLimit - remainingIndexing;
    final usedInspection =
        IndexingStorageService.defaultInspectionLimit - remainingInspection;
    final indexingPercent =
        usedIndexing / IndexingStorageService.defaultDailyLimit;
    final inspectionPercent =
        usedInspection / IndexingStorageService.defaultInspectionLimit;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.s8),
              Text(
                '오늘 API 사용량',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),

          // Indexing API 할당량
          Row(
            children: [
              Text(
                'Indexing API',
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '$usedIndexing / ${IndexingStorageService.defaultDailyLimit}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: remainingIndexing > 0 ? scheme.primary : scheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: indexingPercent,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                remainingIndexing > 50
                    ? Colors.green
                    : remainingIndexing > 0
                        ? Colors.orange
                        : scheme.error,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.s12),

          // URL Inspection API 할당량
          Row(
            children: [
              Text(
                'URL Inspection',
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '$usedInspection / ${IndexingStorageService.defaultInspectionLimit}',
                style: context.textTheme.bodySmall?.copyWith(
                  color:
                      remainingInspection > 0 ? scheme.primary : scheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: inspectionPercent,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                remainingInspection > 500
                    ? Colors.green
                    : remainingInspection > 0
                        ? Colors.orange
                        : scheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
      BuildContext context, GoogleIndexingState state) {
    final scheme = context.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:
                      state.progressPercent > 0 ? state.progressPercent : null,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.progressText,
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultSummary(BuildContext context, GoogleIndexingState state) {
    final scheme = context.colorScheme;
    final summary = state.summary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.s8),
              Text(
                '결과 요약',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(context, '전체', summary.total, scheme.primary),
              _buildSummaryItem(context, '성공', summary.success, Colors.green),
              _buildSummaryItem(
                  context, '이미 색인됨', summary.alreadyIndexed, Colors.blue),
              _buildSummaryItem(context, '실패', summary.failed, scheme.error),
              _buildSummaryItem(context, '건너뜀', summary.skipped, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: context.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildResultList(BuildContext context, GoogleIndexingState state) {
    final scheme = context.colorScheme;

    return ListView.builder(
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final result = state.results[index];
        final isSuccess = result.status == IndexingStatus.success;
        final isSkipped = result.status == IndexingStatus.skipped;
        final isAlreadyIndexed = result.status == IndexingStatus.alreadyIndexed;

        IconData icon;
        Color iconColor;
        if (isSuccess) {
          icon = Icons.check_circle;
          iconColor = Colors.green;
        } else if (isAlreadyIndexed) {
          icon = Icons.verified;
          iconColor = Colors.blue;
        } else if (isSkipped) {
          icon = Icons.skip_next;
          iconColor = Colors.orange;
        } else {
          icon = Icons.error;
          iconColor = scheme.error;
        }

        String? subtitle;
        Color? subtitleColor;
        if (isAlreadyIndexed) {
          subtitle = '이미 색인됨';
          subtitleColor = Colors.blue;
        } else if (result.errorMessage != null) {
          subtitle = result.errorMessage;
          subtitleColor = isSkipped ? Colors.orange : scheme.error;
        }

        return ListTile(
          dense: true,
          leading: Icon(icon, color: iconColor, size: 20),
          title: Text(
            result.url,
            style: context.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 11,
                  ),
                )
              : null,
        );
      },
    );
  }
}
