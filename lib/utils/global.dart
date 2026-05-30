import 'dart:io';

import 'package:nyxx/nyxx.dart';

import 'command_autocomplete.dart';

const String discordUrl = "https://discord.com/api/v10";

final Map<String, DateTime> botStartTimes = {};

Snowflake? _asSnowflake(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Snowflake) {
    return value;
  }
  if (value is int) {
    return Snowflake(value);
  }
  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<int> getGuildMemberCount(
  dynamic guild, {
  dynamic client,
  Snowflake? guildId,
}) async {
  if (guild == null) return 0;
  try {
    final dynamic dynGuild = guild;
    // memberCount is standard for bots, approximateMemberCount is for with_counts=true
    final count = dynGuild.memberCount ?? dynGuild.approximateMemberCount;
    if (count != null && count > 0) return count;
  } catch (_) {}

  // Try cache if client is provided
  if (client is NyxxRest && guildId != null) {
    try {
      final cached = await client.guilds.get(guildId);
      final dynamic dynCached = cached;
      final count = dynCached.memberCount ?? dynCached.approximateMemberCount;
      if (count != null && count > 0) return count;
    } catch (_) {}
  }

  return 0;
}

Future<User?> _fetchUserCached(dynamic client, Snowflake userId) async {
  try {
    return await client.users.get(userId);
  } catch (_) {
    return null;
  }
}

Future<Member?> _fetchMemberCached(
  Interaction interaction, {
  required Snowflake guildId,
  required Snowflake userId,
}) async {
  try {
    final guild = await fetchGuildCached(interaction.manager.client, guildId);
    if (guild == null) return null;
    return await guild.members.get(userId);
  } catch (_) {
    return null;
  }
}

Future<Guild?> fetchGuildCached(dynamic client, Snowflake guildId) async {
  try {
    // Try cache first
    final cached = await client.guilds.get(guildId);

    // Only return cached if it's a full Guild object
    if (cached is Guild) {
      return cached;
    }

    // Fallback to fetch if not in cache or partial
    return await client.guilds.fetch(guildId);
  } catch (_) {
    return null;
  }
}

Map<String, String> extractBotRuntimeDetails(NyxxRest client) {
  final botUserId = client.user.id;
  final guildCache = client.guilds.cache;

  final details = <String, String>{
    'bot.id': botUserId.toString(),
    'bot.guildCount': guildCache.length.toString(),
    'bot.guildNames': guildCache.values.map((g) => g.name).join(', '),
    'bot.invite':
        'https://discord.com/oauth2/authorize?client_id=$botUserId&scope=bot+applications.commands',
  };

  // Inject ping/latency if we have a gateway client
  if (client is NyxxGateway) {
    try {
      final latencyMs = client.gateway.latency.inMilliseconds;
      final ping = latencyMs < 0 ? '0' : latencyMs.toString();
      details['bot.ping'] = ping;
      details['ping'] = ping;
    } catch (_) {
      details['bot.ping'] = '0';
      details['ping'] = '0';
    }

    final startedAt = botStartTimes[botUserId.toString()];
    if (startedAt != null) {
      final uptimeMs = DateTime.now().difference(startedAt).inMilliseconds;
      details['bot.uptime'] = uptimeMs.toString();
      details['bot.uptimeMs'] = uptimeMs.toString();
    } else {
      details['bot.uptime'] = '0';
      details['bot.uptimeMs'] = '0';
    }

    // Shard info — single-shard bots always use shard 0
    details['bot.shardId'] = '0';
  } else {
    // Fallback so expressions don't break
    details['bot.ping'] = '0';
    details['ping'] = '0';
    details['bot.shardId'] = '0';
    final startedAt = botStartTimes[botUserId.toString()];
    if (startedAt != null) {
      final uptimeMs = DateTime.now().difference(startedAt).inMilliseconds;
      details['bot.uptime'] = uptimeMs.toString();
      details['bot.uptimeMs'] = uptimeMs.toString();
    } else {
      details['bot.uptime'] = '0';
      details['bot.uptimeMs'] = '0';
    }
  }

  // Node version — report the Dart SDK version for parity with BDFD's $nodeVersion.
  // On iOS/Android, Platform.version returns the OS version, not the Dart version.
  // We extract the Dart version from the VM string which always starts with the version.
  try {
    final platformVersion = Platform.version;
    // Platform.version e.g. "3.7.2 (stable) on ..." — extract just the version number
    final dartVersion = platformVersion.split(' ').first;
    details['bot.nodeVersion'] = 'Dart $dartVersion';
  } catch (_) {
    details['bot.nodeVersion'] = 'Dart';
  }

  try {
    final cachedUser = client.users.cache[botUserId];
    if (cachedUser != null) {
      details['bot.username'] = cachedUser.username;
    }
  } catch (_) {}

  return details;
}

