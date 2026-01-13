import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// 캐시된 Sitemap 데이터
class _CachedSitemap {
  final List<String> urls;
  final DateTime fetchedAt;

  _CachedSitemap({required this.urls, required this.fetchedAt});

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > const Duration(minutes: 30);
}

/// Sitemap.xml에서 URL 목록을 추출하는 서비스
class SitemapParser {
  /// 티스토리 포스팅 URL 패턴 (숫자로 끝나는 URL)
  static final _postingPattern = RegExp(r'/\d+$');

  /// 모바일 URL 패턴 (/m/ 경로 포함)
  static final _mobilePattern = RegExp(r'/m/');

  /// Sitemap 캐시 (30분 TTL)
  static final Map<String, _CachedSitemap> _cache = {};

  /// 캐시 초기화
  static void clearCache() {
    _cache.clear();
  }

  /// 포스팅 URL인지 확인
  static bool isPostingUrl(String url) {
    return _postingPattern.hasMatch(url);
  }

  /// 모바일 URL인지 확인
  static bool isMobileUrl(String url) {
    return _mobilePattern.hasMatch(url);
  }

  /// sitemap URL에서 URL을 추출합니다.
  /// [postingsOnly]가 true이면 포스팅 URL만 반환합니다.
  /// [useCache]가 true이면 캐시된 결과를 사용합니다 (기본값: true).
  static Future<List<String>> parseUrls(
    String sitemapUrl, {
    bool postingsOnly = true,
    bool useCache = true,
  }) async {
    // 캐시 확인
    if (useCache) {
      final cached = _cache[sitemapUrl];
      if (cached != null && !cached.isExpired) {
        // 캐시된 전체 URL 목록에서 필터링
        if (postingsOnly) {
          return cached.urls.where(isPostingUrl).toList();
        }
        return List.from(cached.urls);
      }
    }

    try {
      final response = await http.get(Uri.parse(sitemapUrl));

      if (response.statusCode != 200) {
        throw Exception('Sitemap 로드 실패: HTTP ${response.statusCode}');
      }

      final document = XmlDocument.parse(response.body);
      final allUrls = <String>[];

      // sitemap index인 경우 (여러 sitemap을 포함)
      final sitemapElements = document.findAllElements('sitemap');
      if (sitemapElements.isNotEmpty) {
        for (final sitemap in sitemapElements) {
          final loc = sitemap.findElements('loc').firstOrNull?.innerText;
          if (loc != null) {
            // 하위 sitemap을 재귀적으로 파싱 (필터링 없이)
            final subUrls =
                await parseUrls(loc, postingsOnly: false, useCache: useCache);
            allUrls.addAll(subUrls);
          }
        }
      } else {
        // 일반 sitemap인 경우
        final urlElements = document.findAllElements('url');
        for (final urlElement in urlElements) {
          final loc = urlElement.findElements('loc').firstOrNull?.innerText;
          if (loc != null && loc.isNotEmpty) {
            // 모바일 URL 제외
            if (isMobileUrl(loc)) {
              continue;
            }
            allUrls.add(loc);
          }
        }
      }

      // 캐시에 저장 (필터링 전 전체 URL)
      _cache[sitemapUrl] = _CachedSitemap(
        urls: allUrls,
        fetchedAt: DateTime.now(),
      );

      // 필터링 적용
      if (postingsOnly) {
        return allUrls.where(isPostingUrl).toList();
      }
      return allUrls;
    } on XmlParserException catch (e) {
      throw Exception('Sitemap XML 파싱 실패: ${e.message}');
    } catch (e) {
      throw Exception('Sitemap 파싱 중 오류: $e');
    }
  }
}
