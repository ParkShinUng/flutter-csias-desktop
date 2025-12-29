import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 비밀번호를 플랫폼별 보안 저장소에 안전하게 저장/불러오기 합니다.
/// - macOS: Keychain
/// - Windows: Windows Credential Manager
/// - Linux: libsecret
class SecurePasswordService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
    wOptions: WindowsOptions(),
  );

  static const _keyPrefix = 'csias_account_password_';

  /// 계정 ID에 해당하는 비밀번호를 저장합니다.
  static Future<void> savePassword(String accountId, String password) async {
    await _storage.write(key: '$_keyPrefix$accountId', value: password);
  }

  /// 계정 ID에 해당하는 비밀번호를 불러옵니다.
  /// 비밀번호가 없으면 null을 반환합니다.
  static Future<String?> getPassword(String accountId) async {
    return await _storage.read(key: '$_keyPrefix$accountId');
  }

  /// 계정 ID에 해당하는 비밀번호를 삭제합니다.
  static Future<void> deletePassword(String accountId) async {
    await _storage.delete(key: '$_keyPrefix$accountId');
  }

  /// 모든 저장된 비밀번호를 삭제합니다. (앱 초기화 시 사용)
  static Future<void> deleteAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_keyPrefix)) {
        await _storage.delete(key: key);
      }
    }
  }

  /// 비밀번호가 저장되어 있는지 확인합니다.
  static Future<bool> hasPassword(String accountId) async {
    final password = await _storage.read(key: '$_keyPrefix$accountId');
    return password != null && password.isNotEmpty;
  }
}