Map<String, String> extractMemberRuntimeDetails({
  required dynamic member,
  required dynamic guild,
  required String guildId,
}) {
  if (member == null || guild == null || guildId.trim().isEmpty) {
    return const <String, String>{};
  }

  final roleIds = <String>{};
  try {
    final dynamic roleIdsRaw = member.roleIds;
    if (roleIdsRaw is Iterable) {
      for (final roleId in roleIdsRaw) {
        final asSnowflake = _asSnowflake(roleId);
        final value = (asSnowflake ?? roleId).toString().trim();
        if (value.isNotEmpty) {
          roleIds.add(value);
        }
      }
    }
  } catch (_) {
    return const <String, String>{};
  }

  var mask = 0;

  // If the member carries Discord-computed permissions (e.g. from an
  // interaction payload), use them as the baseline. This covers the guild
  // owner implicit-all-permissions and the administrator role override that
  // Discord applies server-side.
  try {
    final dynamic memberPerms = member.permissions;
    if (memberPerms is Permissions) {
      mask |= memberPerms.value;
    } else if (memberPerms != null) {
      final parsed = int.tryParse(memberPerms.toString());
      if (parsed != null) {
        mask |= parsed;
      }
    }
  } catch (_) {
    // member.permissions is unavailable (e.g. fetched member, not from
    // interaction payload). Continue with role-based computation.
  }

  try {
    final dynamic roleListRaw = guild.roleList;
    if (roleListRaw is Iterable) {
      for (final role in roleListRaw) {
        final roleIdValue =
            (_asSnowflake((role as dynamic).id) ?? role.id).toString().trim();
        if (!roleIds.contains(roleIdValue) && roleIdValue != guildId.trim()) {
          continue;
        }

        final dynamic permsRaw = role.permissions;
        final int permValue;
        if (permsRaw is Permissions) {
          permValue = permsRaw.value;
        } else {
          permValue = int.tryParse(permsRaw.value.toString()) ?? 0;
        }
        mask |= permValue;
      }
    }
  } catch (_) {
    // If role-based computation fails but we already have member.permissions,
    // continue with what we have instead of returning empty.
    if (mask == 0) {
      return const <String, String>{};
    }
  }

  // Guild owners implicitly have all permissions in Discord.
  try {
    final memberIdStr =
        (_asSnowflake(member.id) ?? member.id).toString().trim();
    final ownerIdStr =
        (_asSnowflake(guild.ownerId) ?? guild.ownerId).toString().trim();
    if (memberIdStr.isNotEmpty && memberIdStr == ownerIdStr) {
      for (final entry in _permissionTokenFlags) {
        mask |= entry.key.value;
      }
    }
  } catch (_) {}

  final permissions = Permissions(mask);
  final tokens = _permissionTokensFromPermissions(permissions);
  final details = <String, String>{
    'member.isAdmin': permissions.isAdministrator ? 'true' : 'false',
    'member.permissions': tokens.join(','),
    'interaction.member.isAdmin':
        permissions.isAdministrator ? 'true' : 'false',
    'interaction.member.permissions': tokens.join(','),
    'member.roles': roleIds.join(','),
  };

  // Extra member fields that may not be available on every PartialMember.
  try {
    final dynamic joinedAt = member.joinedAt;
    if (joinedAt is DateTime) {
      details['member.joinedAt'] = joinedAt.toIso8601String();
    }
  } catch (_) {}

  try {
    final dynamic premiumSince = member.premiumSince;
    details['member.isBooster'] = (premiumSince != null).toString();
    if (premiumSince is DateTime) {
      details['member.premiumSince'] = premiumSince.toIso8601String();
    }
  } catch (_) {}

  try {
    final dynamic communicationDisabledUntil =
        member.communicationDisabledUntil;
    if (communicationDisabledUntil is DateTime) {
      details['member.communicationDisabledUntil'] =
          communicationDisabledUntil.toIso8601String();
    }
  } catch (_) {}

  return details;
}

List<String> _permissionTokensFromPermissions(Permissions permissions) {
  final tokens = <String>[];
  final isAdmin = permissions.has(Permissions.administrator);
  for (final entry in _permissionTokenFlags) {
    if (isAdmin || permissions.has(entry.key)) {
      tokens.add(entry.value);
    }
  }
  return tokens;
}

Map<String, String> extractPermissionsByIdRuntimeDetails({
  required String userId,
  required Map<String, String> memberDetails,
}) {
  final trimmedUserId = userId.trim();
  if (trimmedUserId.isEmpty) {
    return const <String, String>{};
  }

  final permissions = (memberDetails['member.permissions'] ?? '').trim();
  final isAdmin = (memberDetails['member.isAdmin'] ?? 'false').trim();
  return <String, String>{
    'permissions.byId.$trimmedUserId': permissions,
    'isAdmin.byId.$trimmedUserId': isAdmin,
  };
}

