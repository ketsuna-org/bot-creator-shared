part of '../event_contexts.dart';

dynamic _safeRead(dynamic object, dynamic Function() reader) {
  try {
    return reader();
  } catch (_) {
    return null;
  }
}

List<String> _stringifyInteractionValues(dynamic rawValues) {
  if (rawValues is! Iterable) {
    return const <String>[];
  }

  return rawValues
      .map((value) => value.toString())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

List<String> _extractResolvedEntityIds(dynamic resolvedEntityMap) {
  if (resolvedEntityMap is Map) {
    return resolvedEntityMap.keys
        .map((key) => key.toString())
        .where((key) => key.isNotEmpty)
        .toList(growable: false);
  }

  if (resolvedEntityMap is Iterable) {
    return resolvedEntityMap
        .map((item) => _idString(_safeRead(item, () => item.id) ?? item))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  return const <String>[];
}

String? _normalizeSelectComponentType(dynamic rawType) {
  final normalized = rawType.toString().toLowerCase().replaceAll(
    RegExp(r'[^a-z]'),
    '',
  );

  if (normalized.contains('stringselect')) {
    return 'string';
  }
  if (normalized.contains('channelselect')) {
    return 'channel';
  }
  if (normalized.contains('userselect')) {
    return 'user';
  }
  if (normalized.contains('roleselect')) {
    return 'role';
  }
  if (normalized.contains('mentionableselect')) {
    return 'mentionable';
  }

  return null;
}

void _addSelectCollectionVariables({
  required Map<String, String> variables,
  required String singularKey,
  required String pluralKey,
  required String countKey,
  required List<String> values,
}) {
  variables[singularKey] = values.isNotEmpty ? values.first : '';
  variables[pluralKey] = values.join(',');
  variables[countKey] = values.length.toString();
  variables['__collection.$singularKey'] = jsonEncode(values);
  variables['__collection.$pluralKey'] = jsonEncode(values);

  for (var index = 0; index < values.length; index++) {
    variables['$singularKey[${index + 1}]'] = values[index];
  }
}

Map<String, String> _buildSelectInteractionVariables(
  dynamic data,
  List<String> values,
) {
  final selectType = _normalizeSelectComponentType(
    _safeRead(data, () => data?.type),
  );
  if (selectType == null) {
    return const <String, String>{};
  }

  final resolved = _safeRead(data, () => data?.resolved);
  switch (selectType) {
    case 'string':
      final variables = <String, String>{};
      _addSelectCollectionVariables(
        variables: variables,
        singularKey: 'interaction.stringSelect.value',
        pluralKey: 'interaction.stringSelect.values',
        countKey: 'interaction.stringSelect.count',
        values: values,
      );
      return variables;
    case 'channel':
      final variables = <String, String>{};
      _addSelectCollectionVariables(
        variables: variables,
        singularKey: 'interaction.channelSelect.channelId',
        pluralKey: 'interaction.channelSelect.channelIds',
        countKey: 'interaction.channelSelect.channelCount',
        values: values,
      );
      return variables;
    case 'user':
      final variables = <String, String>{};
      _addSelectCollectionVariables(
        variables: variables,
        singularKey: 'interaction.userSelect.userId',
        pluralKey: 'interaction.userSelect.userIds',
        countKey: 'interaction.userSelect.userCount',
        values: values,
      );
      return variables;
    case 'role':
      final variables = <String, String>{};
      _addSelectCollectionVariables(
        variables: variables,
        singularKey: 'interaction.roleSelect.roleId',
        pluralKey: 'interaction.roleSelect.roleIds',
        countKey: 'interaction.roleSelect.roleCount',
        values: values,
      );
      return variables;
    case 'mentionable':
      final mentionableUserIds = _extractResolvedEntityIds(
        _safeRead(resolved, () => resolved?.users),
      );
      final variables = <String, String>{};
      _addSelectCollectionVariables(
        variables: variables,
        singularKey: 'interaction.mentionableSelect.userId',
        pluralKey: 'interaction.mentionableSelect.userIds',
        countKey: 'interaction.mentionableSelect.userCount',
        values: mentionableUserIds.isNotEmpty ? mentionableUserIds : values,
      );
      return variables;
  }

  return const <String, String>{};
}

Map<String, String> buildInteractionRuntimeVariables(Interaction interaction) {
  final dynamic data = _safeRead(interaction, () => interaction.data);
  final dynamic commandType = _safeRead(data, () => data.type);
  final dynamic commandId = _safeRead(data, () => data.id);
  final commandName = (_safeRead(data, () => data.name) ?? '').toString();

  final customId = (_safeRead(data, () => data.customId) ?? '').toString();
  final values = _stringifyInteractionValues(
    _safeRead(data, () => data.values),
  );

  final modalComponents = _safeRead(data, () => data.components);
  final modalInputPairs = <String, String>{};
  if (modalComponents is Iterable) {
    for (final component in modalComponents) {
      final innerComponents = _safeRead(component, () => component.components);
      if (innerComponents is! Iterable) {
        continue;
      }
      for (final inner in innerComponents) {
        final key =
            (_safeRead(inner, () => inner.customId) ?? '').toString().trim();
        if (key.isEmpty) {
          continue;
        }
        final value = (_safeRead(inner, () => inner.value) ?? '').toString();
        modalInputPairs['modal.$key'] = value;
      }
    }
  }

  final userId =
      _idString(_safeRead(interaction, () => interaction.user?.id)) != ''
          ? _idString(_safeRead(interaction, () => interaction.user?.id))
          : _idString(
            _safeRead(interaction, () => interaction.member?.user?.id),
          );
  final channelId = _idString(
    _safeRead(interaction, () => interaction.channelId) ??
        _safeRead(interaction, () => interaction.channel?.id),
  );
  final guildId = _idString(
    _safeRead(interaction, () => interaction.guildId) ??
        _safeRead(interaction, () => interaction.guild?.id),
  );
  final messageId = _idString(
    _safeRead(interaction, () => interaction.message?.id),
  );

  final kind =
      interaction is MessageComponentInteraction
          ? ((values.isNotEmpty) ? 'select' : 'button')
          : interaction is ModalSubmitInteraction
          ? 'modal'
          : interaction is ApplicationCommandInteraction
          ? 'command'
          : interaction is ApplicationCommandAutocompleteInteraction
          ? 'autocomplete'
          : interaction.type.toString();

  return <String, String>{
    'interaction.kind': kind,
    'interaction.customId': customId,
    'interaction.values': values.join(','),
    'interaction.values.count': values.length.toString(),
    'interaction.guildId': guildId,
    'interaction.channelId': channelId,
    'interaction.userId': userId,
    'interaction.messageId': messageId,
    'interaction.command.name': commandName,
    'interaction.command.id': commandId?.toString() ?? '',
    'interaction.command.type': commandType?.toString() ?? '',
    'modal.customId': customId,
    ..._buildSelectInteractionVariables(data, values),
    ...modalInputPairs,
  };
}

EventExecutionContext buildInteractionCreateEventContext(
  InteractionCreateEvent event,
) {
  final interaction = event.interaction;
  final dynamic data = interaction.data;

  final extra = <String, String>{
    ...buildInteractionRuntimeVariables(interaction),
    'interaction.id': interaction.id.toString(),
    'interaction.token': interaction.token,
    'interaction.applicationId': interaction.applicationId.toString(),
    'interaction.data.type':
        (interaction is ModalSubmitInteraction)
            ? ''
            : _safeRead(data, () => data.type)?.toString() ?? '',
  };

  // Enrich with member details when available (guild interactions).
  final member = interaction.member;
  if (member is Member) {
    extra['member.id'] = member.id.toString();
    extra['member.nick'] = member.nick ?? '';
    extra['member.avatar'] = makeAvatarUrl(
      member.id.toString(),
      avatarId: member.avatar?.hash ?? member.user?.avatar.hash,
      isAnimated: member.avatar?.isAnimated ?? member.user?.avatar.isAnimated ?? false,
      legacyFormat: 'webp',
      discriminator: member.user?.discriminator,
    );
    extra['member.joinedAt'] = member.joinedAt.toIso8601String();
    extra['member.roles'] = member.roleIds.map((id) => id.toString()).join(',');
    extra['member.roles.count'] = member.roleIds.length.toString();
    extra['member.isBooster'] = (member.premiumSince != null).toString();
    if (member.communicationDisabledUntil != null) {
      extra['member.communicationDisabledUntil'] =
          member.communicationDisabledUntil!.toIso8601String();
    }
  }

  // Enrich with user details when available.
  final user = interaction.user ?? member?.user;
  if (user != null) {
    extra['user.id'] = user.id.toString();
    extra['user.username'] = user.username;
    extra['user.globalName'] = user.globalName ?? user.username;
    extra['user.tag'] = user.discriminator;
    final userAvatarUrl = makeAvatarUrl(
      user.id.toString(),
      avatarId: user.avatar.hash,
      isAnimated: user.avatar.isAnimated,
      legacyFormat: 'webp',
      discriminator: user.discriminator,
    );
    extra['user.avatar'] = userAvatarUrl;
    extra['user.banner'] = user.banner?.url.toString() ?? '';
    extra['user.createdAt'] = user.id.timestamp.toIso8601String();
    extra['author.id'] = user.id.toString();
    extra['author.username'] = user.username;
    extra['author.globalName'] = user.globalName ?? user.username;
    extra['author.tag'] = user.discriminator;
    extra['author.avatar'] = userAvatarUrl;
    extra['author.banner'] = user.banner?.url.toString() ?? '';
    final accentColor = user.accentColor;
    if (accentColor != null) {
      extra['user.bannerColor'] =
          '#${accentColor.value.toRadixString(16).padLeft(6, '0')}';
    }
  }

  return _baseEventContext(
    eventName: 'interactionCreate',
    guildId: _asSnowflake(interaction.guildId),
    channelId: _asSnowflake(interaction.channelId),
    userId:
        _asSnowflake(interaction.user?.id) ??
        _asSnowflake(interaction.member?.user?.id),
    interaction: interaction,
    extra: extra,
  );
}
