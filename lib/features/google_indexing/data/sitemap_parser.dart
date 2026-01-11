import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// Sitemap.xml에서 URL 목록을 추출하는 서비스
class SitemapParser {
  /// 티스토리 포스팅 URL 패턴 (숫자로 끝나는 URL)
  static final _postingPattern = RegExp(r'/\d+$');

  /// 포스팅 URL인지 확인
  static bool isPostingUrl(String url) {
    return _postingPattern.hasMatch(url);
  }

  /// sitemap URL에서 URL을 추출합니다.
  /// [postingsOnly]가 true이면 포스팅 URL만 반환합니다.
  static Future<List<String>> parseUrls(
    String sitemapUrl, {
    bool postingsOnly = true,
  }) async {
    try {
      final response = await http.get(Uri.parse(sitemapUrl));

      if (response.statusCode != 200) {
        throw Exception('Sitemap 로드 실패: HTTP ${response.statusCode}');
      }

      final document = XmlDocument.parse(response.body);
      final urls = <String>[];

      // sitemap index인 경우 (여러 sitemap을 포함)
      final sitemapElements = document.findAllElements('sitemap');
      if (sitemapElements.isNotEmpty) {
        for (final sitemap in sitemapElements) {
          final loc = sitemap.findElements('loc').firstOrNull?.innerText;
          if (loc != null) {
            // 하위 sitemap을 재귀적으로 파싱
            final subUrls = await parseUrls(loc, postingsOnly: postingsOnly);
            urls.addAll(subUrls);
          }
        }
        return urls;
      }

      // 일반 sitemap인 경우
      final urlElements = document.findAllElements('url');
      for (final urlElement in urlElements) {
        final loc = urlElement.findElements('loc').firstOrNull?.innerText;
        if (loc != null && loc.isNotEmpty) {
          // 포스팅만 필터링 옵션 적용
          if (postingsOnly && !isPostingUrl(loc)) {
            continue;
          }
          urls.add(loc);
        }
      }

      return urls;
    } on XmlParserException catch (e) {
      throw Exception('Sitemap XML 파싱 실패: ${e.message}');
    } catch (e) {
      throw Exception('Sitemap 파싱 중 오류: $e');
    }
  }
}
