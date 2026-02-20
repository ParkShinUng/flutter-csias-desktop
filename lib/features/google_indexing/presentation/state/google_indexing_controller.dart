import 'package:csias_desktop/features/google_indexing/data/google_indexing_service.dart';
import 'package:csias_desktop/features/google_indexing/data/google_oauth_service.dart';
import 'package:csias_desktop/features/google_indexing/data/indexing_storage_service.dart';
import 'package:csias_desktop/features/google_indexing/data/sitemap_parser.dart';
import 'package:csias_desktop/features/google_indexing/data/url_inspection_service.dart';
import 'package:csias_desktop/features/google_indexing/domain/models/indexing_result.dart';
import 'package:csias_desktop/features/google_indexing/presentation/state/google_indexing_state.dart';
import 'package:csias_desktop/features/tistory_posting/data/unified_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoogleIndexingController extends Notifier<GoogleIndexingState> {
  final _indexingService = GoogleIndexingService();
  GoogleOAuthService? _oauthService;
  bool _isCancelled = false;

  @override
  GoogleIndexingState build() {
    ref.onDispose(() {
      _indexingService.dispose();
    });
    _initialize();
    return GoogleIndexingState.initial();
  }

  /// 초기화
  Future<void> _initialize() async {
    await refresh();
  }

  /// 상태 새로고침
  Future<void> refresh() async {
    final hasServiceAccount = await IndexingStorageService.hasServiceAccount();
    final remainingIndexingQuota =
        await IndexingStorageService.getRemainingDailyQuota();
    final remainingInspectionQuota =
        await IndexingStorageService.getRemainingInspectionQuota();
    final blogNames = await _loadAllBlogNames();

    // OAuth 상태 확인
    final authStatus = await _checkAuthStatus();

    state = state.copyWith(
      hasServiceAccount: hasServiceAccount,
      authStatus: authStatus,
      remainingIndexingQuota: remainingIndexingQuota,
      remainingInspectionQuota: remainingInspectionQuota,
      blogNames: blogNames,
    );
  }

  /// OAuth 인증 상태 확인
  Future<AuthStatus> _checkAuthStatus() async {
    final hasCredentials = await IndexingStorageService.hasOAuthCredentials();
    if (!hasCredentials) {
      return AuthStatus.notConfigured;
    }

    final tokens = await IndexingStorageService.loadOAuthTokens();
    if (tokens == null) {
      return AuthStatus.notAuthenticated;
    }

    // 토큰이 만료되었으면 갱신 시도
    if (tokens.isExpired) {
      final credentials = await IndexingStorageService.loadOAuthCredentials();
      if (credentials == null) {
        return AuthStatus.notAuthenticated;
      }

      _oauthService = GoogleOAuthService(
        clientId: credentials.clientId,
        clientSecret: credentials.clientSecret,
      );

      final result = await _oauthService!.refreshAccessToken(
        tokens.refreshToken,
      );
      if (result.success) {
        await IndexingStorageService.saveOAuthTokens(
          OAuthTokens(
            accessToken: result.accessToken!,
            refreshToken: result.refreshToken!,
            expiresAt: result.expiresAt!,
          ),
        );
        return AuthStatus.authenticated;
      } else {
        return AuthStatus.notAuthenticated;
      }
    }

    return AuthStatus.authenticated;
  }

  /// 모든 블로그 이름 로드
  Future<List<String>> _loadAllBlogNames() async {
    try {
      final accounts = await UnifiedStorageService.loadAccounts();
      final blogNames = <String>[];
      for (final account in accounts) {
        blogNames.addAll(account.blogNames);
      }
      return blogNames.toSet().toList(); // 중복 제거
    } catch (e) {
      return [];
    }
  }

  /// Sitemap URL 생성
  String _getSitemapUrl(String blogName) {
    return 'https://$blogName.tistory.com/sitemap.xml';
  }

  /// OAuth 인증 시작
  Future<void> startAuthentication() async {
    final credentials = await IndexingStorageService.loadOAuthCredentials();
    if (credentials == null) {
      state = state.copyWith(errorMessage: 'OAuth 자격증명 파일이 없습니다.');
      return;
    }

    state = state.copyWith(
      authStatus: AuthStatus.authenticating,
      statusMessage: '브라우저에서 Google 계정으로 로그인해주세요...',
    );

    _oauthService = GoogleOAuthService(
      clientId: credentials.clientId,
      clientSecret: credentials.clientSecret,
    );

    final result = await _oauthService!.authenticate();

    if (result.success) {
      await IndexingStorageService.saveOAuthTokens(
        OAuthTokens(
          accessToken: result.accessToken!,
          refreshToken: result.refreshToken!,
          expiresAt: result.expiresAt!,
        ),
      );

      state = state.copyWith(
        authStatus: AuthStatus.authenticated,
        statusMessage: '인증 완료',
        clearError: true,
      );
    } else {
      state = state.copyWith(
        authStatus: AuthStatus.notAuthenticated,
        errorMessage: result.error ?? '인증 실패',
        clearStatus: true,
      );
    }
  }

  /// OAuth 인증 취소
  Future<void> cancelAuthentication() async {
    await _oauthService?.cancelAuthentication();
    state = state.copyWith(
      authStatus: AuthStatus.notAuthenticated,
      clearStatus: true,
    );
  }

  /// 로그아웃
  Future<void> logout() async {
    await IndexingStorageService.deleteOAuthTokens();
    state = state.copyWith(
      authStatus: AuthStatus.notAuthenticated,
      statusMessage: '로그아웃 완료',
    );
  }

  /// 전체 색인 요청 시작
  Future<void> startIndexing() async {
    if (state.isRunning) return;

    // 상태 새로고침
    await refresh();

    if (!state.hasServiceAccount) {
      state = state.copyWith(errorMessage: '서비스 계정 JSON 파일이 없습니다.');
      return;
    }

    if (state.blogNames.isEmpty) {
      state = state.copyWith(errorMessage: '등록된 블로그가 없습니다.');
      return;
    }

    _isCancelled = false;
    state = state.copyWith(
      isRunning: true,
      allUrls: [],
      results: [],
      currentIndex: 0,
      totalCount: 0,
      clearError: true,
      currentPhase: '준비',
      statusMessage: '인증 확인 중...',
    );

    try {
      // 1. Indexing API 인증
      await _indexingService.authenticate(
        IndexingStorageService.serviceAccountPath,
      );

      // 2. OAuth 인증 확인 및 필요시 자동 인증
      var tokens = await IndexingStorageService.loadOAuthTokens();

      // 토큰이 없거나 만료된 경우 인증 진행
      if (tokens == null || tokens.isExpired) {
        // OAuth 자격증명 확인
        final credentials = await IndexingStorageService.loadOAuthCredentials();
        if (credentials == null) {
          state = state.copyWith(
            isRunning: false,
            errorMessage: 'OAuth 자격증명 파일이 없습니다. 먼저 자격증명을 설정해주세요.',
            clearStatus: true,
            clearPhase: true,
          );
          return;
        }

        // 토큰이 있지만 만료된 경우 갱신 시도
        if (tokens != null && tokens.isExpired) {
          state = state.copyWith(statusMessage: '토큰 갱신 중...');

          _oauthService = GoogleOAuthService(
            clientId: credentials.clientId,
            clientSecret: credentials.clientSecret,
          );

          final refreshResult = await _oauthService!.refreshAccessToken(
            tokens.refreshToken,
          );

          if (refreshResult.success) {
            tokens = OAuthTokens(
              accessToken: refreshResult.accessToken!,
              refreshToken: refreshResult.refreshToken!,
              expiresAt: refreshResult.expiresAt!,
            );
            await IndexingStorageService.saveOAuthTokens(tokens);
          } else {
            // 갱신 실패 시 새로 인증 필요
            tokens = null;
          }
        }

        // 토큰이 없으면 새로 인증 진행
        if (tokens == null) {
          state = state.copyWith(
            authStatus: AuthStatus.authenticating,
            statusMessage: '브라우저에서 Google 계정으로 로그인해주세요...',
            currentPhase: 'OAuth 인증',
          );

          _oauthService = GoogleOAuthService(
            clientId: credentials.clientId,
            clientSecret: credentials.clientSecret,
          );

          final authResult = await _oauthService!.authenticate();

          if (_isCancelled) {
            state = state.copyWith(
              isRunning: false,
              authStatus: AuthStatus.notAuthenticated,
              clearStatus: true,
              clearPhase: true,
            );
            return;
          }

          if (!authResult.success) {
            state = state.copyWith(
              isRunning: false,
              authStatus: AuthStatus.notAuthenticated,
              errorMessage: authResult.error ?? '인증에 실패했습니다.',
              clearStatus: true,
              clearPhase: true,
            );
            return;
          }

          // 인증 성공 - 토큰 저장
          tokens = OAuthTokens(
            accessToken: authResult.accessToken!,
            refreshToken: authResult.refreshToken!,
            expiresAt: authResult.expiresAt!,
          );
          await IndexingStorageService.saveOAuthTokens(tokens);

          state = state.copyWith(
            authStatus: AuthStatus.authenticated,
            statusMessage: '인증 완료! 색인 작업을 시작합니다...',
            currentPhase: '준비',
          );
        }
      }

      // 3. 모든 블로그에서 URL 수집
      state = state.copyWith(
        currentPhase: 'Sitemap 로딩',
        statusMessage: 'Sitemap 로딩 중...',
      );

      final allUrls = <String>[];
      for (final blogName in state.blogNames) {
        if (_isCancelled) break;

        state = state.copyWith(statusMessage: '$blogName sitemap 로딩 중...');

        try {
          final sitemapUrl = _getSitemapUrl(blogName);
          final urls = await SitemapParser.parseUrls(sitemapUrl);
          allUrls.addAll(urls);
        } catch (e) {
          // 개별 블로그 sitemap 오류는 무시
        }
      }

      if (_isCancelled) {
        state = state.copyWith(
          isRunning: false,
          clearStatus: true,
          clearPhase: true,
        );
        return;
      }

      if (allUrls.isEmpty) {
        state = state.copyWith(
          isRunning: false,
          errorMessage: 'Sitemap에서 URL을 찾을 수 없습니다.',
          clearStatus: true,
          clearPhase: true,
        );
        return;
      }

      // 3.5. 로컬 기록에서 이미 처리된 URL 필터링
      state = state.copyWith(
        currentPhase: '기록 확인',
        statusMessage: '이전 색인 기록 확인 중...',
      );

      final localIndexedUrls = await IndexingStorageService.loadIndexedUrls();
      final urlsToProcess = allUrls.where(
        (url) => !localIndexedUrls.containsKey(url),
      ).toList();
      final locallySkippedCount = allUrls.length - urlsToProcess.length;

      state = state.copyWith(
        allUrls: allUrls,
        totalCount: urlsToProcess.length,
      );

      if (urlsToProcess.isEmpty) {
        state = state.copyWith(
          isRunning: false,
          statusMessage: '모든 URL(${allUrls.length}개)이 이미 처리되었습니다.',
          clearPhase: true,
        );
        return;
      }

      // 4. URL별 색인 상태 확인 (Inspection 전용)
      state = state.copyWith(
        currentPhase: '색인 상태 확인',
        statusMessage: locallySkippedCount > 0
            ? '이전 기록 $locallySkippedCount개 제외, ${urlsToProcess.length}개 확인 중...'
            : '색인 상태 확인 중...',
        currentIndex: 0,
      );

      var inspectionService = UrlInspectionService(
        accessToken: tokens.accessToken,
      );
      final results = <UrlIndexingResult>[];
      final urlsToIndex = <String>[];
      var inspectionQuota = state.remainingInspectionQuota;
      var indexingQuota = state.remainingIndexingQuota;
      var indexedCount = 0;

      const inspectionBatchSize = 5;
      const delayBetweenBatches = Duration(milliseconds: 1000);

      for (
        int batchStart = 0;
        batchStart < urlsToProcess.length;
        batchStart += inspectionBatchSize
      ) {
        if (_isCancelled) break;

        final batchEnd =
            (batchStart + inspectionBatchSize).clamp(0, urlsToProcess.length);
        final batch = urlsToProcess.sublist(batchStart, batchEnd);

        state = state.copyWith(
          currentIndex: batchStart + 1,
          statusMessage:
              '색인 상태 확인 중... (${batchStart + 1}-$batchEnd/${urlsToProcess.length})',
        );

        for (final url in batch) {
          if (_isCancelled) break;

          if (inspectionQuota > 0) {
            final siteUrl = UrlInspectionService.extractSiteUrl(url);
            var inspectionResult = await inspectionService.inspectUrl(
              url: url,
              siteUrl: siteUrl,
            );

            // 토큰 만료 시 갱신 후 재시도
            if (inspectionResult.status == UrlIndexingStatus.tokenExpired &&
                tokens != null) {
              state = state.copyWith(statusMessage: '토큰 갱신 중...');

              final credentials =
                  await IndexingStorageService.loadOAuthCredentials();
              if (credentials != null) {
                _oauthService = GoogleOAuthService(
                  clientId: credentials.clientId,
                  clientSecret: credentials.clientSecret,
                );

                final refreshResult = await _oauthService!.refreshAccessToken(
                  tokens.refreshToken,
                );

                if (refreshResult.success) {
                  tokens = OAuthTokens(
                    accessToken: refreshResult.accessToken!,
                    refreshToken: refreshResult.refreshToken!,
                    expiresAt: refreshResult.expiresAt!,
                  );
                  await IndexingStorageService.saveOAuthTokens(tokens);

                  inspectionService.dispose();
                  inspectionService = UrlInspectionService(
                    accessToken: tokens.accessToken,
                  );

                  state = state.copyWith(statusMessage: '색인 상태 확인 중...');
                  inspectionResult = await inspectionService.inspectUrl(
                    url: url,
                    siteUrl: siteUrl,
                  );
                }
              }
            }

            await IndexingStorageService.incrementInspectionCount();
            inspectionQuota--;

            if (inspectionResult.status == UrlIndexingStatus.indexed) {
              results.add(UrlIndexingResult(
                url: url,
                status: IndexingStatus.alreadyIndexed,
              ));
              indexedCount++;
              await IndexingStorageService.markUrlAsVerified(url);
            } else if (inspectionResult.status == UrlIndexingStatus.error &&
                inspectionResult.errorMessage?.contains('429') == true) {
              inspectionQuota = 0;
              // 현재 URL은 확인 불가 — 색인 요청 대상에 포함
              urlsToIndex.add(url);
              results.add(UrlIndexingResult(
                url: url,
                status: IndexingStatus.pending,
              ));
            } else {
              // 미색인 또는 알 수 없음 — 색인 요청 대상
              urlsToIndex.add(url);
              results.add(UrlIndexingResult(
                url: url,
                status: IndexingStatus.pending,
              ));
            }
          } else {
            // Inspection 할당량 소진
            results.add(UrlIndexingResult(
              url: url,
              status: IndexingStatus.skipped,
              errorMessage: 'Inspection 할당량 소진',
            ));
          }
        }

        state = state.copyWith(
          results: List.from(results),
          currentIndex: batchEnd,
          remainingInspectionQuota: inspectionQuota,
        );

        if (batchEnd < urlsToProcess.length && !_isCancelled) {
          await Future.delayed(delayBetweenBatches);
        }
      }

      inspectionService.dispose();

      if (_isCancelled) {
        state = state.copyWith(
          isRunning: false,
          clearStatus: true,
          clearPhase: true,
        );
        return;
      }

      // 5. 미색인 URL 일괄 색인 요청 (Batch Request)
      var requestedCount = 0;

      if (urlsToIndex.isNotEmpty && indexingQuota > 0) {
        // 할당량 내에서 처리할 URL 분리
        final urlsWithinQuota = urlsToIndex.length <= indexingQuota
            ? urlsToIndex
            : urlsToIndex.sublist(0, indexingQuota);

        // 할당량 초과분은 스킵 처리
        for (int i = indexingQuota; i < urlsToIndex.length; i++) {
          final idx = results.indexWhere((r) => r.url == urlsToIndex[i]);
          if (idx >= 0) {
            results[idx] = UrlIndexingResult(
              url: urlsToIndex[i],
              status: IndexingStatus.skipped,
              errorMessage: '일일 할당량 초과',
            );
          }
        }

        state = state.copyWith(
          currentPhase: '색인 요청',
          statusMessage:
              '${urlsWithinQuota.length}개 URL 일괄 색인 요청 중...',
          currentIndex: 0,
          totalCount: urlsWithinQuota.length,
          results: List.from(results),
        );

        // 100개씩 Batch Request 전송
        const batchChunkSize = 100;

        for (
          int i = 0;
          i < urlsWithinQuota.length;
          i += batchChunkSize
        ) {
          if (_isCancelled) break;

          final chunkEnd =
              (i + batchChunkSize).clamp(0, urlsWithinQuota.length);
          final chunk = urlsWithinQuota.sublist(i, chunkEnd);

          state = state.copyWith(
            currentIndex: chunkEnd,
            statusMessage:
                '일괄 색인 요청 중... ($chunkEnd/${urlsWithinQuota.length})',
          );

          final batchResults =
              await _indexingService.requestBatchIndexing(chunk);

          for (final entry in batchResults.entries) {
            final url = entry.key;
            final apiResult = entry.value;
            final idx = results.indexWhere((r) => r.url == url);

            if (apiResult.success) {
              await IndexingStorageService.incrementTodayCount();
              if (idx >= 0) {
                results[idx] = UrlIndexingResult(
                  url: url,
                  status: IndexingStatus.success,
                );
              }
              requestedCount++;
            } else {
              await IndexingStorageService.incrementTodayCount();
              if (idx >= 0) {
                results[idx] = UrlIndexingResult(
                  url: url,
                  status: apiResult.errorMessage?.contains('429') == true
                      ? IndexingStatus.skipped
                      : IndexingStatus.failed,
                  errorMessage: apiResult.errorMessage,
                );
              }
            }
          }

          indexingQuota -= chunk.length;

          state = state.copyWith(
            results: List.from(results),
            remainingIndexingQuota:
                indexingQuota.clamp(0, IndexingStorageService.defaultDailyLimit),
          );
        }
      } else if (urlsToIndex.isNotEmpty && indexingQuota <= 0) {
        // 할당량이 전혀 없는 경우
        for (final url in urlsToIndex) {
          final idx = results.indexWhere((r) => r.url == url);
          if (idx >= 0) {
            results[idx] = UrlIndexingResult(
              url: url,
              status: IndexingStatus.skipped,
              errorMessage: '일일 할당량 초과',
            );
          }
        }
        state = state.copyWith(results: List.from(results));
      }

      // 결과 메시지 생성
      final messageParts = <String>[];
      if (requestedCount > 0) messageParts.add('$requestedCount개 색인 요청 완료');
      if (indexedCount > 0) messageParts.add('$indexedCount개 이미 색인됨');
      if (locallySkippedCount > 0) {
        messageParts.add('$locallySkippedCount개 이전 기록 제외');
      }
      final resultMessage = messageParts.isNotEmpty
          ? messageParts.join(', ')
          : '처리 완료';

      // 캐시 저장 및 정리
      await IndexingStorageService.flushCache();
      await IndexingStorageService.cleanupOldRecords();
      await IndexingStorageService.flushCache();

      state = state.copyWith(
        isRunning: false,
        statusMessage: resultMessage,
        clearPhase: true,
      );
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        errorMessage: e.toString(),
        clearStatus: true,
        clearPhase: true,
      );
    }
  }

  /// 진행 중인 작업 취소
  void cancel() {
    _isCancelled = true;
    state = state.copyWith(
      isRunning: false,
      statusMessage: '취소됨',
      clearPhase: true,
    );
  }

  /// 에러 메시지 지우기
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 결과 초기화
  void reset() {
    state = state.copyWith(
      allUrls: [],
      results: [],
      currentIndex: 0,
      totalCount: 0,
      clearError: true,
      clearStatus: true,
      clearPhase: true,
    );
  }
}
