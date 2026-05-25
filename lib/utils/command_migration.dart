/// Transparent migration of legacy command `data.response` blocks into
/// equivalent inline actions (`respondWithMessage`, `respondWithComponentV2`,
/// `respondWithModal`, `ifBlock`).
///
/// This migration is applied at runtime by [BotDataStore.normalizeCommandData]
/// and never persists to stored data.


const _kResponseActionTypes = {
  'respondWithMessage',
  'respondWithComponentV2',
  'respondWithModal',
};

/// Threshold above which a `deferInteraction` action is automatically
/// prepended to absorb Discord's 3-second acknowledgement window.
const _kDeferThreshold = 2;

/// Migrates [data] (the `data` sub-map of a stored command) in-place.
///
/// Safe to call multiple times — idempotent via the `_migrated` sentinel.
void migrateCommandDataResponse(Map<String, dynamic> data) {
  final rawResponse = data['response'];
  if (rawResponse is! Map) return;

  final response = Map<String, dynamic>.from(
    rawResponse.cast<String, dynamic>(),
  );

  // Already migrated in this runtime cycle.
  if (response['_migrated'] == true) return;

  // If actions already contain an explicit respond action, do nothing.
  final rawActions = data['actions'];
  final existingActions =
      rawActions is List ? rawActions.whereType<Map>().toList() : const [];
  if (_hasExplicitResponseAction(existingActions)) return;

  // Check if the response block is actually non-trivial (has something to migrate).
  if (!_isLegacyResponseMigrable(response)) {
    // Mark as migrated to avoid re-checking on every execution.
    (data['response'] as Map)['_migrated'] = true;
    return;
  }

  final mutableActions = List<Map<String, dynamic>>.from(
    existingActions.map((e) => Map<String, dynamic>.from(e)),
  );

  // Build the injected respond action(s).
  final injectedActions = _buildRespondActions(response);

  // Determine whether a defer is needed.
  final totalAfterInjection = mutableActions.length + injectedActions.length;
  if (totalAfterInjection > _kDeferThreshold) {
    final isEphemeral = _resolveVisibility(response) == 'ephemeral';
    mutableActions.insert(0, _buildDeferAction(isEphemeral: isEphemeral));
  }

  mutableActions.addAll(injectedActions);
  data['actions'] = mutableActions;

  // Mark as migrated (in-memory sentinel, never persisted).
  (data['response'] as Map)['_migrated'] = true;
}

// ──────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ──────────────────────────────────────────────────────────────────────────────

bool _hasExplicitResponseAction(List existingActions) {
  for (final action in existingActions) {
    final type = (action['type'] ?? '').toString();
    if (_kResponseActionTypes.contains(type)) return true;
  }
  return false;
}

bool _isLegacyResponseMigrable(Map<String, dynamic> response) {
  final type = (response['type'] ?? 'normal').toString();
  final mode = (response['mode'] ?? 'message').toString();

  // A modal response must have a modal payload.
  if (mode == 'modal' || type == 'modal') {
    final modal = response['modal'];
    return modal is Map && modal.isNotEmpty;
  }

  // ComponentV2 must have components.
  if (type == 'componentV2' || mode == 'componentV2') {
    final comps = response['components'];
    return comps is Map && comps.isNotEmpty;
  }

  // Normal text/embed: has text or embeds.
  final text = (response['text'] ?? '').toString().trim();
  if (text.isNotEmpty) return true;
  final embeds = response['embeds'];
  if (embeds is List && embeds.isNotEmpty) return true;

  // Conditional: has the conditional block enabled.
  final workflow = response['workflow'];
  if (workflow is Map) {
    final conditional = workflow['conditional'];
    if (conditional is Map && conditional['enabled'] == true) return true;
  }

  return false;
}

List<Map<String, dynamic>> _buildRespondActions(Map<String, dynamic> response) {
  final workflow = response['workflow'];
  final conditional =
      (workflow is Map ? workflow['conditional'] : null) as Map? ?? const {};
  final conditionalEnabled = conditional['enabled'] == true;

  if (conditionalEnabled) {
    return [_buildConditionalIfBlock(response, conditional)];
  }

  return [_buildSingleRespondAction(response)];
}

