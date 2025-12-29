import 'dart:convert';
import 'dart:io';

/// 비밀번호를 로컬 파일에 암호화하여 저장/불러오기 합니다.
/// macOS Keychain 대신 파일 기반 저장소를 사용합니다.
/// (ad-hoc 서명된 앱에서 Keychain 접근 문제 해결)
class SecurePasswordService {
  static const _fileName = 'credentials.dat';
  static const _obfuscationKey = 'csias_desktop_secure_key_2024';

  static String get _storagePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Application Support/csias_desktop/data';
  }

  static File get _file => File('$_storagePath/$_fileName');

  /// 저장된 모든 비밀번호 맵을 불러옵니다.
  static Future<Map<String, String>> _loadAll() async {
    try {
      final file = _file;
      if (!await file.exists()) {
        return {};
      }
      final encoded = await file.readAsString();
      final decoded = _decode(encoded);
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return json.map((k, v) => MapEntry(k, v as String));
    } catch (e) {
      return {};
    }
  }

  /// 모든 비밀번호 맵을 저장합니다.
  static Future<void> _saveAll(Map<String, String> passwords) async {
    final file = _file;
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final json = jsonEncode(passwords);
    final encoded = _encode(json);
    await file.writeAsString(encoded);
  }

  /// 문자열을 인코딩합니다. (XOR + Base64)
  static String _encode(String input) {
    final inputBytes = utf8.encode(input);
    final keyBytes = utf8.encode(_obfuscationKey);
    final result = <int>[];
    for (var i = 0; i < inputBytes.length; i++) {
      result.add(inputBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64Encode(result);
  }

  /// 인코딩된 문자열을 디코딩합니다.
  static String _decode(String encoded) {
    final bytes = base64Decode(encoded);
    final keyBytes = utf8.encode(_obfuscationKey);
    final result = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      result.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return utf8.decode(result);
  }

  /// 계정 ID에 해당하는 비밀번호를 저장합니다.
  static Future<void> savePassword(String accountId, String password) async {
    final passwords = await _loadAll();
    passwords[accountId] = password;
    await _saveAll(passwords);
  }

  /// 계정 ID에 해당하는 비밀번호를 불러옵니다.
  /// 비밀번호가 없으면 null을 반환합니다.
  static Future<String?> getPassword(String accountId) async {
    final passwords = await _loadAll();
    return passwords[accountId];
  }

  /// 계정 ID에 해당하는 비밀번호를 삭제합니다.
  static Future<void> deletePassword(String accountId) async {
    final passwords = await _loadAll();
    passwords.remove(accountId);
    await _saveAll(passwords);
  }

  /// 모든 저장된 비밀번호를 삭제합니다. (앱 초기화 시 사용)
  static Future<void> deleteAll() async {
    final file = _file;
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 비밀번호가 저장되어 있는지 확인합니다.
  static Future<bool> hasPassword(String accountId) async {
    final passwords = await _loadAll();
    final password = passwords[accountId];
    return password != null && password.isNotEmpty;
  }
}
