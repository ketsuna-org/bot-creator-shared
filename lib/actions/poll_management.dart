import 'dart:convert';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

/// Creates a Discord poll in a channel.
///
/// Payload fields:
/// - `channelId` — target channel
/// - `question` — poll question (required)
/// - `answers` — JSON array of answer strings, e.g. `["Yes","No"]` (required, max 10)
/// - `durationHours` — duration in hours (1–168, default 24)
/// - `allowMultiselect` — whether users can pick multiple answers (default false)
///
/// Returns `{'messageId', 'pollId'}` or `{'error': '...'}`.
Future<Map<String, String>> createPollAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  Snowflake? fallbackChannelId,
  required String Function(String) resolve,
}) async {
  try {
    final channelId =
        _toSnowflake(resolve((payload['channelId'] ?? '').toString())) ??
        fallbackChannelId;
    if (channelId == null) {
      return {'error': 'channelId is required for createPoll'};
    }

    final question = resolve((payload['question'] ?? '').toString()).trim();
    if (question.isEmpty) {
      return {'error': 'question is required for createPoll'};
    }

    // Parse answers — accepts JSON array string or List
    List<String> answers = [];
    final rawAnswers = payload['answers'];
    if (rawAnswers is List) {
      answers =
          rawAnswers
              .map((e) => resolve(e.toString()).trim())
              .where((s) => s.isNotEmpty)
              .toList();
    } else {
      final resolved = resolve((rawAnswers ?? '').toString()).trim();
      if (resolved.isNotEmpty) {
        try {
          final decoded = jsonDecode(resolved);
          if (decoded is List) {
            answers =
                decoded
                    .map((e) => e.toString().trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
          }
        } catch (_) {
          // Treat as comma-separated
          answers =
              resolved
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
        }
      }
    }

    if (answers.isEmpty) {
      return {'error': 'At least one answer is required for createPoll'};
    }
    if (answers.length > 10) {
      return {'error': 'createPoll supports at most 10 answers'};
    }

    final rawDuration =
        int.tryParse(resolve((payload['durationHours'] ?? '24').toString())) ??
        24;
    final durationHours = rawDuration.clamp(1, 168);

    final allowMultiselectRaw =
        resolve(
          (payload['allowMultiselect'] ?? 'false').toString(),
        ).toLowerCase();
    final allowMultiselect =
        allowMultiselectRaw == 'true' || allowMultiselectRaw == '1';

    final channel = await fetchChannelCached(client, channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel'};
    }

    final pollAnswers =
        answers
            .map(
              (text) =>
                  PollAnswerBuilder(pollMedia: PollMediaBuilder(text: text)),
            )
            .toList();

    final message = await channel.sendMessage(
      MessageBuilder(
        poll: PollBuilder(
          question: PollMediaBuilder(text: question),
          answers: pollAnswers,
          duration: Duration(hours: durationHours),
          allowMultiselect: allowMultiselect,
        ),
      ),
    );

    return {
      'messageId': message.id.toString(),
      'pollId': message.id.toString(),
    };
  } catch (e) {
    return {'error': 'Failed to create poll: $e'};
  }
}

/// Immediately ends an active poll on a message.
///
/// Payload fields:
/// - `channelId` — channel containing the poll message
/// - `messageId` — message ID of the poll
///
/// Returns `{'messageId', 'status': 'ended'}` or `{'error': '...'}`.
Future<Map<String, String>> endPollAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  Snowflake? fallbackChannelId,
}) async {
  try {
    final channelId = _toSnowflake(payload['channelId']) ?? fallbackChannelId;
    if (channelId == null) {
      return {'error': 'channelId is required for endPoll'};
    }

    final messageId = _toSnowflake(payload['messageId']);
    if (messageId == null) {
      return {'error': 'messageId is required for endPoll'};
    }

    final channel = await fetchChannelCached(client, channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel'};
    }
    await channel.messages.endPoll(messageId);
    return {'messageId': messageId.toString(), 'status': 'ended'};
  } catch (e) {
    return {'error': 'Failed to end poll: $e'};
  }
}