final List<MapEntry<Flag<Permissions>, String>> _permissionTokenFlags =
    <MapEntry<Flag<Permissions>, String>>[
      MapEntry(Permissions.addReactions, 'addreactions'),
      MapEntry(Permissions.administrator, 'administrator'),
      MapEntry(Permissions.attachFiles, 'attachfiles'),
      MapEntry(Permissions.banMembers, 'banmembers'),
      MapEntry(Permissions.changeNickname, 'changenickname'),
      MapEntry(Permissions.connect, 'connect'),
      MapEntry(Permissions.createInstantInvite, 'createinstantinvite'),
      MapEntry(Permissions.createPrivateThreads, 'createprivatethreads'),
      MapEntry(Permissions.createPublicThreads, 'createpublicthreads'),
      MapEntry(Permissions.deafenMembers, 'deafenmembers'),
      MapEntry(Permissions.embedLinks, 'embedlinks'),
      MapEntry(Permissions.kickMembers, 'kickmembers'),
      MapEntry(Permissions.manageChannels, 'managechannels'),
      MapEntry(Permissions.manageEvents, 'manageevents'),
      MapEntry(Permissions.manageGuild, 'manageguild'),
      MapEntry(Permissions.manageGuildExpressions, 'manageguildexpressions'),
      MapEntry(Permissions.manageMessages, 'managemessages'),
      MapEntry(Permissions.manageNicknames, 'managenicknames'),
      MapEntry(Permissions.manageRoles, 'manageroles'),
      MapEntry(Permissions.manageThreads, 'managethreads'),
      MapEntry(Permissions.manageWebhooks, 'managewebhooks'),
      MapEntry(Permissions.mentionEveryone, 'mentioneveryone'),
      MapEntry(Permissions.moderateMembers, 'moderatemembers'),
      MapEntry(Permissions.moveMembers, 'movemembers'),
      MapEntry(Permissions.muteMembers, 'mutemembers'),
      MapEntry(Permissions.prioritySpeaker, 'priorityspeaker'),
      MapEntry(Permissions.readMessageHistory, 'readmessagehistory'),
      MapEntry(Permissions.requestToSpeak, 'requesttospeak'),
      MapEntry(Permissions.sendMessages, 'sendmessages'),
      MapEntry(Permissions.sendMessagesInThreads, 'sendmessagesinthreads'),
      MapEntry(Permissions.sendTtsMessages, 'sendttsmessages'),
      MapEntry(Permissions.sendVoiceMessages, 'sendvoicemessages'),
      MapEntry(Permissions.speak, 'speak'),
      MapEntry(Permissions.stream, 'stream'),
      MapEntry(Permissions.useApplicationCommands, 'useapplicationcommands'),
      MapEntry(Permissions.useExternalEmojis, 'useexternalemojis'),
      MapEntry(Permissions.useExternalStickers, 'useexternalstickers'),
      MapEntry(Permissions.useSoundboard, 'usesoundboard'),
      MapEntry(Permissions.viewAuditLog, 'viewauditlog'),
      MapEntry(Permissions.viewChannel, 'viewchannel'),
      MapEntry(Permissions.viewGuildInsights, 'viewguildinsights'),
    ];

Future<Channel?> fetchChannelCached(dynamic client, Snowflake channelId) async {
  try {
    return await client.channels.get(channelId);
  } catch (_) {
    return null;
  }
}

Future<User> getDiscordUser(String botToken) async {
  try {
    final client = await Nyxx.connectRest(botToken);
    return await client.user.fetch();
  } catch (e) {
    throw Exception("Failed to fetch user: $e");
  }
}

String makeAvatarUrl(
  String userId, {
  String? avatarId,
  bool isAnimated = false,
  String legacyFormat = "webp",
  String? discriminator,
}) {
  if (avatarId == null || avatarId.isEmpty || avatarId == "0") {
    if (discriminator != null &&
        discriminator != "0" &&
        discriminator != "0000") {
      return "https://cdn.discordapp.com/embed/avatars/${int.parse(discriminator) % 5}.png";
    }
    // New default avatar logic for migrated accounts or missing discriminator
    return "https://cdn.discordapp.com/embed/avatars/${(BigInt.parse(userId) >> 22).toInt() % 6}.png";
  }
  return "https://cdn.discordapp.com/avatars/$userId/$avatarId.$legacyFormat?size=1024";
}

String makeBannerUrl(
  String userId, {
  String? bannerId,
  bool isAnimated = false,
  String legacyFormat = "webp",
}) {
  if (bannerId == null || bannerId.isEmpty || bannerId == '0') {
    return '';
  }

  if (isAnimated && legacyFormat == 'gif') {
    return "https://cdn.discordapp.com/banners/$userId/$bannerId.gif?size=1024";
  }

  return "https://cdn.discordapp.com/banners/$userId/$bannerId.$legacyFormat?size=1024";
}

String makeGuildIcon(String guildId, String? iconId) {
  if (guildId == "DM" || iconId == null || iconId.isEmpty) {
    return "https://cdn.discordapp.com/embed/avatars/0.png";
  }
  return "https://cdn.discordapp.com/icons/$guildId/$iconId.webp?size=1024";
}

Map<String, String> extractChannelRuntimeDetails(dynamic channel) {
  if (channel == null) {
    return const <String, String>{};
  }

  final details = <String, String>{
    'channel.kind': channel.runtimeType.toString(),
  };

  void trySet(String key, Object? Function() accessor) {
    try {
      final value = accessor();
      final str = (value ?? '').toString();
      if (str.isNotEmpty) {
        details[key] = str;
      }
    } catch (_) {
      // Property not available on this channel type — skip.
    }
  }

  trySet('channel.id', () => _asSnowflake(channel.id));
  trySet('channel.topic', () => channel.topic);
  trySet('channel.parentId', () => _asSnowflake(channel.parentId));
  trySet('channel.position', () => channel.position);
  trySet('channel.nsfw', () => ((channel.isNsfw ?? false) == true).toString());
  trySet('channel.slowmode', () => channel.rateLimitPerUser);
  trySet('channel.bitrate', () => channel.bitrate);
  trySet('channel.userLimit', () => channel.userLimit);
  trySet('channel.categoryId', () => _asSnowflake(channel.parentId));
  trySet(
    'channel.thread.archived',
    () => ((channel.isArchived ?? false) == true).toString(),
  );
  trySet(
    'channel.thread.locked',
    () => ((channel.isLocked ?? false) == true).toString(),
  );
  trySet('channel.thread.ownerId', () => _asSnowflake(channel.ownerId));
  trySet(
    'channel.thread.autoArchiveDuration',
    () => channel.autoArchiveDuration,
  );
  trySet(
    'channel.mention',
    () => channel is PartialChannel ? '<#${channel.id}>' : null,
  );
  trySet(
    'channel.typeValue',
    () => (channel as dynamic).type?.value?.toString(),
  );

  return details;
}

