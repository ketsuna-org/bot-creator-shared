import 'package:bot_creator_shared/utils/command_autocomplete.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeSerializedAutocompleteConfig', () {
    test('normalizes entry point and trims argument keys', () {
      final config = normalizeSerializedAutocompleteConfig(<String, dynamic>{
        'workflow': 'country_search',
        'entryPoint': '',
        'arguments': <String, dynamic>{' dataset ': 'countries'},
      });

      expect(config, <String, dynamic>{
        'enabled': true,
        'workflow': 'country_search',
        'entryPoint': 'main',
        'arguments': <String, dynamic>{'dataset': 'countries'},
      });
    });
  });

  group('resolveAutocompleteConfigForInteraction', () {
    test('finds focused option config through subcommand nesting', () {
      final config = resolveAutocompleteConfigForInteraction(
        storedOptions: <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'subCommandGroup',
            'name': 'admin',
            'options': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'subCommand',
                'name': 'search',
                'options': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'string',
                    'name': 'country',
                    'autocomplete': <String, dynamic>{
                      'enabled': true,
                      'workflow': 'country_search',
                      'entryPoint': 'main',
                      'arguments': <String, dynamic>{'dataset': 'countries'},
                    },
                  },
                ],
              },
            ],
          },
        ],
        interactionOptions: <InteractionOption>[
          InteractionOption(
            name: 'admin',
            type: CommandOptionType.subCommandGroup,
            value: null,
            options: <InteractionOption>[
              InteractionOption(
                name: 'search',
                type: CommandOptionType.subCommand,
                value: null,
                options: <InteractionOption>[
                  InteractionOption(
                    name: 'country',
                    type: CommandOptionType.string,
                    value: 'fr',
                    options: null,
                    isFocused: true,
                  ),
                ],
                isFocused: null,
              ),
            ],
            isFocused: null,
          ),
        ],
      );

      expect(config, <String, dynamic>{
        'enabled': true,
        'workflow': 'country_search',
        'entryPoint': 'main',
        'arguments': <String, dynamic>{'dataset': 'countries'},
      });
    });
  });
}
