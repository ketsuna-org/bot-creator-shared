import 'package:test/test.dart';

import 'package:bot_creator_shared/actions/executors/operations_expander.dart';

void main() {
  group('Operation Expander', () {
    String resolve(String input) => input;

    test('passes through concrete operations unchanged', () {
      final ops = [
        {'op': 'create', 'width': '100', 'height': '100', 'color': 'red'},
        {'op': 'drawText', 'text': 'Hello', 'x': '10', 'y': '20', 'fontSize': '14', 'color': 'white'},
      ];

      final expanded = expandCanvasOperations(ops, resolve);

      expect(expanded.length, equals(2));
      expect(expanded[0]['op'], equals('create'));
      expect(expanded[1]['op'], equals('drawText'));
    });

    group('conditions', () {
      test('skips operation when condition resolves to false', () {
        final ops = [
          {'op': 'create', 'width': '100', 'height': '100', 'color': 'red'},
          {
            'op': 'drawText',
            'text': 'Conditional',
            'x': '10',
            'y': '20',
            'fontSize': '14',
            'color': 'white',
            'condition': '((isPremium))',
          },
          {'op': 'drawRect', 'x': '0', 'y': '0', 'width': '50', 'height': '50', 'color': 'blue'},
        ];

        final expanded = expandCanvasOperations(
          ops,
          (input) => input == '((isPremium))' ? 'false' : input,
        );

        // drawText should be skipped because condition is falsy
        expect(expanded.length, equals(2));
        expect(expanded[0]['op'], equals('create'));
        expect(expanded[1]['op'], equals('drawRect'));
      });

      test('keeps operation when condition resolves to true', () {
        final ops = [
          {'op': 'create', 'width': '100', 'height': '100', 'color': 'red'},
          {
            'op': 'drawText',
            'text': 'Conditional',
            'x': '10',
            'y': '20',
            'fontSize': '14',
            'color': 'white',
            'condition': '((showText))',
          },
        ];

        final expanded = expandCanvasOperations(
          ops,
          (input) => input == '((showText))' ? 'true' : input,
        );

        expect(expanded.length, equals(2));
        expect(expanded[1]['op'], equals('drawText'));
      });

      test('skips operation when condition is empty string', () {
        final ops = [
          {'op': 'create', 'width': '50', 'height': '50', 'color': 'black'},
          {
            'op': 'drawCircle',
            'x': '25',
            'y': '25',
            'radius': '20',
            'color': 'white',
            'condition': '',
          },
        ];

        final expanded = expandCanvasOperations(ops, resolve);

        expect(expanded.length, equals(1));
        expect(expanded[0]['op'], equals('create'));
      });
    });

    group('forEach', () {
      test('unrolls a forEach loop into N operations', () {
        final ops = [
          {'op': 'create', 'width': '200', 'height': '300', 'color': '#2c2f33'},
          {
            'op': 'forEach',
            'list': '[{"rank":1,"name":"Alice"},{"rank":2,"name":"Bob"},{"rank":3,"name":"Carol"}]',
            'itemTemplate': {
              'op': 'drawText',
              'text': '((item.rank)). ((item.name))',
              'x': '10',
              'y': '((item.index * 24 + 50))',
              'fontSize': '14',
              'color': 'white',
            },
          },
        ];

        final expanded = expandCanvasOperations(ops, resolve);

        // create + 3 drawText ops (one per item)
        expect(expanded.length, equals(4));
        expect(expanded[0]['op'], equals('create'));
        expect(expanded[1]['op'], equals('drawText'));
        expect(expanded[1]['text'], equals('1. Alice'));
        expect(expanded[1]['y'], equals('50'));
        expect(expanded[2]['text'], equals('2. Bob'));
        expect(expanded[2]['y'], equals('74'));
        expect(expanded[3]['text'], equals('3. Carol'));
        expect(expanded[3]['y'], equals('98'));
      });

      test('forEach with comma-separated string list', () {
        final ops = [
          {'op': 'create', 'width': '100', 'height': '100', 'color': 'black'},
          {
            'op': 'forEach',
            'list': 'Alpha,Beta,Gamma',
            'itemTemplate': {
              'op': 'drawText',
              'text': '((item))',
              'x': '0',
              'y': '((item.index * 20))',
              'fontSize': '14',
              'color': 'white',
            },
          },
        ];

        final expanded = expandCanvasOperations(ops, resolve);

        expect(expanded.length, equals(4));
        expect(expanded[1]['text'], equals('Alpha'));
        expect(expanded[2]['text'], equals('Beta'));
        expect(expanded[3]['text'], equals('Gamma'));
      });

      test('forEach with empty list produces no operations', () {
        final ops = [
          {'op': 'create', 'width': '100', 'height': '100', 'color': 'black'},
          {
            'op': 'forEach',
            'list': '[]',
            'itemTemplate': {
              'op': 'drawText',
              'text': '((item))',
              'x': '0',
              'y': '0',
              'fontSize': '14',
              'color': 'white',
            },
          },
        ];

        final expanded = expandCanvasOperations(ops, resolve);

        expect(expanded.length, equals(1));
        expect(expanded[0]['op'], equals('create'));
      });
    });

    group('composition', () {
      test('substitutes composition slots into template operations', () {
        final compositions = <String, List<Map<String, dynamic>>>{
          'welcomeCard': [
            {
              'op': 'create',
              'width': '800',
              'height': '400',
              'color': '#2c2f33',
            },
            {
              'op': 'drawText',
              'text': 'Welcome, \$slot.username!',
              'x': '50',
              'y': '200',
              'fontSize': '48',
              'color': 'white',
            },
          ],
        };

        final ops = [
          {
            'composition': 'welcomeCard',
            'slots': {
              'username': '((author.name))',
              'memberCount': '42',
            },
          },
        ];

        final expanded = expandCanvasOperations(
          ops,
          (input) => input == '((author.name))' ? 'Alice' : input,
          compositions: compositions,
        );

        expect(expanded.length, equals(2));
        expect(expanded[0]['op'], equals('create'));
        expect(expanded[0]['width'], equals('800'));
        expect(expanded[1]['op'], equals('drawText'));
        expect(expanded[1]['text'], equals('Welcome, Alice!'));
      });

      test('unknown composition returns empty list', () {
        final ops = [
          {
            'composition': 'nonexistentTemplate',
            'slots': {'key': 'value'},
          },
        ];

        final expanded = expandCanvasOperations(ops, resolve);

        expect(expanded, isEmpty);
      });

      test('composition without compositions map returns empty', () {
        final ops = [
          {
            'composition': 'welcomeCard',
            'slots': {'key': 'value'},
          },
        ];

        final expanded = expandCanvasOperations(ops, resolve);

        expect(expanded, isEmpty);
      });
    });

    group('edge cases', () {
      test('empty operations list returns empty', () {
        final expanded = expandCanvasOperations([], resolve);
        expect(expanded, isEmpty);
      });

      test('null operations in list are skipped', () {
        final ops = [
          {'op': 'create', 'width': '100', 'height': '100', 'color': 'red'},
          null, // Should be skipped
          {'op': 'drawRect', 'x': '0', 'y': '0', 'width': '50', 'height': '50', 'color': 'blue'},
        ];

        final expanded = expandCanvasOperations(ops, resolve);

        expect(expanded.length, equals(2));
      });

      test('non-Map operations are skipped', () {
        final ops = [
          {'op': 'create', 'width': '100', 'height': '100', 'color': 'red'},
          'not a map', // Should be skipped
          {'op': 'drawRect', 'x': '0', 'y': '0', 'width': '50', 'height': '50', 'color': 'blue'},
        ];

        final expanded = expandCanvasOperations(ops, resolve);

        expect(expanded.length, equals(2));
      });
    });
  });
}
