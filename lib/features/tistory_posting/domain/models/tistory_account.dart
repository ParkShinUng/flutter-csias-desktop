class TistoryAccount {
  final String id;
  final String kakaoId;
  final String password;
  final String blogName;
  final String? storageStatePath;

  const TistoryAccount({
    required this.id,
    required this.kakaoId,
    required this.password,
    required this.blogName,
    required this.storageStatePath,
  });

  TistoryAccount copyWith({
    String? id,
    String? kakaoId,
    String? password,
    String? blogName,
    String? storageStatePath,
  }) {
    return TistoryAccount(
      id: id ?? this.id,
      kakaoId: kakaoId ?? this.kakaoId,
      password: password ?? this.password,
      blogName: blogName ?? this.blogName,
      storageStatePath: storageStatePath ?? this.storageStatePath,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kakaoId': kakaoId,
    'password': password,
    'blogName': blogName,
    'storagePath': storageStatePath,
  };

  static TistoryAccount fromJson(Map<String, dynamic> json) {
    return TistoryAccount(
      id: json['id'] as String,
      kakaoId: json['displayName'] as String,
      password: json['passwordKey'] as String,
      blogName: json['blogName'] as String,
      storageStatePath: json['storageStatePath'] as String,
    );
  }
}
