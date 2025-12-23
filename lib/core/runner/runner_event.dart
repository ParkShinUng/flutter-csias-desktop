class RunnerEvent {
  final String event;
  final String? message;
  final Map<String, dynamic> raw;

  RunnerEvent({required this.event, required this.raw, this.message});

  factory RunnerEvent.fromJson(Map<String, dynamic> json) {
    return RunnerEvent(
      event: (json["event"] ?? "log").toString(),
      message: json["message"]?.toString(),
      raw: json,
    );
  }
}