Map<String, dynamic> _buildSingleRespondAction(
  Map<String, dynamic> response, {
  String? overrideText,
  List<dynamic>? overrideEmbeds,
  Map<String, dynamic>? overrideComponents,
  Map<String, dynamic>? overrideModal,
  bool? overrideEphemeral,
}) {
  final type = (response['type'] ?? 'normal').toString();
  final mode = (response['mode'] ?? 'message').toString();
  final isEphemeral =
      overrideEphemeral ?? (_resolveVisibility(response) == 'ephemeral');

  if (mode == 'modal' || type == 'modal') {
    final modal =
        overrideModal ??
        Map<String, dynamic>.from(
          (response['modal'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
    return {
      'type': 'respondWithModal',
      'enabled': true,
      'depend_on': <String>[],
      'error': {'mode': 'stop'},
      'payload': {'modal': modal},
    };
  }

  if (type == 'componentV2' || mode == 'componentV2') {
    final components =
        overrideComponents ??
        Map<String, dynamic>.from(
          (response['components'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
    return {
      'type': 'respondWithComponentV2',
      'enabled': true,
      'depend_on': <String>[],
      'error': {'mode': 'stop'},
      'payload': {'components': components, 'ephemeral': isEphemeral},
    };
  }

  // Normal message.
  final text = overrideText ?? (response['text'] ?? '').toString();
  final embeds =
      overrideEmbeds ??
      (response['embeds'] is List
          ? List<dynamic>.from(response['embeds'] as List)
          : const <dynamic>[]);
  final components =
      overrideComponents ??
      Map<String, dynamic>.from(
        (response['components'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  return {
    'type': 'respondWithMessage',
    'enabled': true,
    'depend_on': <String>[],
    'error': {'mode': 'stop'},
    'payload': {
      'content': text,
      if (embeds.isNotEmpty) 'embeds': embeds,
      if (components.isNotEmpty) 'components': components,
      'ephemeral': isEphemeral,
    },
  };
}

Map<String, dynamic> _buildConditionalIfBlock(
  Map<String, dynamic> response,
  Map conditional,
) {
  final variable = (conditional['variable'] ?? '').toString();

  // ── True branch ───────────────────────────────────────────────────────────
  final whenTrueType = (conditional['whenTrueType'] ?? 'message').toString();
  final whenTrueEphemeral = _resolveConditionalVisibility(
    response,
    conditional,
    branch: 'true',
    branchType: whenTrueType,
  );
  final trueAction = _buildSingleRespondAction(
    response,
    overrideText: (conditional['whenTrueText'] ?? '').toString(),
    overrideEmbeds: _castEmbedList(conditional['whenTrueEmbeds']),
    overrideComponents: _resolveConditionalComponents(
      conditional,
      branchType: whenTrueType,
      branch: 'true',
    ),
    overrideModal:
        (conditional['whenTrueModal'] as Map?)?.cast<String, dynamic>(),
    overrideEphemeral: whenTrueEphemeral,
  );

  // ── False branch ──────────────────────────────────────────────────────────
  final whenFalseType = (conditional['whenFalseType'] ?? 'message').toString();
  final whenFalseEphemeral = _resolveConditionalVisibility(
    response,
    conditional,
    branch: 'false',
    branchType: whenFalseType,
  );
  final falseAction = _buildSingleRespondAction(
    response,
    overrideText: (conditional['whenFalseText'] ?? '').toString(),
    overrideEmbeds: _castEmbedList(conditional['whenFalseEmbeds']),
    overrideComponents: _resolveConditionalComponents(
      conditional,
      branchType: whenFalseType,
      branch: 'false',
    ),
    overrideModal:
        (conditional['whenFalseModal'] as Map?)?.cast<String, dynamic>(),
    overrideEphemeral: whenFalseEphemeral,
  );

  return {
    'type': 'ifBlock',
    'enabled': true,
    'depend_on': <String>[],
    'error': {'mode': 'stop'},
    'payload': {
      'condition': variable,
      'actions': [trueAction],
      'elseActions': [falseAction],
    },
  };
}

Map<String, dynamic>? _resolveConditionalComponents(
  Map conditional, {
  required String branchType,
  required String branch,
}) {
  final isV2 = branchType == 'componentV2';
  final key =
      isV2
          ? 'when${branch == 'true' ? 'True' : 'False'}Components'
          : 'when${branch == 'true' ? 'True' : 'False'}NormalComponents';
  final raw = conditional[key];
  if (raw is! Map || raw.isEmpty) return null;
  return raw.cast<String, dynamic>();
}

bool _resolveConditionalVisibility(
  Map<String, dynamic> response,
  Map conditional, {
  required String branch,
  required String branchType,
}) {
  // Per-branch visibility is encoded in the branch type suffix (ephemeral vs normal).
  // The legacy system stored visibility in workflow.visibility — we fall back to it.
  // Since each branch can be independently ephemeral we check a branch-specific key
  // if present, otherwise we fall back to the global visibility.
  final branchKey = 'when${branch == 'true' ? 'True' : 'False'}Visibility';
  final branchVis = (conditional[branchKey] ?? '').toString().toLowerCase();
  if (branchVis == 'ephemeral') return true;
  if (branchVis == 'public') return false;
  // Fallback: use the global visibility from the workflow block.
  return _resolveVisibility(response) == 'ephemeral';
}

String _resolveVisibility(Map<String, dynamic> response) {
  final workflow = response['workflow'];
  if (workflow is Map) {
    return (workflow['visibility'] ?? 'public').toString().toLowerCase();
  }
  return 'public';
}

List<dynamic> _castEmbedList(dynamic raw) {
  if (raw is! List) return const [];
  return List<dynamic>.from(raw);
}

Map<String, dynamic> _buildDeferAction({required bool isEphemeral}) {
  return {
    'type': 'deferInteraction',
    'enabled': true,
    'depend_on': <String>[],
    'error': {'mode': 'stop'},
    'payload': {'ephemeral': isEphemeral},
  };
}
