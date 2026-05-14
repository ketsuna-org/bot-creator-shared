import 'package:bot_creator_shared/actions/calculate.dart';

import '../../types/action.dart';

Future<bool> executeCalculateAction({
  required BotCreatorActionType type,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
}) async {
  if (type != BotCreatorActionType.calculate) {
    return false;
  }

  final calcResult = await calculateAction(
    payload: payload,
    resolve: resolveValue,
  );
  if (calcResult['error'] != null) {
    throw Exception(calcResult['error']);
  }

  final calcValue = calcResult['result'] ?? '';
  results[resultKey] = calcValue;
  variables['$resultKey.result'] = calcValue;
  return true;
}
