import 'package:nyxx/nyxx.dart';

/// Parses allowed mentions from a payload using the provided resolver function.
AllowedMentions? parseAllowedMentions(Map<String, dynamic>? payload, String Function(String) resolve) {
  if (payload == null || !payload.containsKey('allowedMentions')) {
    return null;
  }
  final json = payload['allowedMentions'];
  if (json is! Map) return null;

  final parseList = (json['parse'] as List?)?.map((e) => resolve(e.toString())).toList();
  final usersList = (json['users'] as List?)
      ?.map((e) {
        final resolved = resolve(e.toString());
        final val = int.tryParse(resolved);
        return val != null ? Snowflake(val) : null;
      })
      .whereType<Snowflake>()
      .toList();
  final rolesList = (json['roles'] as List?)
      ?.map((e) {
        final resolved = resolve(e.toString());
        final val = int.tryParse(resolved);
        return val != null ? Snowflake(val) : null;
      })
      .whereType<Snowflake>()
      .toList();

  return AllowedMentions(
    parse: parseList,
    users: usersList,
    roles: rolesList,
  );
}
