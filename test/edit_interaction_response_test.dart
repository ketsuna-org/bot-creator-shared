import 'package:bot_creator_shared/actions/edit_interaction_response.dart';
import 'package:bot_creator_shared/utils/interaction_ack_state.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

void main() {
  group('editInteractionMessageAction', () {
    test('updates message directly on unacknowledged component interaction', () async {
      final mockInteraction = MockMessageComponentInteraction();
      expect(isInteractionAcknowledged(mockInteraction), isFalse);

      final result = await editInteractionMessageAction(
        mockInteraction,
        payload: <String, dynamic>{
          'content': 'Hello, updated!',
        },
        resolve: (val) => val,
      );

      expect(result['error'], isNull);
      expect(mockInteraction.didRespond, isTrue);
      expect(mockInteraction.updateMessageCalled, isTrue);
      expect(mockInteraction.updateOriginalResponseCalled, isFalse);
      expect(isInteractionAcknowledged(mockInteraction), isTrue);
      expect(result['messageId'], equals('12345'));
    });

    test('supports editing components using componentV2 payload key', () async {
      final mockInteraction = MockMessageComponentInteraction();
      expect(isInteractionAcknowledged(mockInteraction), isFalse);

      final result = await editInteractionMessageAction(
        mockInteraction,
        payload: <String, dynamic>{
          'content': 'Hello with components!',
          'componentV2': <String, dynamic>{
            'rows': [
              {
                'components': [
                  {
                    'type': 'button',
                    'customId': 'btn1',
                    'label': 'Click me',
                    'style': 1,
                  }
                ]
              }
            ],
          },
        },
        resolve: (val) => val,
      );

      expect(result['error'], isNull);
      expect(mockInteraction.didRespond, isTrue);
      expect(mockInteraction.updateMessageCalled, isTrue);
      expect(result['messageId'], equals('12345'));
    });

    test('updates original response on already acknowledged component interaction', () async {
      final mockInteraction = MockMessageComponentInteraction();
      markInteractionAcknowledged(mockInteraction);
      expect(isInteractionAcknowledged(mockInteraction), isTrue);

      final result = await editInteractionMessageAction(
        mockInteraction,
        payload: <String, dynamic>{
          'content': 'Hello, updated again!',
        },
        resolve: (val) => val,
      );

      expect(result['error'], isNull);
      expect(mockInteraction.didRespond, isFalse);
      expect(mockInteraction.updateOriginalResponseCalled, isTrue);
      expect(result['messageId'], equals('12345'));
    });

    test('falls back to _FakeMessage if message is null and fetchOriginalResponse throws', () async {
      final mockInteraction = ExceptionMockMessageComponentInteraction();
      expect(isInteractionAcknowledged(mockInteraction), isFalse);

      final result = await editInteractionMessageAction(
        mockInteraction,
        payload: <String, dynamic>{
          'content': 'Hello, updated!',
        },
        resolve: (val) => val,
      );

      expect(result['error'], isNull);
      expect(mockInteraction.didRespond, isTrue);
      expect(mockInteraction.updateMessageCalled, isTrue);
      expect(isInteractionAcknowledged(mockInteraction), isTrue);
      expect(result['messageId'], equals('0'));
    });

    test('falls back to _FakeMessage if message is null and updateOriginalResponse throws', () async {
      final mockInteraction = ExceptionMockMessageComponentInteraction();
      markInteractionAcknowledged(mockInteraction);
      expect(isInteractionAcknowledged(mockInteraction), isTrue);

      final result = await editInteractionMessageAction(
        mockInteraction,
        payload: <String, dynamic>{
          'content': 'Hello, updated again!',
        },
        resolve: (val) => val,
      );

      expect(result['error'], isNull);
      expect(mockInteraction.didRespond, isFalse);
      expect(result['messageId'], equals('0'));
    });
  });
}

class ExceptionMockMessageComponentInteraction extends MockMessageComponentInteraction {
  @override
  Message? get message => null;

  @override
  Future<Message> fetchOriginalResponse() async {
    throw Exception('Simulated fetchOriginalResponse error');
  }

  @override
  Future<Message> updateOriginalResponse(MessageUpdateBuilder builder) async {
    throw Exception('Simulated updateOriginalResponse error');
  }
}


class MockMessageComponentInteraction implements MessageComponentInteraction {
  bool didRespond = false;
  bool updateMessageCalled = false;
  bool updateOriginalResponseCalled = false;

  @override
  Future<InteractionCallbackResponse?> respond(
    Builder<Message> builder, {
    bool? updateMessage,
    bool? isEphemeral,
    bool? withResponse,
  }) async {
    didRespond = true;
    updateMessageCalled = updateMessage == true;
    return null;
  }

  @override
  Future<Message> updateOriginalResponse(MessageUpdateBuilder builder) async {
    updateOriginalResponseCalled = true;
    return _MockMessage();
  }

  @override
  Future<Message> fetchOriginalResponse() async {
    return _MockMessage();
  }

  @override
  final Snowflake? guildId = Snowflake(9876);

  @override
  final Snowflake? channelId = Snowflake(5432);

  @override
  final Message? message = _MockMessage();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMessage implements Message {
  @override
  final Snowflake id = Snowflake(12345);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