Future<Map<String, String>> extractGuildRuntimeDetails(
  dynamic guild, {
  dynamic client,
  Snowflake? guildId,
}) async {
  if (guild == null) {
    return const <String, String>{};
  }

  final details = <String, String>{'guild.kind': guild.runtimeType.toString()};

  void trySet(String key, Object? Function() accessor) {
    try {
      final value = accessor();
      final str = (value ?? '').toString();
      if (str.isNotEmpty) {
        details[key] = str;
      }
    } catch (_) {
      // Property not available on this guild type — skip.
    }
  }

  List<String> featureList = const <String>[];
  try {
    final featuresRaw = guild.features;
    if (featuresRaw is Iterable) {
      featureList = featuresRaw
          .map((value) => value.toString())
          .toList(growable: false);
    }
  } catch (_) {}

  trySet('guild.id', () => _asSnowflake(guild.id));
  trySet('guild.ownerId', () => _asSnowflake(guild.ownerId));
  trySet('guild.description', () => guild.description);
  trySet('guild.vanityUrlCode', () => guild.vanityUrlCode);
  trySet('guild.preferredLocale', () => guild.preferredLocale);
  trySet('guild.verificationLevel', () => guild.verificationLevel);
  trySet('guild.mfaLevel', () => guild.mfaLevel);
  trySet('guild.nsfwLevel', () => guild.nsfwLevel);
  trySet('guild.premiumTier', () => guild.premiumTier);
  trySet(
    'guild.premiumSubscriptionCount',
    () => guild.premiumSubscriptionCount,
  );
  details['guild.features'] = featureList.join(',');
  details['guild.features.count'] = featureList.length.toString();

  final count = await getGuildMemberCount(
    guild,
    client: client,
    guildId: guildId,
  );
  details['guild.memberCount'] = count.toString();
  details['guild.count'] = count.toString();

  trySet('guild.systemChannelId', () => _asSnowflake(guild.systemChannelId));
  trySet('guild.rulesChannelId', () => _asSnowflake(guild.rulesChannelId));
  trySet('guild.afkChannelId', () => _asSnowflake(guild.afkChannelId));
  trySet('guild.banner', () => guild.banner?.url);
  trySet('guild.splash', () => guild.splash?.url);
  trySet('guild.afkTimeout', () => guild.afkTimeout?.inSeconds);
  trySet('guild.icon', () => guild.icon?.url?.toString());

  trySet('guild.roleCount', () {
    final dynamic dynGuild = guild;
    final roleList = dynGuild.roleList ?? dynGuild.roles;
    return roleList is Iterable ? roleList.length : null;
  });
  trySet('guild.roleNames', () {
    final dynamic dynGuild = guild;
    final roleList = dynGuild.roleList ?? dynGuild.roles;
    if (roleList is Iterable) {
      return roleList
          .map((role) => (role as dynamic).name.toString())
          .join(',');
    }
    return null;
  });
  trySet('guild.stickerCount', () {
    final stickerList = guild.stickerList;
    return stickerList is Iterable ? stickerList.length : null;
  });
  trySet('guild.emojiCount', () {
    final emojiList = guild.emojiList;
    return emojiList is Iterable ? emojiList.length : null;
  });

  details.removeWhere((key, value) => value.isEmpty);
  return details;
}

