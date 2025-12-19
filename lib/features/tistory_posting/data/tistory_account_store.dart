import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/tistory_account.dart';

class TistoryAccountStore {
  static const _key = 'tistory_accounts';

  Future<List<TistoryAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];

    final List decoded = jsonDecode(raw);
    return decoded
        .map(
          (e) => TistoryAccount(
            id: e['id'],
            kakaoId: e['kakaoId'],
            password: e['password'],
            blogName: e['blogName'],
          ),
        )
        .toList();
  }

  Future<void> saveAccounts(List<TistoryAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      accounts
          .map(
            (a) => {'id': a.id, 'kakaoId': a.kakaoId, 'blogName': a.blogName},
          )
          .toList(),
    );
    await prefs.setString(_key, encoded);
  }
}
