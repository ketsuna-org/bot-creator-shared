import 'package:nyxx/nyxx.dart';

final _ackState = Expando<bool>();

/// Returns true when the interaction was already acknowledged or responded.
bool isInteractionAcknowledged(Interaction interaction) {
  if (_ackState[interaction] == true) {
    return true;
  }

  final dynInteraction = interaction as dynamic;

  try {
    if (dynInteraction.isAcknowledged == true) {
      return true;
    }
  } catch (_) {}

  try {
    if (dynInteraction.acknowledged == true) {
      return true;
    }
  } catch (_) {}

  try {
    if (dynInteraction.hasResponded == true) {
      return true;
    }
  } catch (_) {}

  return false;
}

/// Marks the interaction as acknowledged.
void markInteractionAcknowledged(Interaction interaction) {
  _ackState[interaction] = true;
}