Future<Map<String, String>> generateKeyValues(
  Interaction<ApplicationCommandInteractionData> interaction,
) async {
  final client = interaction.manager.client;
  final guildId =
      _asSnowflake((interaction as dynamic).guildId) ?? interaction.guild?.id;
  final channelId =
      _asSnowflake((interaction as dynamic).channelId) ??
      interaction.channel?.id;
  final invokingUserId =
      _asSnowflake(interaction.user?.id) ??
      _asSnowflake(interaction.member?.id);

  // Parallelize data fetching
  final results = await Future.wait([
    if (guildId != null)
      fetchGuildCached(client, guildId)
    else
      Future.value(null),
    if (channelId != null)
      fetchChannelCached(client, channelId)
    else
      Future.value(null),
    if (guildId != null && invokingUserId != null)
      _fetchMemberCached(interaction, guildId: guildId, userId: invokingUserId)
    else
      Future.value(null),
  ]);

  Guild? guild = results[0] as Guild?;
  Channel? channel = results[1] as Channel?;
  Member? user = results[2] as Member?;

  // Fallback to interaction data if fetch failed
  if (user == null && interaction.member != null) {
    user = interaction.member;
  }

  final invokingUserIdText = invokingUserId?.toString() ?? '';
  final guildIdText = guildId?.toString() ?? '';
  final channelIdText = channelId?.toString() ?? '';
  final guildName = guild?.name ?? (guildId != null ? "Unknown Guild" : "DM");
  final userName =
      user?.user?.username ?? interaction.user?.username ?? "Unknown User";

  final count = await getGuildMemberCount(
    guild ?? interaction.guild,
    client: client,
    guildId: guildId,
  );

  String channelName = getChannelName(channel ?? interaction.channel);
  String channelType = "0";
  try {
    if (channel != null) {
      channelType = (channel as dynamic).type.value.toString();
    } else if (interaction.channel != null) {
      channelType = (interaction.channel as dynamic).type.value.toString();
    }
  } catch (_) {}
  String channelMention =
      (channel ?? interaction.channel) != null
          ? "<#${(channel ?? interaction.channel)!.id}>"
          : "";

  String userAvatarUrl = "https://cdn.discordapp.com/embed/avatars/0.png";
  String userBannerUrl = '';
  String memberAvatarUrl = userAvatarUrl;

  if (user != null) {
    if (user.user != null) {
      final userFinal = user.user!;
      userAvatarUrl = makeAvatarUrl(
        userFinal.id.toString(),
        avatarId: userFinal.avatar.hash,
        isAnimated: userFinal.avatar.isAnimated,
        legacyFormat: "webp",
        discriminator: userFinal.discriminator,
      );

      try {
        final dynamic dynamicUser = userFinal;
        final dynamic userBanner = dynamicUser.banner;
        userBannerUrl = makeBannerUrl(
          userFinal.id.toString(),
          bannerId: userBanner?.hash?.toString(),
          isAnimated: userBanner?.isAnimated == true,
          legacyFormat: "webp",
        );
      } catch (_) {}
    }

    try {
      final dynamic dynamicMember = user;
      final dynamic memberAvatar = dynamicMember.avatar;
      final memberAvatarHash = memberAvatar?.hash?.toString() ?? '';
      if (memberAvatarHash.isNotEmpty && user.user != null) {
        final userFinal = user.user!;
        memberAvatarUrl = makeAvatarUrl(
          userFinal.id.toString(),
          avatarId: memberAvatarHash,
          isAnimated: memberAvatar?.isAnimated == true,
          legacyFormat: "webp",
          discriminator: userFinal.discriminator,
        );
      }
    } catch (_) {}
  }

  Map<String, String> listOfArgs = {
    "userName": userName,
    "userId": invokingUserIdText,
    "userUsername": user?.user?.username ?? "Unknown User",
    "userTag": user?.user?.discriminator ?? "Unknown User",
    "userAvatar": userAvatarUrl,
    "userBanner": userBannerUrl,
    "user.id": invokingUserIdText,
    "user.username": user?.user?.username ?? "Unknown User",
    "user.tag": user?.user?.discriminator ?? "Unknown User",
    "user.avatar": userAvatarUrl,
    "user.banner": userBannerUrl,
    "member.id": invokingUserIdText,
    "member.nick": user?.nick ?? '',
    "member.avatar": memberAvatarUrl,
    "member.displayName":
        user?.nick ?? user?.user?.globalName ?? user?.user?.username ?? '',
    "displayName":
        user?.nick ?? user?.user?.globalName ?? user?.user?.username ?? '',
    "interaction.member.id": invokingUserIdText,
    "interaction.member.nick": user?.nick ?? '',
    "interaction.member.avatar": memberAvatarUrl,
    "interaction.member.displayName":
        user?.nick ?? user?.user?.globalName ?? user?.user?.username ?? '',
    "author.id": invokingUserIdText,
    "author.username": user?.user?.username ?? "Unknown User",
    "author.tag": user?.user?.discriminator ?? "Unknown User",
    "author.avatar": userAvatarUrl,
    "author.banner": userBannerUrl,
    "author.displayName":
        user?.nick ?? user?.user?.globalName ?? user?.user?.username ?? '',
    "interaction.user.id": invokingUserIdText,
    "interaction.user.username": user?.user?.username ?? "Unknown User",
    "interaction.user.tag": user?.user?.discriminator ?? "Unknown User",
    "interaction.user.avatar": userAvatarUrl,
    "interaction.user.banner": userBannerUrl,
    "interaction.user.displayName":
        user?.user?.globalName ?? user?.user?.username ?? '',
    "guildName": guildName,
    "guild.name": guildName,
    "channelName": channelName,
    "channel.name": channelName,
    "channelType": channelType,
    "channel.type": channelType,
    "channel.mention": channelMention,
    "guildIcon": makeGuildIcon(
      guild?.id.toString() ?? "DM",
      (guild is Guild) ? guild.icon?.hash : null,
    ),
    "guildId": guildIdText,
    "guild.id": guildIdText,
    "channelId": channelIdText,
    "channel.id": channelIdText,
    "guildCount": count.toString(),
    "guild.count": count.toString(),
    "interaction.guild.id": guildIdText,
    "interaction.guild.name": guildName,
    "interaction.guild.icon": makeGuildIcon(
      guild?.id.toString() ?? "DM",
      (guild is Guild) ? guild.icon?.hash : null,
    ),
    "interaction.channel.id": channelIdText,
    "interaction.channel.name": channelName,
    "interaction.channel.type": channelType,
    "interaction.channel.mention": channelMention,
    "user.mention": user?.user != null ? "<@${user!.user!.id}>" : "",
    "author.mention": user?.user != null ? "<@${user!.user!.id}>" : "",
    "member.mention": user != null ? "<@${user.id}>" : "",
  };
  listOfArgs.addAll(extractChannelRuntimeDetails(channel));
  listOfArgs.addAll(
    await extractGuildRuntimeDetails(
      guild,
      client: interaction.manager.client,
      guildId: guildId,
    ),
  );
  final invokingMemberDetails = extractMemberRuntimeDetails(
    member: user,
    guild: guild,
    guildId: guildIdText,
  );
  listOfArgs.addAll(invokingMemberDetails);
  listOfArgs.addAll(
    extractPermissionsByIdRuntimeDetails(
      userId: invokingUserIdText,
      memberDetails: invokingMemberDetails,
    ),
  );
  listOfArgs.addAll(extractBotRuntimeDetails(interaction.manager.client));
  final command = interaction.data;
  listOfArgs["commandName"] = command.name;
  listOfArgs["commandId"] = command.id.toString();
  final commandType = command.type;
  final commandTypeName =
      commandType == ApplicationCommandType.user
          ? 'user'
          : commandType == ApplicationCommandType.message
          ? 'message'
          : 'chatInput';
  listOfArgs["commandType"] = commandTypeName;
  listOfArgs["commandTypeValue"] = commandType.value.toString();
  listOfArgs["command.type"] = commandTypeName;
  listOfArgs["interaction.command.type"] = commandTypeName;

  final targetId = command.targetId;
  if (targetId != null) {
    listOfArgs["target.id"] = targetId.toString();
    listOfArgs["interaction.target.id"] = targetId.toString();
  }

  if (commandType == ApplicationCommandType.user && targetId != null) {
    final resolvedUser = command.resolved?.users?[targetId];
    User? targetUser = resolvedUser;
    targetUser ??= await _fetchUserCached(interaction.manager.client, targetId);
    if (targetUser != null) {
      String targetBannerUrl = '';
      final dynamic dynamicTargetUser = targetUser;
      final dynamic targetBanner = dynamicTargetUser.banner;
      targetBannerUrl = makeBannerUrl(
        targetUser.id.toString(),
        bannerId: targetBanner?.hash?.toString(),
        isAnimated: targetBanner?.isAnimated == true,
        legacyFormat: "webp",
      );

      listOfArgs["target.user.id"] = targetUser.id.toString();
      listOfArgs["target.user.username"] = targetUser.username;
      listOfArgs["target.user.tag"] = targetUser.discriminator;
      listOfArgs["target.user.avatar"] = makeAvatarUrl(
        targetUser.id.toString(),
        avatarId: targetUser.avatar.hash,
        isAnimated: targetUser.avatar.isAnimated,
        legacyFormat: "webp",
        discriminator: targetUser.discriminator,
      );
      listOfArgs["target.user.banner"] = targetBannerUrl;
      listOfArgs["target.userName"] = targetUser.username;
      listOfArgs["target.userAvatar"] = listOfArgs["target.user.avatar"] ?? '';
    }

    Member? resolvedMember = command.resolved?.members?[targetId];
    if (resolvedMember == null) {
      final resolvedGuildId =
          _asSnowflake((interaction as dynamic).guildId) ??
          interaction.guild?.id;
      if (resolvedGuildId != null) {
        resolvedMember = await _fetchMemberCached(
          interaction,
          guildId: resolvedGuildId,
          userId: targetId,
        );
      }
    }
    if (resolvedMember != null) {
      listOfArgs["target.member.id"] = resolvedMember.id.toString();
      listOfArgs["target.member.nick"] = resolvedMember.nick ?? '';
    }
  }

  if (commandType == ApplicationCommandType.message && targetId != null) {
    final resolvedMessage = command.resolved?.messages?[targetId];
    if (resolvedMessage != null) {
      listOfArgs["target.message.id"] = resolvedMessage.id.toString();
      listOfArgs["target.message.channelId"] =
          resolvedMessage.channelId.toString();
      listOfArgs["target.messageId"] = resolvedMessage.id.toString();

      if (resolvedMessage is Message) {
        listOfArgs["target.message.content"] = resolvedMessage.content;
        listOfArgs["target.message.author.id"] =
            resolvedMessage.author.id.toString();
        listOfArgs["target.messageContent"] = resolvedMessage.content;
      }
    }
  }

  if (interaction.data.options is List<InteractionOption>) {
    final options = interaction.data.options as List<InteractionOption>;
    for (final option in options) {
      if (option.type == CommandOptionType.subCommand) {
        listOfArgs[option.name] = option.value.toString();
        final subOptions = option.options as List<InteractionOption>;
        for (final subOption in subOptions) {
          final subKeyValues = await generateKeyValuesFromInteractionOption(
            subOption,
            interaction,
          );
          // let's prefix them with opts to avoid conflicts
          // with other keys
          for (final entry in subKeyValues.entries) {
            listOfArgs["opts.${entry.key}"] = entry.value;
            listOfArgs["arg.${entry.key}"] = entry.value;
            listOfArgs["workflow.arg.${entry.key}"] = entry.value;
          }
        }
      } else if (option.type == CommandOptionType.subCommandGroup) {
        listOfArgs[option.name] = option.value.toString();
        final subCommandsOptions = option.options as List<InteractionOption>;
        for (final subCommandOption in subCommandsOptions) {
          final subOptions =
              subCommandOption.options as List<InteractionOption>;
          for (final subOption in subOptions) {
            final subKeyValues = await generateKeyValuesFromInteractionOption(
              subOption,
              interaction,
            );
            // let's prefix them with opts to avoid conflicts
            // with other keys
            for (final entry in subKeyValues.entries) {
              listOfArgs["opts.${entry.key}"] = entry.value;
              listOfArgs["arg.${entry.key}"] = entry.value;
              listOfArgs["workflow.arg.${entry.key}"] = entry.value;
            }
          }
        }
      } else {
        final keyValues = await generateKeyValuesFromInteractionOption(
          option,
          interaction,
        );
        // let's prefix them with opts to avoid conflicts
        // with other keys
        for (final entry in keyValues.entries) {
          listOfArgs["opts.${entry.key}"] = entry.value;
          listOfArgs["arg.${entry.key}"] = entry.value;
          listOfArgs["workflow.arg.${entry.key}"] = entry.value;
        }
      }
    }
  }
  return listOfArgs;
}

