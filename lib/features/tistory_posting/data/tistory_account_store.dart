import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/tistory_account.dart';

class TistoryAccountStore {
  static const _key = 'tistory_accounts';

  static late final SharedPreferences _preferences;

  Future<List<TistoryAccount>> loadAccounts() async {
    try {
      _preferences = await SharedPreferences.getInstance();

      final raw = _preferences.getString(_key);
      if (raw == null) return [];

      final List decoded = jsonDecode(raw);

      final accountList = <TistoryAccount>[];
      for (final item in decoded) {
        if (item is! Map) continue;

        final id = item['id']?.toString().trim();
        final kakaoId = item['kakaoId']?.toString().trim();
        final password = item['password']?.toString().trim();
        final blogName = item['blogName']?.toString().trim();
        final storageStatePath = item['storageStatePath']?.toString().trim();

        if (id == null || id.isEmpty) continue;
        if (kakaoId == null || kakaoId.isEmpty) continue;
        if (password == null || password.isEmpty) continue;

        accountList.add(
          TistoryAccount(
            id: id,
            kakaoId: kakaoId,
            blogName: (blogName ?? ""),
            password: password,
            storageStatePath: storageStatePath,
          ),
        );
      }

      return accountList;
    } catch (e, st) {
      debugPrint('[AccountStore] load ERROR: $e\n$st');
      return [];
    }
  }

  Future<void> saveAccounts(List<TistoryAccount> accounts) async {
    try {
      final encoded = jsonEncode(
        accounts
            .map(
              (a) => {'id': a.id, 'kakaoId': a.kakaoId, 'blogName': a.blogName},
            )
            .toList(),
      );

      await _preferences.setString(_key, encoded);
    } catch (e, st) {
      debugPrint('[AccountStore] save ERROR: $e\n$st');
    }
  }
}
