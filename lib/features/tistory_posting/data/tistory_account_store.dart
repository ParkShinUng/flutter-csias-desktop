import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/tistory_account.dart';

class TistoryAccountStore {
  static const _key = 'tistory_accounts_v1';

  Future<List<TistoryAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(TistoryAccount.fromJson).toList();
  }

  Future<void> save(List<TistoryAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
