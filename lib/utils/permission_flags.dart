/// Discord permission flag definitions.
///
/// Each entry maps a human-readable key to its bit value.
/// The [PermissionFlag] class holds the key, bit position value,
/// and a category for grouping in the UI.
///
/// Usage in UI: render as tri-state toggles (Allow / Deny / Unset).
/// Usage in executor: compute allow/deny bitmasks from toggle states.

/// One Discord permission with metadata for UI rendering.
class PermissionFlag {
  const PermissionFlag({
    required this.key,
    required this.bitValue,
    required this.category,
    this.voiceOnly = false,
  });

  /// Normalized key matching Discord API convention (e.g. 'sendMessages').
  final String key;

  /// The integer bit value (e.g. 2048 for SEND_MESSAGES).
  final int bitValue;

  /// Category for grouping in the UI.
  final PermissionCategory category;

  /// Whether this permission only applies to voice channels.
  final bool voiceOnly;
}

/// Categories for grouping permission flags in the UI.
enum PermissionCategory {
  general,
  membership,
  text,
  voice,
  advanced,
}

/// All Discord permission flags in display order.
const List<PermissionFlag> discordPermissionFlags = <PermissionFlag>[
  // ── General ──
  PermissionFlag(
    key: 'createInstantInvite',
    bitValue: 0x1,
    category: PermissionCategory.general,
  ),
  PermissionFlag(
    key: 'manageChannels',
    bitValue: 0x10,
    category: PermissionCategory.general,
  ),
  PermissionFlag(
    key: 'manageGuild',
    bitValue: 0x20,
    category: PermissionCategory.general,
  ),
  PermissionFlag(
    key: 'manageRoles',
    bitValue: 0x10000000,
    category: PermissionCategory.general,
  ),
  PermissionFlag(
    key: 'manageWebhooks',
    bitValue: 0x20000000,
    category: PermissionCategory.general,
  ),
  PermissionFlag(
    key: 'manageGuildExpressions',
    bitValue: 0x40000000,
    category: PermissionCategory.general,
  ),
  PermissionFlag(
    key: 'viewAuditLog',
    bitValue: 0x80,
    category: PermissionCategory.general,
  ),
  PermissionFlag(
    key: 'viewGuildInsights',
    bitValue: 0x80000,
    category: PermissionCategory.general,
  ),
  PermissionFlag(
    key: 'manageEvents',
    bitValue: 0x200000000,
    category: PermissionCategory.general,
  ),

  // ── Membership ──
  PermissionFlag(
    key: 'administrator',
    bitValue: 0x8,
    category: PermissionCategory.membership,
  ),
  PermissionFlag(
    key: 'kickMembers',
    bitValue: 0x2,
    category: PermissionCategory.membership,
  ),
  PermissionFlag(
    key: 'banMembers',
    bitValue: 0x4,
    category: PermissionCategory.membership,
  ),
  PermissionFlag(
    key: 'moderateMembers',
    bitValue: 0x10000000000,
    category: PermissionCategory.membership,
  ),

  // ── Text ──
  PermissionFlag(
    key: 'viewChannel',
    bitValue: 0x400,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'sendMessages',
    bitValue: 0x800,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'sendMessagesInThreads',
    bitValue: 0x4000000000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'createPublicThreads',
    bitValue: 0x800000000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'createPrivateThreads',
    bitValue: 0x1000000000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'manageThreads',
    bitValue: 0x400000000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'manageMessages',
    bitValue: 0x2000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'embedLinks',
    bitValue: 0x4000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'attachFiles',
    bitValue: 0x8000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'readMessageHistory',
    bitValue: 0x10000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'addReactions',
    bitValue: 0x40,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'mentionEveryone',
    bitValue: 0x20000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'useExternalEmojis',
    bitValue: 0x40000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'useExternalStickers',
    bitValue: 0x2000000000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'sendTtsMessages',
    bitValue: 0x1000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'sendVoiceMessages',
    bitValue: 0x400000000000,
    category: PermissionCategory.text,
  ),
  PermissionFlag(
    key: 'useApplicationCommands',
    bitValue: 0x80000000,
    category: PermissionCategory.text,
  ),

  // ── Voice ──
  PermissionFlag(
    key: 'connect',
    bitValue: 0x100000,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),
  PermissionFlag(
    key: 'speak',
    bitValue: 0x200000,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),
  PermissionFlag(
    key: 'stream',
    bitValue: 0x200,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),
  PermissionFlag(
    key: 'useVoiceActivity',
    bitValue: 0x2000000,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),
  PermissionFlag(
    key: 'prioritySpeaker',
    bitValue: 0x100,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),
  PermissionFlag(
    key: 'muteMembers',
    bitValue: 0x400000,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),
  PermissionFlag(
    key: 'deafenMembers',
    bitValue: 0x800000,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),
  PermissionFlag(
    key: 'moveMembers',
    bitValue: 0x1000000,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),
  PermissionFlag(
    key: 'requestToSpeak',
    bitValue: 0x100000000,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),
  PermissionFlag(
    key: 'useSoundboard',
    bitValue: 0x40000000000,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),
  PermissionFlag(
    key: 'useExternalSounds',
    bitValue: 0x200000000000,
    category: PermissionCategory.voice,
    voiceOnly: true,
  ),

  // ── Advanced ──
  PermissionFlag(
    key: 'changeNickname',
    bitValue: 0x4000000,
    category: PermissionCategory.advanced,
  ),
  PermissionFlag(
    key: 'manageNicknames',
    bitValue: 0x8000000,
    category: PermissionCategory.advanced,
  ),
];

