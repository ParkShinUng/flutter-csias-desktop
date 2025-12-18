class RunnerMessage {
  final String jobId;
  final String status; // log | success | failed
  final String? message;
  final String? error;

  const RunnerMessage({
    required this.jobId,
    required this.status,
    this.message,
    this.error,
  });

  factory RunnerMessage.fromJson(Map<String, dynamic> json) {
    return RunnerMessage(
      jobId: json['jobId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString(),
      error: json['error']?.toString(),
    );
  }
}
