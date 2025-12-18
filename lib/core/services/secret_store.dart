import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecretStore {
  static const _storage = FlutterSecureStorage();

  Future<void> save(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<String?> get(String key) => _storage.read(key: key);
  Future<void> remove(String key) => _storage.delete(key: key);
}
