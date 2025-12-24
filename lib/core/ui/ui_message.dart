enum UiMessageType { info, warning, error }

class UiMessage {
  final UiMessageType type;
  final String title;
  final String message;
  final String? detail; // 선택: 예외/스택 등

  const UiMessage({
    required this.type,
    required this.title,
    required this.message,
    this.detail,
  });

  factory UiMessage.error(
    String message, {
    String title = "Error",
    String? detail,
  }) {
    return UiMessage(
      type: UiMessageType.error,
      title: title,
      message: message,
      detail: detail,
    );
  }

  factory UiMessage.info(String message, {String title = "Information"}) {
    return UiMessage(type: UiMessageType.info, title: title, message: message);
  }

  factory UiMessage.warning(String message, {String title = "Warning"}) {
    return UiMessage(
      type: UiMessageType.warning,
      title: title,
      message: message,
    );
  }
}
