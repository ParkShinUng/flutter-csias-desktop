class TistoryAccount {
  final String id;
  final String kakaoId;
  final String password;
  final String blogName;
  final Map<String, dynamic>? storageState;
  final Map<String, int> postingHistory; // date -> count

  const TistoryAccount({
    required this.id,
    required this.kakaoId,
    required this.password,
    required this.blogName,
    this.storageState,
    this.postingHistory = const {},
  });

  TistoryAccount copyWith({
    String? id,
    String? kakaoId,
    String? password,
    String? blogName,
    Map<String, dynamic>? storageState,
    bool clearStorageState = false,
    Map<String, int>? postingHistory,
  }) {
    return TistoryAccount(
      id: id ?? this.id,
      kakaoId: kakaoId ?? this.kakaoId,
      password: password ?? this.password,
      blogName: blogName ?? this.blogName,
      storageState: clearStorageState ? null : (storageState ?? this.storageState),
      postingHistory: postingHistory ?? this.postingHistory,
    );
  }

  /// JSON으로 직렬화합니다.
  /// 주의: 비밀번호는 보안상 제외됩니다. SecurePasswordService를 통해 별도 저장하세요.
  Map<String, dynamic> toJson() => {
        'id': id,
        'kakaoId': kakaoId,
        // password는 보안상 제외 - SecurePasswordService에서 별도 관리
        'blogName': blogName,
        if (storageState != null) 'storageState': storageState,
        'postingHistory': postingHistory,
      };

  /// JSON에서 역직렬화합니다.
  /// password는 빈 문자열로 초기화되며, SecurePasswordService에서 별도로 불러와야 합니다.
  /// legacyPassword는 마이그레이션용으로 기존 JSON에 password가 있으면 반환합니다.
  factory TistoryAccount.fromJson(Map<String, dynamic> json) {
    return TistoryAccount(
      id: json['id'] as String,
      kakaoId: json['kakaoId'] as String,
      // password는 secure storage에서 별도로 불러옴
      password: '',
      blogName: json['blogName'] as String,
      storageState: json['storageState'] as Map<String, dynamic>?,
      postingHistory: (json['postingHistory'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
    );
  }

  /// 기존 JSON에서 평문 비밀번호를 추출합니다. (마이그레이션용)
  static String? extractLegacyPassword(Map<String, dynamic> json) {
    return json['password'] as String?;
  }

  String get displayName => '$kakaoId ($blogName)';
}
