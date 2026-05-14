import 'package:bot_creator_shared/utils/interaction_listener_registry.dart';
import 'package:test/test.dart';

void main() {
  group('InteractionListenerRegistry', () {
    test('matches listeners by bot, type, and optional scope', () {
      final customId = 'shared-custom-id-scope';
      final registry = InteractionListenerRegistry.instance;

      final botAEntry = ListenerEntry(
        botId: 'bot-a',
        workflowName: 'workflow-a',
        expiresAt: _future,
        type: 'button',
        channelId: 'channel-a',
      );
      final botBEntry = ListenerEntry(
        botId: 'bot-b',
        workflowName: 'workflow-b',
        expiresAt: _future,
        type: 'button',
        channelId: 'channel-b',
      );

      registry.register(customId, botAEntry);
      registry.register(customId, botBEntry);

      final match = registry.getMatching(
        customId,
        const ListenerMatchRequest(
          botId: 'bot-a',
          type: 'button',
          channelId: 'channel-a',
        ),
      );

      expect(match, same(botAEntry));

      registry.removeEntry(customId, botAEntry);
      registry.removeEntry(customId, botBEntry);
    });

    test('removeEntry only removes the matched listener instance', () {
      final customId = 'shared-custom-id-remove';
      final registry = InteractionListenerRegistry.instance;

      final first = ListenerEntry(
        botId: 'bot-a',
        workflowName: 'first',
        expiresAt: _future,
        type: 'button',
        channelId: 'channel-a',
      );
      final second = ListenerEntry(
        botId: 'bot-a',
        workflowName: 'second',
        expiresAt: _future,
        type: 'button',
        channelId: 'channel-b',
      );

      registry.register(customId, first);
      registry.register(customId, second);
      registry.removeEntry(customId, first);

      final remaining = registry.getMatching(
        customId,
        const ListenerMatchRequest(
          botId: 'bot-a',
          type: 'button',
          channelId: 'channel-b',
        ),
      );

      expect(remaining, same(second));

      registry.removeEntry(customId, second);
    });

    test('does not match listeners when interaction type differs', () {
      final customId = 'shared-custom-id-type';
      final registry = InteractionListenerRegistry.instance;

      final entry = ListenerEntry(
        botId: 'bot-a',
        workflowName: 'button-only',
        expiresAt: _future,
        type: 'button',
      );

      registry.register(customId, entry);

      final match = registry.getMatching(
        customId,
        const ListenerMatchRequest(botId: 'bot-a', type: 'modal'),
      );

      expect(match, isNull);

      registry.removeEntry(customId, entry);
    });

    test('matches listeners by messageId to avoid same-channel collisions', () {
      final customId = 'shared-custom-id-message-scope';
      final registry = InteractionListenerRegistry.instance;

      final first = ListenerEntry(
        botId: 'bot-a',
        workflowName: 'first',
        expiresAt: _future,
        type: 'button',
        channelId: 'channel-a',
        messageId: 'message-1',
      );
      final second = ListenerEntry(
        botId: 'bot-a',
        workflowName: 'second',
        expiresAt: _future,
        type: 'button',
        channelId: 'channel-a',
        messageId: 'message-2',
      );

      registry.register(customId, first);
      registry.register(customId, second);

      final secondMatch = registry.getMatching(
        customId,
        const ListenerMatchRequest(
          botId: 'bot-a',
          type: 'button',
          channelId: 'channel-a',
          messageId: 'message-2',
        ),
      );
      final missingMatch = registry.getMatching(
        customId,
        const ListenerMatchRequest(
          botId: 'bot-a',
          type: 'button',
          channelId: 'channel-a',
          messageId: 'message-3',
        ),
      );

      expect(secondMatch, same(second));
      expect(missingMatch, isNull);

      registry.removeEntry(customId, first);
      registry.removeEntry(customId, second);
    });
  });
}

final DateTime _future = DateTime.utc(2099, 1, 1);
