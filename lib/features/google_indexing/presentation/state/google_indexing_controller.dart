import 'package:csias_desktop/features/google_indexing/data/google_indexing_service.dart';
import 'package:csias_desktop/features/google_indexing/data/indexing_storage_service.dart';
import 'package:csias_desktop/features/google_indexing/data/sitemap_parser.dart';
import 'package:csias_desktop/features/google_indexing/domain/models/indexing_result.dart';
import 'package:csias_desktop/features/google_indexing/presentation/state/google_indexing_state.dart';
import 'package:csias_desktop/features/tistory_posting/data/unified_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoogleIndexingController extends Notifier<GoogleIndexingState> {
  final _indexingService = GoogleIndexingService();
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
    final remainingQuota = await IndexingStorageService.getRemainingDailyQuota();
    final blogNames = await _loadAllBlogNames();

    state = state.copyWith(
      hasServiceAccount: hasServiceAccount,
      remainingQuota: remainingQuota,
      blogNames: blogNames,
    );
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

  /// 전체 색인 요청 시작
  Future<void> startIndexing() async {
    if (state.isRunning) return;

    // 상태 새로고침
    await refresh();

    if (!state.hasServiceAccount) {
      state = state.copyWith(
        errorMessage: '서비스 계정 JSON 파일이 없습니다.',
      );
      return;
    }

    if (state.blogNames.isEmpty) {
      state = state.copyWith(
        errorMessage: '등록된 블로그가 없습니다. Tistory 계정을 먼저 추가해주세요.',
      );
      return;
    }

    if (state.remainingQuota <= 0) {
      state = state.copyWith(
        errorMessage: '오늘의 일일 할당량(200개)을 모두 사용했습니다.',
      );
      return;
    }

    _isCancelled = false;
    state = state.copyWith(
      isRunning: true,
      allUrls: [],
      pendingUrls: [],
      results: [],
      currentIndex: 0,
      clearError: true,
      statusMessage: '인증 중...',
    );

    try {
      // 1. 인증
      await _indexingService.authenticate(IndexingStorageService.serviceAccountPath);

      // 2. 모든 블로그에서 URL 수집
      state = state.copyWith(statusMessage: 'Sitemap 로딩 중...');
      final allUrls = <String>[];

      for (final blogName in state.blogNames) {
        if (_isCancelled) break;

        state = state.copyWith(statusMessage: '$blogName sitemap 로딩 중...');

        try {
          final sitemapUrl = _getSitemapUrl(blogName);
          final urls = await SitemapParser.parseUrls(sitemapUrl);
          allUrls.addAll(urls);
        } catch (e) {
          // 개별 블로그 sitemap 오류는 무시하고 계속 진행
        }
      }

      if (_isCancelled) {
        state = state.copyWith(isRunning: false, clearStatus: true);
        return;
      }

      if (allUrls.isEmpty) {
        state = state.copyWith(
          isRunning: false,
          errorMessage: 'Sitemap에서 URL을 찾을 수 없습니다.',
          clearStatus: true,
        );
        return;
      }

      state = state.copyWith(allUrls: allUrls);

      // 3. 이미 색인된 URL 제외
      state = state.copyWith(statusMessage: '색인 상태 확인 중...');
      final indexedUrls = await IndexingStorageService.loadIndexedUrls();
      final pendingUrls = allUrls.where((url) => !indexedUrls.containsKey(url)).toList();

      if (pendingUrls.isEmpty) {
        state = state.copyWith(
          isRunning: false,
          statusMessage: '모든 URL이 이미 색인되어 있습니다.',
        );
        return;
      }

      state = state.copyWith(pendingUrls: pendingUrls);

      // 4. 색인 요청 진행
      final results = <UrlIndexingResult>[];
      var remainingQuota = state.remainingQuota;

      for (int i = 0; i < pendingUrls.length; i++) {
        if (_isCancelled) break;

        final url = pendingUrls[i];
        state = state.copyWith(
          currentIndex: i + 1,
          statusMessage: '색인 요청 중... (${i + 1}/${pendingUrls.length})',
        );

        // 할당량 확인 - 초과 시 남은 URL 모두 스킵 처리하고 종료
        if (remainingQuota <= 0) {
          // 남은 모든 URL을 스킵 처리
          for (int j = i; j < pendingUrls.length; j++) {
            results.add(UrlIndexingResult(
              url: pendingUrls[j],
              status: IndexingStatus.skipped,
              errorMessage: '일일 할당량 초과',
            ));
          }
          state = state.copyWith(
            results: List.from(results),
            errorMessage: '일일 할당량(200개)을 모두 사용했습니다. 내일 다시 시도해주세요.',
          );
          break;
        }

        // API 호출
        final apiResult = await _indexingService.requestIndexing(url);

        if (apiResult.success) {
          await IndexingStorageService.markUrlAsIndexed(url);
          results.add(UrlIndexingResult(
            url: url,
            status: IndexingStatus.success,
          ));
        } else {
          // 429 에러 (Rate Limit) 시 중단
          if (apiResult.errorMessage?.contains('429') == true) {
            results.add(UrlIndexingResult(
              url: url,
              status: IndexingStatus.failed,
              errorMessage: 'API 요청 한도 초과 - 잠시 후 다시 시도해주세요.',
            ));
            await IndexingStorageService.incrementTodayCount();
            state = state.copyWith(
              results: List.from(results),
              errorMessage: 'API 요청 한도 초과로 중단되었습니다.',
            );
            break;
          }

          await IndexingStorageService.incrementTodayCount();
          results.add(UrlIndexingResult(
            url: url,
            status: IndexingStatus.failed,
            errorMessage: apiResult.errorMessage,
          ));
        }

        remainingQuota--;
        state = state.copyWith(
          results: List.from(results),
          remainingQuota: remainingQuota,
        );

        // Rate Limiting: 1초 딜레이
        if (i < pendingUrls.length - 1 && !_isCancelled) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      // 오래된 기록 정리
      await IndexingStorageService.cleanupOldRecords();

      state = state.copyWith(
        isRunning: false,
        clearStatus: true,
      );
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        errorMessage: e.toString(),
        clearStatus: true,
      );
    }
  }

  /// 진행 중인 색인 요청 취소
  void cancel() {
    _isCancelled = true;
    state = state.copyWith(
      isRunning: false,
      statusMessage: '취소됨',
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
      pendingUrls: [],
      results: [],
      currentIndex: 0,
      clearError: true,
      clearStatus: true,
    );
  }
}
