import 'package:test/test.dart';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/types/component.dart';
import 'package:bot_creator_shared/actions/send_component_v2.dart';

void main() {
  group('send_component_v2 buildComponentNode', () {
    test('ModalTextInputNode alone builds with label', () {
      final node = ModalTextInputNode(
        customId: 'input_id',
        label: 'My Label',
        style: BcTextInputStyle.short,
        placeholder: 'Enter text',
        value: 'default',
        required: true,
        minLength: 5,
        maxLength: 10,
      );

      final builder = buildComponentNode(node, (s) => s);
      expect(builder, isA<TextInputBuilder>());
      final map = builder.build();
      expect(map['label'], 'My Label');
      expect(map['custom_id'], 'input_id');
      expect(map['placeholder'], 'Enter text');
      expect(map['value'], 'default');
      expect(map['required'], true);
      expect(map['min_length'], 5);
      expect(map['max_length'], 10);
    });

    test('ModalTextInputNode wrapped inside LabelNode builds without label', () {
      final node = LabelNode(
        label: 'Outer Label',
        description: 'Outer Desc',
        component: ModalTextInputNode(
          customId: 'input_id',
          label: 'My Label',
          style: BcTextInputStyle.short,
          placeholder: 'Enter text',
          value: 'default',
          required: true,
          minLength: 5,
          maxLength: 10,
        ),
      );

      final builder = buildComponentNode(node, (s) => s);
      expect(builder, isA<LabelComponentBuilder>());
      final map = builder.build();
      expect(map['label'], 'Outer Label');
      expect(map['description'], 'Outer Desc');

      // The nested component is under 'component' key in LabelComponentBuilder
      final nestedComponentMap = map['component'] as Map<String, dynamic>;
      expect(nestedComponentMap.containsKey('label'), isFalse);
      expect(nestedComponentMap['custom_id'], 'input_id');
      expect(nestedComponentMap['placeholder'], 'Enter text');
      expect(nestedComponentMap['value'], 'default');
      expect(nestedComponentMap['required'], true);
      expect(nestedComponentMap['min_length'], 5);
      expect(nestedComponentMap['max_length'], 10);
    });
  });
}