Future<Map<String, String>> generateKeyValuesFromInteractionOption(
  InteractionOption value,
  Interaction<ApplicationCommandInteractionData> interaction,
) async {
  final client = interaction.manager.client;
  switch (value.type) {
    case CommandOptionType.string:
      return {value.name: value.value.toString()};
    case CommandOptionType.integer:
      return {value.name: value.value.toString()};
    case CommandOptionType.boolean:
      return {value.name: value.value.toString()};
    case CommandOptionType.user:
      final userId = Snowflake(int.parse(value.value.toString()));
      final user = await _fetchUserCached(client, userId);
      final optionResult = <String, String>{
        value.name: user?.username ?? value.value.toString(),
        "${value.name}.id": userId.toString(),
      };

      final resolvedGuildId =
          _asSnowflake((interaction as dynamic).guildId) ??
          interaction.guild?.id;
      if (resolvedGuildId != null) {
        final guild = await fetchGuildCached(
          interaction.manager.client,
          resolvedGuildId,
        );
        final member = await _fetchMemberCached(
          interaction,
          guildId: resolvedGuildId,
          userId: userId,
        );
        if (guild != null && member != null) {
          final memberDetails = extractMemberRuntimeDetails(
            member: member,
            guild: guild,
            guildId: resolvedGuildId.toString(),
          );
          optionResult["${value.name}.permissions"] =
              memberDetails['member.permissions'] ?? '';
          optionResult["${value.name}.isAdmin"] =
              memberDetails['member.isAdmin'] ?? 'false';
          optionResult.addAll(
            extractPermissionsByIdRuntimeDetails(
              userId: userId.toString(),
              memberDetails: memberDetails,
            ),
          );
        }
      }

      if (user == null) {
        return optionResult;
      }
      optionResult.addAll({
        value.name: user.username,
        "${value.name}.id": user.id.toString(),
        "${value.name}.username": user.username,
        "${value.name}.tag": user.discriminator,
        "${value.name}.avatar": makeAvatarUrl(
          user.id.toString(),
          avatarId: user.avatar.hash,
          isAnimated: user.avatar.isAnimated,
          legacyFormat: "webp",
          discriminator: user.discriminator,
        ),
        "${value.name}.banner": makeBannerUrl(
          user.id.toString(),
          bannerId: (user as dynamic).banner?.hash?.toString(),
          isAnimated: (user as dynamic).banner?.isAnimated == true,
          legacyFormat: "webp",
        ),
      });
      return optionResult;
    case CommandOptionType.channel:
      final channelId = Snowflake(int.parse(value.value.toString()));
      final channel = await fetchChannelCached(client, channelId);
      if (channel == null) {
        return {
          value.name: channelId.toString(),
          "${value.name}.id": channelId.toString(),
          "${value.name}.type": 'unknown',
        };
      }
      return {
        value.name: getChannelName(channel),
        "${value.name}.id": channel.id.toString(),
        "${value.name}.type": channel.type.toString(),
      };
    case CommandOptionType.role:
      final role = await interaction.guild?.roles.fetch(
        value.value as Snowflake,
      );
      return {
        value.name: role?.name ?? "Unknown Role",
        "${value.name}.id": role?.id.toString() ?? "Unknown Role",
      };
    case CommandOptionType.mentionable:
      final mentionableId = Snowflake(int.parse(value.value.toString()));
      final mentionable = await _fetchUserCached(client, mentionableId);
      if (mentionable == null) {
        return {
          value.name: mentionableId.toString(),
          "${value.name}.id": mentionableId.toString(),
        };
      }
      return {
        value.name: mentionable.username,
        "${value.name}.id": mentionable.id.toString(),
        "${value.name}.username": mentionable.username,
        "${value.name}.tag": mentionable.discriminator,
        "${value.name}.avatar": makeAvatarUrl(
          mentionable.id.toString(),
          avatarId: mentionable.avatar.hash,
          isAnimated: mentionable.avatar.isAnimated,
          legacyFormat: "webp",
          discriminator: mentionable.discriminator,
        ),
        "${value.name}.banner": makeBannerUrl(
          mentionable.id.toString(),
          bannerId: (mentionable as dynamic).banner?.hash?.toString(),
          isAnimated: (mentionable as dynamic).banner?.isAnimated == true,
          legacyFormat: "webp",
        ),
      };
    case CommandOptionType.number:
      return {value.name: value.value.toString()};
  }
  return {value.name: value.value.toString()};
}

