enum TistoryAuthType { credentials, cookies }

class TistoryAccount {
  final String id;
  final String displayName;
  final TistoryAuthType authType;

  // credentials
  final String? loginId;
  final String? passwordKey; // secure storage key
  final String? blogName;

  // cookies
  final String? tsSession;
  final String? tAno;

  const TistoryAccount({
    required this.id,
    required this.displayName,
    required this.authType,
    this.loginId,
    this.passwordKey,
    this.blogName,
    this.tsSession,
    this.tAno,
  });

  TistoryAccount copyWith({
    String? id,
    String? displayName,
    TistoryAuthType? authType,
    String? loginId,
    String? passwordKey,
    String? blogName,
    String? tsSession,
    String? tAno,
  }) {
    return TistoryAccount(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      authType: authType ?? this.authType,
      loginId: loginId ?? this.loginId,
      passwordKey: passwordKey ?? this.passwordKey,
      blogName: blogName ?? this.blogName,
      tsSession: tsSession ?? this.tsSession,
      tAno: tAno ?? this.tAno,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'authType': authType.name,
    'loginId': loginId,
    'passwordKey': passwordKey,
    'blogName': blogName,
    'tsSession': tsSession,
    'tAno': tAno,
  };

  static TistoryAccount fromJson(Map<String, dynamic> json) {
    return TistoryAccount(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      authType: TistoryAuthType.values.firstWhere(
        (e) => e.name == json['authType'],
        orElse: () => TistoryAuthType.credentials,
      ),
      loginId: json['loginId'] as String?,
      passwordKey: json['passwordKey'] as String?,
      blogName: json['blogName'] as String?,
      tsSession: json['tsSession'] as String?,
      tAno: json['tAno'] as String?,
    );
  }
}
