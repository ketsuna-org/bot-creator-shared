import 'dart:async';

Map<String, String> actionError({
  required String code,
  required String message,
  Map<String, String>? data,
}) {
  // Spread data first so that 'error' and 'errorCode' cannot be overridden
  return <String, String>{...?data, 'error': message, 'errorCode': code};
}

Future<T> runWithTimeout<T>(
  Future<T> Function() operation, {
  Duration timeout = const Duration(seconds: 10),
}) {
  return operation().timeout(timeout);
}