Future<Map<String, String>> generateInteractionContextKeyValues(
  Interaction interaction,
) async {
  final dynamic raw = interaction;
  final guildId = _asSnowflake(raw.guildId ?? raw.guild?.id);
  final channelId = _asSnowflake(raw.channelId ?? raw.channel?.id);
  final messageId = _asSnowflake(raw.message?.id);

  User? user;
  final rawUser = raw.user;
  if (rawUser is User) {
    user = rawUser;
  } else {
    final memberUser = raw.member?.user;
    if (memberUser is User) {
      user = memberUser;
    }
  }

  final userId = _asSnowflake(user?.id ?? raw.member?.id);
  if (user == null && userId != null) {
    user = await _fetchUserCached(interaction.manager.client, userId);
  }

  Member? member;
  if (raw.member is Member) {
    member = raw.member as Member;
  }
  if (member == null && guildId != null && userId != null) {
    member = await _fetchMemberCached(
      interaction,
      guildId: guildId,
      userId: userId,
    );
  }

  Guild? guild;
  if (raw.guild is Guild) {
    guild = raw.guild as Guild;
  }
  final count = await getGuildMemberCount(
    guild,
    client: interaction.manager.client,
    guildId: guildId,
  );
  if (guildId != null && (guild == null || count <= 0)) {
    guild = await fetchGuildCached(interaction.manager.client, guildId);
  }

  Channel? channel;
  if (raw.channel is Channel) {
    channel = raw.channel as Channel;
  }
  if (channel == null && channelId != null) {
    channel = await fetchChannelCached(interaction.manager.client, channelId);
  }

  final userIdText = userId?.toString() ?? '';
  final username = user?.username ?? member?.user?.username ?? '';
  final tag = user?.discriminator ?? member?.user?.discriminator ?? '';
  final userAvatarUrl =
      user == null
          ? ''
          : makeAvatarUrl(
            user.id.toString(),
            avatarId: user.avatar.hash,
            isAnimated: user.avatar.isAnimated,
            legacyFormat: 'webp',
            discriminator: user.discriminator,
          );
  String userBannerUrl = '';
  try {
    if (user != null) {
      userBannerUrl = makeBannerUrl(
        user.id.toString(),
        bannerId: (user as dynamic).banner?.hash?.toString(),
        isAnimated: (user as dynamic).banner?.isAnimated == true,
        legacyFormat: 'webp',
      );
    }
  } catch (_) {}

  String memberAvatarUrl = userAvatarUrl;
  try {
    final dynamic dynamicMember = member;
    final dynamic memberAvatar = dynamicMember?.avatar;
    final memberAvatarHash = memberAvatar?.hash?.toString() ?? '';
    if (memberAvatarHash.isNotEmpty && userIdText.isNotEmpty) {
      memberAvatarUrl = makeAvatarUrl(
        userIdText,
        avatarId: memberAvatarHash,
        isAnimated: memberAvatar?.isAnimated == true,
        legacyFormat: 'webp',
        discriminator: tag,
      );
    }
  } catch (_) {}

  final guildName = guild?.name ?? 'DM';
  final guildIcon = makeGuildIcon(
    guildId?.toString() ?? 'DM',
    guild?.icon?.hash,
  );
  final channelName = getChannelName(channel);
  final channelType = channel?.type.value.toString() ?? '0';
  final channelMention = channel != null ? '<#${channel.id}>' : '';

  return <String, String>{
    'interaction.guildId': guildId?.toString() ?? '',
    'interaction.channelId': channelId?.toString() ?? '',
    'interaction.messageId': messageId?.toString() ?? '',
    'interaction.userId': userIdText,
    'userName': username,
    'userId': userIdText,
    'userUsername': username,
    'userTag': tag,
    'userAvatar': userAvatarUrl,
    'userBanner': userBannerUrl,
    'user.id': userIdText,
    'user.username': username,
    'user.tag': tag,
    'user.avatar': userAvatarUrl,
    'user.banner': userBannerUrl,
    'author.id': userIdText,
    'author.username': username,
    'author.tag': tag,
    'author.avatar': userAvatarUrl,
    'author.banner': userBannerUrl,
    'interaction.user.id': userIdText,
    'interaction.user.username': username,
    'interaction.user.tag': tag,
    'interaction.user.avatar': userAvatarUrl,
    'interaction.user.banner': userBannerUrl,
    'member.id': userIdText,
    'member.nick': member?.nick ?? '',
    'member.avatar': memberAvatarUrl,
    'interaction.member.id': userIdText,
    'interaction.member.nick': member?.nick ?? '',
    'interaction.member.avatar': memberAvatarUrl,
    'guildName': guildName,
    'guildId': guildId?.toString() ?? '',
    'guildIcon': guildIcon,
    'guildCount': count.toString(),
    'guild.name': guildName,
    'guild.id': guildId?.toString() ?? '',
    'guild.count': count.toString(),
    'interaction.guild.name': guildName,
    'interaction.guild.id': guildId?.toString() ?? '',
    'interaction.guild.icon': guildIcon,
    'channelName': channelName,
    'channelId': channelId?.toString() ?? '',
    'channelType': channelType,
    'channel.name': channelName,
    'channel.id': channelId?.toString() ?? '',
    'channel.type': channelType,
    'channel.mention': channelMention,
    'user.mention':
        user != null
            ? '<@${user.id}>'
            : (member?.user != null ? '<@${member!.user!.id}>' : ''),
    'author.mention':
        user != null
            ? '<@${user.id}>'
            : (member?.user != null ? '<@${member!.user!.id}>' : ''),
    'member.mention': member != null ? '<@${member.id}>' : '',
    'interaction.channel.name': channelName,
    'interaction.channel.id': channelId?.toString() ?? '',
    'interaction.channel.type': channelType,
    'interaction.channel.mention': channelMention,
    ...extractChannelRuntimeDetails(channel),
    ...await extractGuildRuntimeDetails(
      guild,
      client: interaction.manager.client,
      guildId: guildId,
    ),
  };
}

InteractionOption? findFocusedOption(List<InteractionOption>? options) {
  return findFocusedInteractionOption(options);
}

String getChannelName(PartialChannel? channel) {
  if (channel is GuildTextChannel) {
    return channel.name;
  } else if (channel is GuildVoiceChannel) {
    return channel.name;
  } else if (channel is ThreadsOnlyChannel) {
    return channel.name;
  } else if (channel is GuildStageChannel) {
    return channel.name;
  } else if (channel is DmChannel) {
    return "DM";
  }
  return "Unknown Channel";
}
