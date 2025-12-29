/// 스토리지 관련 예외
class StorageException implements Exception {
  final String message;
  final String? details;
  final Object? originalError;

  const StorageException(
    this.message, {
    this.details,
    this.originalError,
  });

  @override
  String toString() {
    if (details != null) {
      return 'StorageException: $message ($details)';
    }
    return 'StorageException: $message';
  }
}

/// 계정 로드 실패 예외
class AccountLoadException extends StorageException {
  const AccountLoadException({
    String message = '계정을 불러오는 데 실패했습니다',
    String? details,
    Object? originalError,
  }) : super(message, details: details, originalError: originalError);
}

/// 계정 저장 실패 예외
class AccountSaveException extends StorageException {
  const AccountSaveException({
    String message = '계정을 저장하는 데 실패했습니다',
    String? details,
    Object? originalError,
  }) : super(message, details: details, originalError: originalError);
}

/// 비밀번호 저장소 예외
class SecureStorageException extends StorageException {
  const SecureStorageException({
    String message = '보안 저장소 접근에 실패했습니다',
    String? details,
    Object? originalError,
  }) : super(message, details: details, originalError: originalError);
}

/// 포스팅 관련 예외
class PostingException implements Exception {
  final String message;
  final String? details;
  final Object? originalError;

  const PostingException(
    this.message, {
    this.details,
    this.originalError,
  });

  @override
  String toString() {
    if (details != null) {
      return 'PostingException: $message ($details)';
    }
    return 'PostingException: $message';
  }
}

/// 브라우저를 찾을 수 없는 예외
class BrowserNotFoundException extends PostingException {
  const BrowserNotFoundException()
      : super(
          'Chrome 또는 Edge 브라우저를 찾을 수 없습니다',
          details: 'Google Chrome 또는 Microsoft Edge를 설치해주세요.',
        );
}

/// 포스팅 실행 실패 예외
class PostingExecutionException extends PostingException {
  const PostingExecutionException({
    String message = '포스팅 실행에 실패했습니다',
    String? details,
    Object? originalError,
  }) : super(message, details: details, originalError: originalError);
}
