import 'package:bot_creator_shared/utils/global.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

class _FakeChannel {
  _FakeChannel({
    this.id,
    this.topic,
    this.parentId,
    this.position,
    this.isNsfw,
    this.rateLimitPerUser,
    this.bitrate,
    this.userLimit,
    this.isArchived,
    this.isLocked,
    this.ownerId,
    this.autoArchiveDuration,
  });

  final String? id;
  final String? topic;
  final String? parentId;
  final int? position;
  final bool? isNsfw;
  final int? rateLimitPerUser;
  final int? bitrate;
  final int? userLimit;
  final bool? isArchived;
  final bool? isLocked;
  final String? ownerId;
  final int? autoArchiveDuration;
}

class _FakeGuild {
  _FakeGuild({
    this.id,
    this.ownerId,
    this.description,
    this.vanityUrlCode,
    this.preferredLocale,
    this.verificationLevel,
    this.mfaLevel,
    this.nsfwLevel,
    this.premiumTier,
    this.premiumSubscriptionCount,
    this.features,
    this.memberCount,
  });

  final String? id;
  final String? ownerId;
  final String? description;
  final String? vanityUrlCode;
  final String? preferredLocale;
  final String? verificationLevel;
  final String? mfaLevel;
  final String? nsfwLevel;
  final int? premiumTier;
  final int? premiumSubscriptionCount;
  final List<String>? features;
  final int? memberCount;
}

class _FakeRolePermissions {
  const _FakeRolePermissions(this.value);

  final int value;
}

class _FakeRole {
  const _FakeRole({required this.id, required this.permissions});

  final dynamic id;
  final dynamic permissions;
}

class _FakeGuildWithRoles {
  const _FakeGuildWithRoles({required this.roleList, this.ownerId});

  final List<_FakeRole> roleList;
  final dynamic ownerId;
}

class _FakeMemberWithRoles {
  const _FakeMemberWithRoles({
    required this.roleIds,
    this.id,
    this.permissions,
  });

  final List<dynamic> roleIds;
  final dynamic id;
  final dynamic permissions;
}

