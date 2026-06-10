import 'package:bot_creator_shared/utils/command_migration.dart';
import 'package:test/test.dart';

void main() {
  group('stripMigratedCommandData', () {
    test('empty list returns false', () {
      expect(stripMigratedCommandData([]), isFalse);
    });

    test('command without data key returns false', () {
      final commands = [<String, dynamic>{'name': 'test'}];
      expect(stripMigratedCommandData(commands), isFalse);
    });

    test('command with data but no response key returns false', () {
      final commands = [
        <String, dynamic>{
          'name': 'test',
          'data': <String, dynamic>{'simpleConfig': 'stuff'},
        },
      ];
      expect(stripMigratedCommandData(commands), isFalse);
    });

    test('command with response but no _migrated returns false', () {
      final commands = [
        <String, dynamic>{
          'name': 'test',
          'data': <String, dynamic>{
            'response': <String, dynamic>{'content': 'hello'},
            'simpleConfig': 'stuff',
          },
        },
      ];
      expect(stripMigratedCommandData(commands), isFalse);
      // Verify keys are still present
      final data = commands[0]['data'] as Map<String, dynamic>;
      expect(data.containsKey('response'), isTrue);
      expect(data.containsKey('simpleConfig'), isTrue);
    });

    test('command with _migrated removes both response and simpleConfig', () {
      final commands = [
        <String, dynamic>{
          'name': 'test',
          'data': <String, dynamic>{
            'response': <String, dynamic>{'_migrated': true, 'content': 'hello'},
            'simpleConfig': 'stuff',
            'otherKey': 42,
          },
        },
      ];
      expect(stripMigratedCommandData(commands), isTrue);
      final data = commands[0]['data'] as Map<String, dynamic>;
      expect(data.containsKey('response'), isFalse);
      expect(data.containsKey('simpleConfig'), isFalse);
      expect(data['otherKey'], equals(42));
    });

    test('_migrated with false value still triggers removal', () {
      final commands = [
        <String, dynamic>{
          'name': 'test',
          'data': <String, dynamic>{
            'response': <String, dynamic>{'_migrated': false},
            'simpleConfig': 'stuff',
          },
        },
      ];
      expect(stripMigratedCommandData(commands), isTrue);
      final data = commands[0]['data'] as Map<String, dynamic>;
      expect(data.containsKey('response'), isFalse);
      expect(data.containsKey('simpleConfig'), isFalse);
    });

    test('only response removed when _migrated present but no simpleConfig', () {
      final commands = [
        <String, dynamic>{
          'name': 'test',
          'data': <String, dynamic>{
            'response': <String, dynamic>{'_migrated': true},
            'otherKey': 'preserved',
          },
        },
      ];
      expect(stripMigratedCommandData(commands), isTrue);
      final data = commands[0]['data'] as Map<String, dynamic>;
      expect(data.containsKey('response'), isFalse);
      expect(data.containsKey('simpleConfig'), isFalse);
      expect(data['otherKey'], equals('preserved'));
    });

    test('multiple commands, only migrated ones are stripped', () {
      final commands = [
        <String, dynamic>{
          'name': 'cmd-a',
          'data': <String, dynamic>{
            'response': <String, dynamic>{'_migrated': true, 'content': 'a'},
            'simpleConfig': 'a-simple',
          },
        },
        <String, dynamic>{
          'name': 'cmd-b',
          'data': <String, dynamic>{
            'response': <String, dynamic>{'content': 'b'},
            'simpleConfig': 'b-simple',
          },
        },
      ];
      expect(stripMigratedCommandData(commands), isTrue);
      // cmd-a: stripped
      final dataA = commands[0]['data'] as Map<String, dynamic>;
      expect(dataA.containsKey('response'), isFalse);
      expect(dataA.containsKey('simpleConfig'), isFalse);
      // cmd-b: preserved
      final dataB = commands[1]['data'] as Map<String, dynamic>;
      expect(dataB.containsKey('response'), isTrue);
      expect(dataB.containsKey('simpleConfig'), isTrue);
    });

    test('response is not a map → skipped', () {
      final commands = [
        <String, dynamic>{
          'name': 'test',
          'data': <String, dynamic>{
            'response': 'not-a-map',
            'simpleConfig': 'stuff',
          },
        },
      ];
      expect(stripMigratedCommandData(commands), isFalse);
    });

    test('data is not a map → skipped', () {
      final commands = [
        <String, dynamic>{
          'name': 'test',
          'data': 'not-a-map',
        },
      ];
      expect(stripMigratedCommandData(commands), isFalse);
    });
  });
}
