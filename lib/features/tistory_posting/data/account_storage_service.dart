import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';

class AccountStorageService {
  static const _fileName = 'accounts.json';

  static String get _storagePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Application Support/csias_desktop/storageState';
  }

  static String get _filePath => '$_storagePath/$_fileName';

  static Future<void> _ensureDirectory() async {
    final dir = Directory(_storagePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static Future<List<TistoryAccount>> loadAccounts() async {
    try {
      await _ensureDirectory();
      final file = File(_filePath);

      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);

      return jsonList
          .map((json) => TistoryAccount.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveAccounts(List<TistoryAccount> accounts) async {
    await _ensureDirectory();
    final file = File(_filePath);
    final jsonList = accounts.map((a) => a.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  static Future<void> addAccount(TistoryAccount account) async {
    final accounts = await loadAccounts();
    accounts.add(account);
    await saveAccounts(accounts);
  }

  static Future<void> updateAccount(TistoryAccount account) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      accounts[index] = account;
      await saveAccounts(accounts);
    }
  }

  static Future<void> deleteAccount(String accountId) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((a) => a.id == accountId);
    await saveAccounts(accounts);

    // storageState 파일도 삭제
    final account = accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => TistoryAccount(id: '', kakaoId: '', password: '', blogName: ''),
    );
    if (account.kakaoId.isNotEmpty) {
      final stateFile = File('$_storagePath/tistory_${account.kakaoId}.storageState.json');
      if (await stateFile.exists()) {
        await stateFile.delete();
      }
    }
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
