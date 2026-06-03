import 'dart:convert';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';
import 'package:bot_creator_shared/actions/respond_with_message.dart';

class MockMessageResponse implements MessageResponse {
  bool responded = false;
  bool updated = false;
  bool followedUp = false;
  
  MessageBuilder? respondBuilder;
  MessageUpdateBuilder? updateBuilder;
  MessageBuilder? followupBuilder;

  bool isAcknowledged = false;

  @override
  Snowflake? get guildId => Snowflake(1111);

  @override
  PartialChannel? get channel => null;

  @override
  Snowflake? get channelId => Snowflake(2222);

  @override
  Future<InteractionCallbackResponse?> respond(MessageBuilder builder, {bool? isEphemeral, bool? withResponse}) async {
    responded = true;
    respondBuilder = builder;
    isAcknowledged = true;
    return null;
  }

  @override
  Future<Message> updateOriginalResponse(MessageUpdateBuilder builder) async {
    updated = true;
    updateBuilder = builder;
    return _MockMessage();
  }

  Future<Message> sendFollowupMessage(MessageBuilder builder, {bool? isEphemeral}) async {
    followedUp = true;
    followupBuilder = builder;
    return _MockMessage();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMessage implements Message {
  @override
  Snowflake get id => Snowflake(123);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('respondWithMessageAction attachments', () {
    test('succeeds and attaches canvas files even if text content is empty', () async {
      final interaction = MockMessageResponse();
      final variables = {
        'temp._canvasAttachment_card': base64Encode([1, 2, 3]),
      };

      final result = await respondWithMessageAction(
        interaction,
        payload: {
          'content': '',
          'embeds': [],
          'components': {},
          'ephemeral': false,
        },
        resolve: (val) => val,
        botId: 'test_bot',
        variables: variables,
      );

      expect(result['error'], isNull);
      expect(interaction.responded, isTrue);
      expect(interaction.respondBuilder, isNotNull);
      expect(interaction.respondBuilder!.content, equals(' ')); // Space fallback for attachments
      expect(interaction.respondBuilder!.attachments, hasLength(1));
      expect(interaction.respondBuilder!.attachments!.first.fileName, equals('card.png'));
      expect(interaction.respondBuilder!.attachments!.first.data, equals([1, 2, 3]));
    });

    test('uses followup for acknowledged interaction when attachments are present', () async {
      final interaction = MockMessageResponse()..isAcknowledged = true;
      final variables = {
        'temp._canvasAttachment_card': base64Encode([4, 5, 6]),
      };

      final result = await respondWithMessageAction(
        interaction,
        payload: {
          'content': 'Test',
          'embeds': [],
          'components': {},
          'ephemeral': false,
        },
        resolve: (val) => val,
        botId: 'test_bot',
        variables: variables,
      );

      expect(result['error'], isNull);
      expect(interaction.followedUp, isTrue);
      expect(interaction.followupBuilder, isNotNull);
      expect(interaction.followupBuilder!.content, equals('Test'));
      expect(interaction.followupBuilder!.attachments, hasLength(1));
      expect(interaction.followupBuilder!.attachments!.first.data, equals([4, 5, 6]));
    });
  });
}
