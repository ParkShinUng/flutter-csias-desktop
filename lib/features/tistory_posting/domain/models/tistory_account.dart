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

  Map<String, dynamic> toJson() => {
        'id': id,
        'kakaoId': kakaoId,
        'password': password,
        'blogName': blogName,
        if (storageState != null) 'storageState': storageState,
        'postingHistory': postingHistory,
      };

  factory TistoryAccount.fromJson(Map<String, dynamic> json) {
    return TistoryAccount(
      id: json['id'] as String,
      kakaoId: json['kakaoId'] as String,
      password: json['password'] as String,
      blogName: json['blogName'] as String,
      storageState: json['storageState'] as Map<String, dynamic>?,
      postingHistory: (json['postingHistory'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
    );
  }

  String get displayName => '$kakaoId ($blogName)';
}
