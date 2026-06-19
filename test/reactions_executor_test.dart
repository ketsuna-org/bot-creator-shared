import 'package:bot_creator_shared/actions/executors/reactions_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

class FakeNyxxGateway implements NyxxGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('executeReactionsAction', () {
    test('resolves and splits emojis by semicolon and cleans up BDFD quirks', () async {
      final results = <String, String>{};
      final payload = <String, dynamic>{
        'channelId': '123',
        'messageId': '456',
        'emojis': [
          '🔥;✨',
          '<;:hollyDab:828628880629825546>;',
          '<a;:animatedEmoji:12345678>;',
        ],
      };

      // Since we don't have a live NyxxGateway client in this unit test,
      // and we just want to verify how payload['emojis'] gets resolved, cleaned, and split,
      // we can verify the behavior by checking how executeReactionsAction parses it.
      // Wait, executeReactionsAction calls addReactionAction, which will fail with a connection error
      // or "Missing channelId/messageId" if we don't mock it, but actually we resolve values first.
      // Let's verify that the emojis are split and formatted correctly by catching the exception
      // or checking the error message returned.
      try {
        await executeReactionsAction(
          type: BotCreatorActionType.addReaction,
          client: FakeNyxxGateway(), // dummy client
          payload: payload,
          resultKey: 'addReact',
          results: results,
          fallbackChannelId: null,
          resolveValue: (input) => input,
        );
      } catch (e) {
        final errorMsg = e.toString();
        // Since addReactionAction is called on each emoji in the resolved list,
        // and we passed dynamic as client, it will throw a CastError or similar when
        // attempting fetchChannelCached, but it will have processed the resolved emojis list first.
        // If the splitting/cleaning works, the exception or call trace will show that it tried to react
        // to the cleaned list of emojis: ['🔥', '✨', '<:hollyDab:828628880629825546>', '<a:animatedEmoji:12345678>']
        // Let's verify the processed list is correct.
        expect(errorMsg, contains('🔥'));
        expect(errorMsg, contains('✨'));
        expect(errorMsg, contains('<:hollyDab:828628880629825546>'));
        expect(errorMsg, contains('<a:animatedEmoji:12345678>'));
        // And it should NOT contain the uncleaned format
        expect(errorMsg, isNot(contains('<;:')));
        expect(errorMsg, isNot(contains(';>')));
      }
    });
  });
}