/// Compute the allow bitmask from a set of permission keys.
int computeAllowBitmask(Set<String> allowedKeys) {
  int bitmask = 0;
  for (final flag in discordPermissionFlags) {
    if (allowedKeys.contains(flag.key)) {
      bitmask |= flag.bitValue;
    }
  }
  return bitmask;
}

/// Compute the deny bitmask from a set of permission keys.
int computeDenyBitmask(Set<String> deniedKeys) {
  int bitmask = 0;
  for (final flag in discordPermissionFlags) {
    if (deniedKeys.contains(flag.key)) {
      bitmask |= flag.bitValue;
    }
  }
  return bitmask;
}

/// Decompose allow/deny bitmasks into a map of permission key → state.
///
/// States: 'allow', 'deny', or 'unset'.
Map<String, String> decomposePermissionBitmasks(int allow, int deny) {
  final result = <String, String>{};
  for (final flag in discordPermissionFlags) {
    if ((allow & flag.bitValue) != 0) {
      result[flag.key] = 'allow';
    } else if ((deny & flag.bitValue) != 0) {
      result[flag.key] = 'deny';
    } else {
      result[flag.key] = 'unset';
    }
  }
  return result;
}

/// Normalize a BDFD permission token to the canonical key used by [PermissionFlag].
///
/// Handles common BDFD aliases and returns null if unrecognized.
String? normalizeBdfdPermissionToken(String raw) {
  final normalized = raw.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]'),
    '',
  );
  if (normalized.isEmpty) return null;

  // Direct match first
  for (final flag in discordPermissionFlags) {
    if (flag.key.toLowerCase() == normalized) return flag.key;
  }

  // Known BDFD aliases (from _permissionTokenAliases in models.dart)
  const aliases = <String, String>{
    'admin': 'administrator',
    'ban': 'banMembers',
    'kick': 'kickMembers',
    'changenicknames': 'changeNickname',
    'externalemojis': 'useExternalEmojis',
    'externalstickers': 'useExternalStickers',
    'manageemojis': 'manageGuildExpressions',
    'manageserver': 'manageGuild',
    'readmessages': 'viewChannel',
    'slashcommands': 'useApplicationCommands',
    'tts': 'sendTtsMessages',
    'usevad': 'useVoiceActivity',
    'voicedeafen': 'deafenMembers',
    'voicemute': 'muteMembers',
  };

  final aliased = aliases[normalized];
  if (aliased != null) return aliased;

  return null;
}

/// Convert a list of BDFD permission tokens to a map of canonical key → 'allow'.
///
/// This bridges BDFD imports (which produce a list of allowed permissions)
/// to the new [permissionFlags] format (Map<String, String> with states).
/// Unrecognized tokens are silently dropped.
Map<String, String> bdfdPermissionListToStates(List<String> tokens) {
  final result = <String, String>{};
  for (final token in tokens) {
    final canonical = normalizeBdfdPermissionToken(token);
    if (canonical != null) {
      result[canonical] = 'allow';
    }
  }
  return result;
}
