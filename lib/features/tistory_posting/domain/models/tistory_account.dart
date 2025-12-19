class TistoryAccount {
  final String id;
  final String kakaoId;
  final String password;
  final String blogName;

  const TistoryAccount({
    required this.id,
    required this.kakaoId,
    required this.password,
    required this.blogName,
  });

  TistoryAccount copyWith({
    String? id,
    String? displayName,
    String? loginId,
    String? password,
    String? blogName,
  }) {
    return TistoryAccount(
      id: id ?? this.id,
      kakaoId: displayName ?? this.kakaoId,
      password: password ?? this.password,
      blogName: blogName ?? this.blogName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kakaoId': kakaoId,
    'password': password,
    'blogName': blogName,
  };

  static TistoryAccount fromJson(Map<String, dynamic> json) {
    return TistoryAccount(
      id: json['id'] as String,
      kakaoId: json['displayName'] as String,
      password: json['passwordKey'] as String,
      blogName: json['blogName'] as String,
    );
  }
}
