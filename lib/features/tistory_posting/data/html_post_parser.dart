import 'dart:io';
import 'package:csias_desktop/features/tistory_posting/domain/models/parsed_post.dart';
import 'package:html/parser.dart' as html_parser;

class HtmlPostParser {
  /// html 파일 → ParsedPost
  /// 규칙:
  /// 1. 첫 번째 <h1> → title
  /// 2. <body> 내부 HTML → body
  /// 3. <body> 없으면 전체 HTML 사용
  ParsedPost parseFile(String path) {
    final file = File(path);

    if (!file.existsSync()) {
      throw Exception("파일이 존재하지 않습니다.");
    }

    final raw = file.readAsStringSync();
    final doc = html_parser.parse(raw);

    // ---- title ----
    final h1 = doc.querySelector('h1');
    if (h1 == null) {
      throw Exception("<h1> 태그를 찾을 수 없습니다.");
    }

    final title = h1.text.trim();
    if (title.isEmpty) {
      throw Exception("제목(<h1>)이 비어 있습니다.");
    }

    // ---- body ----
    final body = doc.querySelector('body');
    final bodyHtml = body != null ? body.innerHtml : raw;

    return ParsedPost(title: title, bodyHtml: bodyHtml);
  }
}