void main() {
  group('extractChannelRuntimeDetails', () {
    test('extracts advanced channel fields', () {
      final details = extractChannelRuntimeDetails(
        _FakeChannel(
          id: '999',
          topic: 'alerts',
          parentId: '123',
          position: 4,
          isNsfw: true,
          rateLimitPerUser: 10,
          bitrate: 64000,
          userLimit: 25,
          isArchived: true,
          isLocked: false,
          ownerId: '777',
          autoArchiveDuration: 1440,
        ),
      );

      expect(details['channel.id'], '999');
      expect(details['channel.topic'], 'alerts');
      expect(details['channel.parentId'], '123');
      expect(details['channel.position'], '4');
      expect(details['channel.nsfw'], 'true');
      expect(details['channel.slowmode'], '10');
      expect(details['channel.bitrate'], '64000');
      expect(details['channel.userLimit'], '25');
      expect(details['channel.thread.archived'], 'true');
      expect(details['channel.thread.locked'], 'false');
      expect(details['channel.thread.ownerId'], '777');
      expect(details['channel.thread.autoArchiveDuration'], '1440');
    });
  });

  group('extractGuildRuntimeDetails', () {
    test('extracts advanced guild fields', () async {
      final details = await extractGuildRuntimeDetails(
        _FakeGuild(
          id: '888',
          ownerId: '42',
          description: 'Main guild',
          vanityUrlCode: 'myguild',
          preferredLocale: 'fr',
          verificationLevel: 'high',
          mfaLevel: 'elevated',
          nsfwLevel: 'default',
          premiumTier: 2,
          premiumSubscriptionCount: 14,
          features: const <String>['COMMUNITY', 'INVITES_DISABLED'],
          memberCount: 1200,
        ),
      );

      expect(details['guild.id'], '888');
      expect(details['guild.ownerId'], '42');
      expect(details['guild.description'], 'Main guild');
      expect(details['guild.vanityUrlCode'], 'myguild');
      expect(details['guild.preferredLocale'], 'fr');
      expect(details['guild.verificationLevel'], 'high');
      expect(details['guild.mfaLevel'], 'elevated');
      expect(details['guild.nsfwLevel'], 'default');
      expect(details['guild.premiumTier'], '2');
      expect(details['guild.premiumSubscriptionCount'], '14');
      expect(details['guild.features'], 'COMMUNITY,INVITES_DISABLED');
      expect(details['guild.features.count'], '2');
      expect(details['guild.memberCount'], '1200');
    });
  });

  group('extractMemberRuntimeDetails', () {
    test('extracts admin flag and permission tokens from role bitmask', () {
      final details = extractMemberRuntimeDetails(
        member: const _FakeMemberWithRoles(roleIds: <String>['200']),
        guild: _FakeGuildWithRoles(
          roleList: <_FakeRole>[
            _FakeRole(
              id: '100',
              permissions: _FakeRolePermissions(Permissions.sendMessages.value),
            ),
            _FakeRole(
              id: '200',
              permissions: _FakeRolePermissions(
                Permissions.administrator.value | Permissions.banMembers.value,
              ),
            ),
          ],
        ),
        guildId: '100',
      );

      expect(details['member.isAdmin'], 'true');
      final permissions = details['member.permissions'] ?? '';
      expect(permissions, contains('administrator'));
      expect(permissions, contains('banmembers'));
      expect(permissions, contains('sendmessages'));
    });

    test('grants all permissions when member is the guild owner', () {
      final details = extractMemberRuntimeDetails(
        member: const _FakeMemberWithRoles(roleIds: <String>['200'], id: '42'),
        guild: _FakeGuildWithRoles(
          ownerId: '42',
          roleList: <_FakeRole>[
            _FakeRole(
              id: '200',
              permissions: _FakeRolePermissions(Permissions.sendMessages.value),
            ),
          ],
        ),
        guildId: '100',
      );

      expect(details['member.isAdmin'], 'true');
      final permissions = details['member.permissions'] ?? '';
      expect(permissions, contains('administrator'));
      expect(permissions, contains('banmembers'));
      expect(permissions, contains('manageguild'));
      expect(permissions, contains('manageroles'));
      expect(permissions, contains('kickmembers'));
    });

    test('computes permissions correctly with Snowflake-typed role IDs', () {
      final details = extractMemberRuntimeDetails(
        member: _FakeMemberWithRoles(roleIds: <Snowflake>[Snowflake(200)]),
        guild: _FakeGuildWithRoles(
          roleList: <_FakeRole>[
            _FakeRole(
              id: Snowflake(100),
              permissions: _FakeRolePermissions(Permissions.sendMessages.value),
            ),
            _FakeRole(
              id: Snowflake(200),
              permissions: _FakeRolePermissions(
                Permissions.administrator.value | Permissions.banMembers.value,
              ),
            ),
          ],
        ),
        guildId: '100',
      );

      expect(details['member.isAdmin'], 'true');
      final permissions = details['member.permissions'] ?? '';
      expect(permissions, contains('administrator'));
      expect(permissions, contains('banmembers'));
      expect(permissions, contains('sendmessages'));
    });

    test('computes permissions with Permissions-typed role permissions', () {
      final details = extractMemberRuntimeDetails(
        member: _FakeMemberWithRoles(roleIds: <Snowflake>[Snowflake(200)]),
        guild: _FakeGuildWithRoles(
          roleList: <_FakeRole>[
            _FakeRole(
              id: Snowflake(100),
              permissions: Permissions(Permissions.sendMessages.value),
            ),
            _FakeRole(
              id: Snowflake(200),
              permissions: Permissions(
                Permissions.administrator.value | Permissions.banMembers.value,
              ),
            ),
          ],
        ),
        guildId: '100',
      );

      expect(details['member.isAdmin'], 'true');
      final permissions = details['member.permissions'] ?? '';
      expect(permissions, contains('administrator'));
      expect(permissions, contains('banmembers'));
      expect(permissions, contains('sendmessages'));
    });

    test('uses member.permissions from interaction payload', () {
      // Simulate a member from an interaction payload where Discord computes
      // the full permissions server-side (e.g. owner has all permissions).
      final allPermsValue =
          Permissions.administrator.value |
          Permissions.banMembers.value |
          Permissions.kickMembers.value |
          Permissions.manageGuild.value |
          Permissions.manageRoles.value |
          Permissions.sendMessages.value;
      final details = extractMemberRuntimeDetails(
        member: _FakeMemberWithRoles(
          roleIds: const <String>[],
          permissions: Permissions(allPermsValue),
        ),
        guild: _FakeGuildWithRoles(
          roleList: <_FakeRole>[
            _FakeRole(
              id: '100',
              permissions: _FakeRolePermissions(Permissions.sendMessages.value),
            ),
          ],
        ),
        guildId: '100',
      );

      expect(details['member.isAdmin'], 'true');
      final permissions = details['member.permissions'] ?? '';
      expect(permissions, contains('administrator'));
      expect(permissions, contains('banmembers'));
      expect(permissions, contains('kickmembers'));
      expect(permissions, contains('manageguild'));
      expect(permissions, contains('manageroles'));
    });

    test('member.permissions supplements role-based computation', () {
      // Even when role-based computation works, member.permissions adds
      // permissions the role calculation may have missed.
      final details = extractMemberRuntimeDetails(
        member: _FakeMemberWithRoles(
          roleIds: const <String>['200'],
          permissions: Permissions(
            Permissions.manageGuild.value | Permissions.manageRoles.value,
          ),
        ),
        guild: _FakeGuildWithRoles(
          roleList: <_FakeRole>[
            _FakeRole(
              id: '100',
              permissions: _FakeRolePermissions(Permissions.sendMessages.value),
            ),
            _FakeRole(
              id: '200',
              permissions: _FakeRolePermissions(Permissions.banMembers.value),
            ),
          ],
        ),
        guildId: '100',
      );

      final permissions = details['member.permissions'] ?? '';
      // From role-based computation:
      expect(permissions, contains('sendmessages'));
      expect(permissions, contains('banmembers'));
      // From member.permissions (interaction payload):
      expect(permissions, contains('manageguild'));
      expect(permissions, contains('manageroles'));
    });

    test('maps member details to by-id permission keys', () {
      final mapped = extractPermissionsByIdRuntimeDetails(
        userId: '243117191774470146',
        memberDetails: const <String, String>{
          'member.permissions': 'administrator,banmembers',
          'member.isAdmin': 'true',
        },
      );

      expect(
        mapped['permissions.byId.243117191774470146'],
        'administrator,banmembers',
      );
      expect(mapped['isAdmin.byId.243117191774470146'], 'true');
    });
  });

  group('extractBotRuntimeDetails', () {
    test('extracts bot details and tracks uptime via botStartTimes registry', () {
      final client = _FakeNyxxRest();
      final botId = '12345';
      
      // Default fallback when not registered
      final initialDetails = extractBotRuntimeDetails(client);
      expect(initialDetails['bot.uptime'], '0');
      expect(initialDetails['bot.uptimeMs'], '0');
      
      // Register bot start time
      final startTime = DateTime.now().subtract(const Duration(seconds: 10));
      botStartTimes[botId] = startTime;
      
      final details = extractBotRuntimeDetails(client);
      expect(details['bot.id'], botId);
      expect(details['bot.uptime'], isNot('0'));
      
      final parsedUptime = int.parse(details['bot.uptime']!);
      expect(parsedUptime, greaterThan(8000));
      expect(parsedUptime, lessThan(12000));
      expect(details['bot.uptimeMs'], details['bot.uptime']);
      
      // Cleanup
      botStartTimes.remove(botId);
    });
  });
}

class _FakePartialUser implements PartialUser {
  @override
  final Snowflake id = Snowflake(12345);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGuildsManager implements GuildManager {
  @override
  final cache = _FakeCache<Guild>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUsersManager implements UserManager {
  @override
  final cache = _FakeCache<User>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCache<T> implements Cache<T> {
  @override
  final int length = 0;

  @override
  final Iterable<T> values = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNyxxRest implements NyxxRest {
  @override
  final user = _FakePartialUser();
  @override
  final guilds = _FakeGuildsManager();
  @override
  final users = _FakeUsersManager();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
