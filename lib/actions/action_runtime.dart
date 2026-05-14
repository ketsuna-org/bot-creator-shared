import 'dart:async';

Map<String, String> actionError({
  required String code,
  required String message,
  Map<String, String>? data,
}) {
  return <String, String>{'error': message, 'errorCode': code, ...?data};
}

Future<T> runWithTimeout<T>(
  Future<T> Function() operation, {
  Duration timeout = const Duration(seconds: 10),
}) {
  return operation().timeout(timeout);
}
