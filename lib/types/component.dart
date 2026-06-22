// Component V2 and Modal type definitions for BotCreator

enum BcButtonStyle { primary, secondary, success, danger, link, premium }

enum BcTextInputStyle { short, paragraph }

enum BcSelectMenuType { string, user, role, mentionable, channel }

enum ComponentV2Type {
  actionRow,
  button,
  stringSelect,
  textInput,
  userSelect,
  roleSelect,
  mentionableSelect,
  channelSelect,
  categorySelect,
  voiceSelect,
  section,
  textDisplay,
  thumbnail,
  mediaGallery,
  file,
  separator,
  container,
  label,
  fileUpload,
  radioGroup,
  checkboxGroup,
  checkbox,
}

abstract class ComponentNode {
  ComponentV2Type get type;
  Map<String, dynamic> toJson();

  static String generateId([String prefix = 'id']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomSuffix =
        (1000 + (DateTime.now().microsecondsSinceEpoch % 9000)).toString();
    return '${prefix}_$timestamp$randomSuffix';
  }

  static ComponentNode fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = ComponentV2Type.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => ComponentV2Type.actionRow, // default fallback
    );

    switch (type) {
      case ComponentV2Type.actionRow:
        return ActionRowNode.fromJson(json);
      case ComponentV2Type.button:
        return ButtonNode.fromJson(json);
      case ComponentV2Type.stringSelect:
        return SelectMenuNode.fromJson(json);
      case ComponentV2Type.textInput:
        return ModalTextInputNode.fromJson(json);
      case ComponentV2Type.userSelect:
      case ComponentV2Type.roleSelect:
      case ComponentV2Type.mentionableSelect:
      case ComponentV2Type.channelSelect:
      case ComponentV2Type.categorySelect:
      case ComponentV2Type.voiceSelect:
        return SelectMenuNode.fromJson(json);
      case ComponentV2Type.section:
        return SectionNode.fromJson(json);
      case ComponentV2Type.textDisplay:
        return TextDisplayNode.fromJson(json);
      case ComponentV2Type.thumbnail:
        return ThumbnailNode.fromJson(json);
      case ComponentV2Type.mediaGallery:
        return MediaGalleryNode.fromJson(json);
      case ComponentV2Type.file:
        return FileNode.fromJson(json);
      case ComponentV2Type.separator:
        return SeparatorNode.fromJson(json);
      case ComponentV2Type.container:
        return ContainerNode.fromJson(json);
      case ComponentV2Type.label:
        return LabelNode.fromJson(json);
      case ComponentV2Type.fileUpload:
        return FileUploadNode.fromJson(json);
      case ComponentV2Type.radioGroup:
        return RadioGroupNode.fromJson(json);
      case ComponentV2Type.checkboxGroup:
        return CheckboxGroupNode.fromJson(json);
      case ComponentV2Type.checkbox:
        return CheckboxNode.fromJson(json);
    }
  }
}

class ActionRowNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.actionRow;

  List<ComponentNode> components;

  ActionRowNode({this.components = const []});

  factory ActionRowNode.fromJson(Map<String, dynamic> json) {
    return ActionRowNode(
      components:
          (json['components'] as List? ?? [])
              .whereType<Map>()
              .map((c) => ComponentNode.fromJson(Map<String, dynamic>.from(c)))
              .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'components': components.map((c) => c.toJson()).toList(),
  };
}

class ButtonNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.button;

  String label;
  BcButtonStyle style;
  String customId;
  String url;
  String emoji;
  String disabled;
  String skuId;
  /// Inline actions that execute when this button is clicked.
  /// Replaces the legacy workflowName/workflowEntryPoint/workflowArguments.
  List<Map<String, dynamic>> actions;

  ButtonNode({
    this.label = 'Button',
    this.style = BcButtonStyle.primary,
    String? customId,
    this.url = '',
    this.emoji = '',
    this.disabled = '',
    this.skuId = '',
    this.actions = const [],
  }) : customId = customId ?? ComponentNode.generateId('btn');

  factory ButtonNode.fromJson(Map<String, dynamic> json) {
    // Prefer inline actions; fall back to legacy workflow for backward compat.
    List<Map<String, dynamic>> actions;
    final legacyWorkflowName =
        (json['workflowName'] ?? json['onClickWorkflow'] ?? '').toString();
    if (json['actions'] is List) {
      actions = (json['actions'] as List)
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList();
    } else if (legacyWorkflowName.isNotEmpty) {
      actions = [
        {
          'type': 'callWorkflow',
          'payload': {
            'workflowName': legacyWorkflowName,
            'entryPoint':
                (json['workflowEntryPoint'] ??
                        json['onClickEntryPoint'] ??
                        '')
                    .toString(),
            'arguments':
                Map<String, dynamic>.from(
                  (json['workflowArguments'] as Map?)
                          ?.cast<String, dynamic>() ??
                      const {},
                ),
          },
        },
      ];
    } else {
      actions = const [];
    }

    return ButtonNode(
      label: (json['label'] ?? '').toString(),
      style: BcButtonStyle.values.firstWhere(
        (s) => s.name == json['style'],
        orElse: () => BcButtonStyle.primary,
      ),
      customId: (json['customId'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      disabled: _parseDisabled(json['disabled']),
      skuId: (json['skuId'] ?? '').toString(),
      actions: actions,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'label': label,
    'style': style.name,
    'customId': customId,
    'url': url,
    'emoji': emoji,
    'disabled': disabled,
    if (skuId.isNotEmpty) 'skuId': skuId,
    if (actions.isNotEmpty) 'actions': actions,
  };
}

/// Handles backward-compatible parsing of the `disabled` field.
/// If it's already a String, use it directly.
/// If it's a bool `true`, migrate to the string `'true'`.
/// Otherwise return an empty string.
String _parseDisabled(dynamic value) {
  if (value is String) return value;
  if (value == true) return 'true';
  return '';
}

class SelectMenuOption {
  String label;
  String value;
  String description;
  dynamic
  emoji; // Can be a String (standard) or Map<String, dynamic> (id, name, animated)
  bool isDefault;

  SelectMenuOption({
    this.label = '',
    this.value = '',
    this.description = '',
    this.emoji,
    this.isDefault = false,
  });

  factory SelectMenuOption.fromJson(Map<String, dynamic> json) {
    return SelectMenuOption(
      label: (json['label'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      emoji: json['emoji'],
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'description': description,
    if (emoji != null) 'emoji': emoji,
    'isDefault': isDefault,
  };
}

class SelectMenuNode extends ComponentNode {
  @override
  final ComponentV2Type type;

  String customId;
  String placeholder;
  List<SelectMenuOption> options;
  int minValues;
  int maxValues;
  String disabled;
  /// Inline actions that execute when an option is selected.
  /// Replaces the legacy workflowName/workflowEntryPoint/workflowArguments.
  List<Map<String, dynamic>> actions;

  SelectMenuNode({
    this.type = ComponentV2Type.stringSelect,
    String? customId,
    this.placeholder = 'Select an option...',
    this.options = const [],
    this.minValues = 1,
    this.maxValues = 1,
    this.disabled = '',
    this.actions = const [],
  }) : customId = customId ?? ComponentNode.generateId('select');

  factory SelectMenuNode.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    var resolvedType = ComponentV2Type.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => ComponentV2Type.stringSelect,
    );
    if (typeStr == 'selectMenu') {
      final menuType = json['menuType'] as String?;
      if (menuType == 'channel') resolvedType = ComponentV2Type.channelSelect;
      if (menuType == 'user') resolvedType = ComponentV2Type.userSelect;
      if (menuType == 'role') resolvedType = ComponentV2Type.roleSelect;
      if (menuType == 'mentionable') resolvedType = ComponentV2Type.mentionableSelect;
      if (menuType == 'category') resolvedType = ComponentV2Type.categorySelect;
      if (menuType == 'voice') resolvedType = ComponentV2Type.voiceSelect;
    }

    // Prefer inline actions; fall back to legacy workflow for backward compat.
    List<Map<String, dynamic>> actions;
    final legacyWorkflowName =
        (json['workflowName'] ?? json['onSelectWorkflow'] ?? '').toString();
    if (json['actions'] is List) {
      actions = (json['actions'] as List)
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList();
    } else if (legacyWorkflowName.isNotEmpty) {
      actions = [
        {
          'type': 'callWorkflow',
          'payload': {
            'workflowName': legacyWorkflowName,
            'entryPoint':
                (json['workflowEntryPoint'] ??
                        json['onSelectEntryPoint'] ??
                        '')
                    .toString(),
            'arguments':
                Map<String, dynamic>.from(
                  (json['workflowArguments'] as Map?)
                          ?.cast<String, dynamic>() ??
                      const {},
                ),
          },
        },
      ];
    } else {
      actions = const [];
    }

    return SelectMenuNode(
      type: resolvedType,
      customId: (json['customId'] ?? '').toString(),
      placeholder: (json['placeholder'] ?? 'Select an option...').toString(),
      options:
          (json['options'] as List? ?? [])
              .whereType<Map>()
              .map(
                (o) => SelectMenuOption.fromJson(Map<String, dynamic>.from(o)),
              )
              .toList(),
      minValues: json['minValues'] as int? ?? 1,
      maxValues: json['maxValues'] as int? ?? 1,
      disabled: _parseDisabled(json['disabled']),
      actions: actions,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'placeholder': placeholder,
    'options': options.map((o) => o.toJson()).toList(),
    'minValues': minValues,
    'maxValues': maxValues,
    'disabled': disabled,
    if (actions.isNotEmpty) 'actions': actions,
  };
}

class SectionNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.section;

  List<TextDisplayNode> components;
  ComponentNode? accessory;

  SectionNode({this.components = const [], this.accessory});

  factory SectionNode.fromJson(Map<String, dynamic> json) {
    ComponentNode? parseAccessory(dynamic accJson) {
      if (accJson is Map) {
        return ComponentNode.fromJson(Map<String, dynamic>.from(accJson));
      }
      return null;
    }

    return SectionNode(
      components:
          (json['components'] as List? ?? [])
              .whereType<Map>()
              .map(
                (c) => TextDisplayNode.fromJson(Map<String, dynamic>.from(c)),
              )
              .toList(),
      accessory: parseAccessory(json['accessory']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'components': components.map((c) => c.toJson()).toList(),
    if (accessory != null) 'accessory': accessory!.toJson(),
  };
}

class TextDisplayNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.textDisplay;

  String content;

  TextDisplayNode({this.content = ''});

  factory TextDisplayNode.fromJson(Map<String, dynamic> json) {
    return TextDisplayNode(content: (json['content'] ?? '').toString());
  }

  @override
  Map<String, dynamic> toJson() => {'type': type.name, 'content': content};
}

class UnfurledMediaItemNode {
  String url;
  UnfurledMediaItemNode({this.url = ''});

  factory UnfurledMediaItemNode.fromJson(Map<String, dynamic> json) {
    return UnfurledMediaItemNode(url: (json['url'] ?? '').toString());
  }

  Map<String, dynamic> toJson() => {'url': url};
}

class ThumbnailNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.thumbnail;

  UnfurledMediaItemNode media;
  String description;
  bool isSpoiler;

  ThumbnailNode({
    UnfurledMediaItemNode? media,
    this.description = '',
    this.isSpoiler = false,
  }) : media = media ?? UnfurledMediaItemNode();

  factory ThumbnailNode.fromJson(Map<String, dynamic> json) {
    return ThumbnailNode(
      media:
          json['media'] is Map
              ? UnfurledMediaItemNode.fromJson(
                Map<String, dynamic>.from(json['media']),
              )
              : UnfurledMediaItemNode(),
      description: (json['description'] ?? '').toString(),
      isSpoiler: json['isSpoiler'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'media': media.toJson(),
    'description': description,
    'isSpoiler': isSpoiler,
  };
}

class MediaGalleryItemNode {
  UnfurledMediaItemNode media;
  String description;
  bool isSpoiler;

  MediaGalleryItemNode({
    UnfurledMediaItemNode? media,
    this.description = '',
    this.isSpoiler = false,
  }) : media = media ?? UnfurledMediaItemNode();

  factory MediaGalleryItemNode.fromJson(Map<String, dynamic> json) {
    return MediaGalleryItemNode(
      media:
          json['media'] is Map
              ? UnfurledMediaItemNode.fromJson(
                Map<String, dynamic>.from(json['media']),
              )
              : UnfurledMediaItemNode(),
      description: (json['description'] ?? '').toString(),
      isSpoiler: json['isSpoiler'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'media': media.toJson(),
    'description': description,
    'isSpoiler': isSpoiler,
  };
}

class MediaGalleryNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.mediaGallery;

  List<MediaGalleryItemNode> items;

  MediaGalleryNode({this.items = const []});

  factory MediaGalleryNode.fromJson(Map<String, dynamic> json) {
    return MediaGalleryNode(
      items:
          (json['items'] as List? ?? [])
              .whereType<Map>()
              .map(
                (i) =>
                    MediaGalleryItemNode.fromJson(Map<String, dynamic>.from(i)),
              )
              .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class SeparatorNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.separator;

  bool isDivider;
  int spacing; // 1 = small, 2 = large

  SeparatorNode({this.isDivider = true, this.spacing = 1});

  factory SeparatorNode.fromJson(Map<String, dynamic> json) {
    return SeparatorNode(
      isDivider: json['isDivider'] == true,
      spacing: json['spacing'] as int? ?? 1,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'isDivider': isDivider,
    'spacing': spacing,
  };
}

class FileNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.file;

  UnfurledMediaItemNode file;
  bool isSpoiler;

  FileNode({UnfurledMediaItemNode? file, this.isSpoiler = false})
    : file = file ?? UnfurledMediaItemNode();

  factory FileNode.fromJson(Map<String, dynamic> json) {
    return FileNode(
      file:
          json['file'] is Map
              ? UnfurledMediaItemNode.fromJson(
                Map<String, dynamic>.from(json['file']),
              )
              : UnfurledMediaItemNode(),
      isSpoiler: json['isSpoiler'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'file': file.toJson(),
    'isSpoiler': isSpoiler,
  };
}

class ContainerNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.container;

  List<ComponentNode> components;
  String accentColor; // hex string e.g. "#FF0000"
  bool isSpoiler;

  ContainerNode({
    this.components = const [],
    this.accentColor = '',
    this.isSpoiler = false,
  });

  factory ContainerNode.fromJson(Map<String, dynamic> json) {
    return ContainerNode(
      components:
          (json['components'] as List? ?? [])
              .whereType<Map>()
              .map((c) => ComponentNode.fromJson(Map<String, dynamic>.from(c)))
              .toList(),
      accentColor: (json['accentColor'] ?? '').toString(),
      isSpoiler: json['isSpoiler'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'components': components.map((c) => c.toJson()).toList(),
    'accentColor': accentColor,
    'isSpoiler': isSpoiler,
  };
}

class LabelNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.label;

  String label;
  String description;
  ComponentNode? component;

  LabelNode({this.label = '', this.description = '', this.component});

  factory LabelNode.fromJson(Map<String, dynamic> json) {
    return LabelNode(
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      component:
          json['component'] is Map
              ? ComponentNode.fromJson(
                Map<String, dynamic>.from(json['component']),
              )
              : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'label': label,
    'description': description,
    if (component != null) 'component': component!.toJson(),
  };
}

class FileUploadNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.fileUpload;

  String customId;
  int minValues;
  int maxValues;
  bool isRequired;

  FileUploadNode({
    String? customId,
    this.minValues = 1,
    this.maxValues = 1,
    this.isRequired = false,
  }) : customId = customId ?? ComponentNode.generateId('upload');

  factory FileUploadNode.fromJson(Map<String, dynamic> json) {
    return FileUploadNode(
      customId: (json['customId'] ?? '').toString(),
      minValues: json['minValues'] as int? ?? 1,
      maxValues: json['maxValues'] as int? ?? 1,
      isRequired: json['isRequired'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'minValues': minValues,
    'maxValues': maxValues,
    'isRequired': isRequired,
  };
}

class RadioGroupOptionNode {
  String value;
  String label;
  String description;
  bool isDefault;

  RadioGroupOptionNode({
    this.value = '',
    this.label = '',
    this.description = '',
    this.isDefault = false,
  });

  factory RadioGroupOptionNode.fromJson(Map<String, dynamic> json) {
    return RadioGroupOptionNode(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'label': label,
    'description': description,
    'isDefault': isDefault,
  };
}

class RadioGroupNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.radioGroup;

  String customId;
  List<RadioGroupOptionNode> options;
  bool isRequired;

  RadioGroupNode({
    String? customId,
    this.options = const [],
    this.isRequired = false,
  }) : customId = customId ?? ComponentNode.generateId('radio');

  factory RadioGroupNode.fromJson(Map<String, dynamic> json) {
    return RadioGroupNode(
      customId: (json['customId'] ?? '').toString(),
      options:
          (json['options'] as List? ?? [])
              .whereType<Map>()
              .map(
                (o) =>
                    RadioGroupOptionNode.fromJson(Map<String, dynamic>.from(o)),
              )
              .toList(),
      isRequired: json['isRequired'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'options': options.map((o) => o.toJson()).toList(),
    'isRequired': isRequired,
  };
}

class CheckboxGroupOptionNode {
  String value;
  String label;
  String description;
  bool isDefault;

  CheckboxGroupOptionNode({
    this.value = '',
    this.label = '',
    this.description = '',
    this.isDefault = false,
  });

  factory CheckboxGroupOptionNode.fromJson(Map<String, dynamic> json) {
    return CheckboxGroupOptionNode(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'label': label,
    'description': description,
    'isDefault': isDefault,
  };
}

class CheckboxGroupNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.checkboxGroup;

  String customId;
  List<CheckboxGroupOptionNode> options;
  int minValues;
  int maxValues;
  bool isRequired;

  CheckboxGroupNode({
    String? customId,
    this.options = const [],
    this.minValues = 1,
    this.maxValues = 1,
    this.isRequired = false,
  }) : customId = customId ?? ComponentNode.generateId('check_group');

  factory CheckboxGroupNode.fromJson(Map<String, dynamic> json) {
    return CheckboxGroupNode(
      customId: (json['customId'] ?? '').toString(),
      options:
          (json['options'] as List? ?? [])
              .whereType<Map>()
              .map(
                (o) => CheckboxGroupOptionNode.fromJson(
                  Map<String, dynamic>.from(o),
                ),
              )
              .toList(),
      minValues: json['minValues'] as int? ?? 1,
      maxValues: json['maxValues'] as int? ?? 1,
      isRequired: json['isRequired'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'options': options.map((o) => o.toJson()).toList(),
    'minValues': minValues,
    'maxValues': maxValues,
    'isRequired': isRequired,
  };
}

class CheckboxNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.checkbox;

  String customId;
  bool isDefault;

  CheckboxNode({String? customId, this.isDefault = false})
    : customId = customId ?? ComponentNode.generateId('check');

  factory CheckboxNode.fromJson(Map<String, dynamic> json) {
    return CheckboxNode(
      customId: (json['customId'] ?? '').toString(),
      isDefault: json['isDefault'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'isDefault': isDefault,
  };
}

class ComponentV2Definition {
  String content;
  List<ComponentNode> components;
  bool ephemeral;

  ComponentV2Definition({
    this.content = '',
    this.components = const [],
    this.ephemeral = false,
  });

  /// Returns true if this definition contains components that REQUIRE the IS_COMPONENTS_V2 flag.
  /// Standard ActionRows with Buttons/Selects are considered V1 (legacy).
  bool get isRichV2 {
    for (final node in components) {
      if (node is! ActionRowNode) return true;
      for (final child in node.components) {
        if (child is! ButtonNode && child is! SelectMenuNode) return true;
      }
    }
    return false;
  }

  factory ComponentV2Definition.fromJson(Map<String, dynamic> json) {
    List<ComponentNode> extractedComponents = [];

    // Parse the new v2 standard format
    if (json.containsKey('components') && json['components'] is List) {
      extractedComponents =
          (json['components'] as List)
              .whereType<Map>()
              .map((c) => ComponentNode.fromJson(Map<String, dynamic>.from(c)))
              .toList();
    }
    // Flat items format produced by the BDFD transpiler.
    // Reconstructs the hierarchy: buttons → ActionRows, selects → ActionRows,
    // layout components (container, section, thumbnail, etc.) → direct.
    else if (json.containsKey('items')) {
      ActionRowNode? currentRow;
      for (final rawItem in (json['items'] as List? ?? []).whereType<Map>()) {
        final item = Map<String, dynamic>.from(rawItem);
        final type = item['type']?.toString() ?? '';
        switch (type) {
          case 'button':
            final newRow = item['newRow'] == true;
            if (newRow || currentRow == null) {
              currentRow = ActionRowNode(components: []);
              extractedComponents.add(currentRow);
            }
            currentRow.components.add(ButtonNode.fromJson(item));
          case 'selectMenu':
            currentRow = null;
            final menu = SelectMenuNode.fromJson(item);
            extractedComponents.add(ActionRowNode(components: [menu]));
          case 'selectMenuOption':
            // Append to the SelectMenu in the most recent ActionRow that
            // holds the matching menuId (or the last select menu if unset).
            final menuId = item['menuId']?.toString() ?? '';
            for (var i = extractedComponents.length - 1; i >= 0; i--) {
              final node = extractedComponents[i];
              if (node is! ActionRowNode) continue;
              for (final child in node.components) {
                if (child is SelectMenuNode &&
                    (child.customId == menuId || menuId.isEmpty)) {
                  child.options.add(SelectMenuOption.fromJson(item));
                  break;
                }
              }
              break;
            }
          case 'separator':
            currentRow = null;
            final divider = item['divider'];
            final isDivider =
                divider is bool
                    ? divider
                    : (divider?.toString().toLowerCase() == 'true' ||
                        divider?.toString().toLowerCase() == 'yes');
            final spacingRaw = item['spacing'];
            final spacing =
                spacingRaw is int
                    ? spacingRaw
                    : int.tryParse(spacingRaw?.toString() ?? '1') ?? 1;
            extractedComponents.add(
              SeparatorNode(isDivider: isDivider, spacing: spacing),
            );
          case 'textDisplay':
            currentRow = null;
            extractedComponents.add(
              TextDisplayNode(content: (item['content'] ?? '').toString()),
            );
          case 'container':
            currentRow = null;
            extractedComponents.add(
              ContainerNode(
                accentColor:
                    (item['accentColor'] ?? item['color'] ?? '').toString(),
              ),
            );
          case 'section':
            currentRow = null;
            extractedComponents.add(
              SectionNode(
                components: [
                  TextDisplayNode(content: (item['content'] ?? '').toString()),
                ],
              ),
            );
          case 'thumbnail':
            currentRow = null;
            extractedComponents.add(
              ThumbnailNode(
                media: UnfurledMediaItemNode(
                  url: (item['url'] ?? '').toString(),
                ),
              ),
            );
          case 'mediaGallery':
            currentRow = null;
            final galleryItems = (item['items'] as List? ?? [])
                .whereType<Map>()
                .map(
                  (i) => MediaGalleryItemNode(
                    media: UnfurledMediaItemNode(
                      url: (i['url'] ?? '').toString(),
                    ),
                    description: (i['description'] ?? '').toString(),
                  ),
                )
                .toList(growable: true);
            extractedComponents.add(MediaGalleryNode(items: galleryItems));
          case 'file':
            currentRow = null;
            extractedComponents.add(
              FileNode(
                file: UnfurledMediaItemNode(
                  url: (item['url'] ?? '').toString(),
                ),
                isSpoiler: item['spoiler'] == true,
              ),
            );
          default:
            // Unknown item type — skip.
            break;
        }
      }
    }
    // Fallback parser for the legacy rows format
    else if (json.containsKey('rows')) {
      final rows = (json['rows'] as List? ?? []).whereType<Map>();
      for (final r in rows) {
        final buttons =
            (r['buttons'] as List? ?? [])
                .whereType<Map>()
                .map((b) => ButtonNode.fromJson(Map<String, dynamic>.from(b)))
                .toList();
        final selectMenuStr = r['selectMenu'] as Map?;
        SelectMenuNode? selectMenu;
        if (selectMenuStr != null) {
          selectMenu = SelectMenuNode.fromJson(
            Map<String, dynamic>.from(selectMenuStr),
          );
        }

        final actionRow = ActionRowNode(components: [...buttons]);
        if (selectMenu != null) actionRow.components.add(selectMenu);

        if (actionRow.components.isNotEmpty) {
          extractedComponents.add(actionRow);
        }
      }
    }

    return ComponentV2Definition(
      content: (json['content'] ?? '').toString(),
      components: extractedComponents,
      ephemeral: json['ephemeral'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'content': content,
    'components': components.map((c) => c.toJson()).toList(),
    'ephemeral': ephemeral,
  };
}

class ModalTextInputNode extends ComponentNode {
  @override
  ComponentV2Type get type => ComponentV2Type.textInput;

  String customId;
  BcTextInputStyle style;
  String label;
  String placeholder;
  String value;
  bool required;
  int? minLength;
  int? maxLength;

  ModalTextInputNode({
    String? customId,
    this.style = BcTextInputStyle.short,
    this.label = '',
    this.placeholder = '',
    this.value = '',
    this.required = false,
    this.minLength,
    this.maxLength,
  }) : customId = customId ?? ComponentNode.generateId('input');

  factory ModalTextInputNode.fromJson(Map<String, dynamic> json) {
    return ModalTextInputNode(
      customId: (json['customId'] ?? '').toString(),
      style: BcTextInputStyle.values.firstWhere(
        (s) => s.name == json['style'],
        orElse: () => BcTextInputStyle.short,
      ),
      label: (json['label'] ?? '').toString(),
      placeholder: (json['placeholder'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      required: json['required'] == true,
      minLength: json['minLength'] as int?,
      maxLength: json['maxLength'] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'customId': customId,
    'style': style.name,
    'label': label,
    'placeholder': placeholder,
    'value': value,
    'required': required,
    if (minLength != null) 'minLength': minLength,
    if (maxLength != null) 'maxLength': maxLength,
  };
}

/// Legacy text-input definition used only by the legacy [ModalDefinition.inputs]
/// format.  Prefer [ModalTextInputNode] (wrapped in a [LabelNode]) for new code.
class ModalTextInputDefinition {
  String customId;
  String label;
  BcTextInputStyle style;
  String placeholder;
  String defaultValue;
  bool required;
  int? minLength;
  int? maxLength;

  ModalTextInputDefinition({
    String? customId,
    this.label = '',
    this.style = BcTextInputStyle.short,
    this.placeholder = '',
    this.defaultValue = '',
    this.required = false,
    this.minLength,
    this.maxLength,
  }) : customId = customId ?? ComponentNode.generateId('input');

  factory ModalTextInputDefinition.fromJson(Map<String, dynamic> json) {
    return ModalTextInputDefinition(
      customId: (json['customId'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      style: BcTextInputStyle.values.firstWhere(
        (s) => s.name == json['style'],
        orElse: () => BcTextInputStyle.short,
      ),
      placeholder: (json['placeholder'] ?? '').toString(),
      defaultValue: (json['defaultValue'] ?? '').toString(),
      required: json['required'] == true,
      minLength: json['minLength'] as int?,
      maxLength: json['maxLength'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'customId': customId,
    'label': label,
    'style': style.name,
    'placeholder': placeholder,
    'defaultValue': defaultValue,
    'required': required,
    if (minLength != null) 'minLength': minLength,
    if (maxLength != null) 'maxLength': maxLength,
  };
}

class ModalDefinition {
  String title;
  String customId;
  /// Legacy text-input-only modal inputs.  Still supported for backward
  /// compatibility but `components` is the preferred format going forward.
  List<ModalTextInputDefinition> inputs;
  /// Generic modal components.  Each entry is a [LabelNode] wrapping a
  /// modal-eligible component: TextInput placeholder, SelectMenuNode (any
  /// select type), FileUploadNode, RadioGroupNode, CheckboxGroupNode, or
  /// CheckboxNode.
  ///
  /// When non-empty this takes priority over [inputs] at send time.
  List<ComponentNode> components;
  /// Inline actions that execute when the modal is submitted.
  /// Replaces the legacy onSubmitWorkflow/onSubmitEntryPoint/onSubmitArguments.
  List<Map<String, dynamic>> actions;

  ModalDefinition({
    this.title = '',
    String? customId,
    this.inputs = const [],
    this.components = const [],
    this.actions = const [],
  }) : customId = customId ?? ComponentNode.generateId('modal');

  /// Returns true when this modal uses the new [components]-based format
  /// (Label wrappers around any modal-eligible component) rather than the
  /// legacy [inputs]-only format.
  bool get hasComponentsV2 => components.isNotEmpty;

  factory ModalDefinition.fromJson(Map<String, dynamic> json) {
    // Prefer inline actions; fall back to legacy workflow for backward compat.
    List<Map<String, dynamic>> actions;
    final legacyWorkflow = json['onSubmitWorkflow']?.toString() ?? '';
    if (json['actions'] is List) {
      actions = (json['actions'] as List)
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList();
    } else if (legacyWorkflow.isNotEmpty) {
      actions = [
        {
          'type': 'callWorkflow',
          'payload': {
            'workflowName': legacyWorkflow,
            'entryPoint':
                (json['onSubmitEntryPoint'] ?? '').toString(),
            'arguments':
                Map<String, dynamic>.from(
                  (json['onSubmitArguments'] as Map?)
                          ?.cast<String, dynamic>() ??
                      const {},
                ),
          },
        },
      ];
    } else {
      actions = const [];
    }

    // Parse new-style generic components (Label wrappers).
    List<ComponentNode> parsedComponents = [];
    if (json['components'] is List) {
      parsedComponents =
          (json['components'] as List)
              .whereType<Map>()
              .map((c) => ComponentNode.fromJson(Map<String, dynamic>.from(c)))
              .toList();
    }

    // Parse legacy text inputs.
    List<ModalTextInputDefinition> parsedInputs = [];
    if (json['inputs'] is List) {
      parsedInputs =
          (json['inputs'] as List)
              .whereType<Map>()
              .map(
                (i) => ModalTextInputDefinition.fromJson(
                  Map<String, dynamic>.from(i),
                ),
              )
              .toList();
    }

    return ModalDefinition(
      title: (json['title'] ?? '').toString(),
      customId: (json['customId'] ?? '').toString(),
      actions: actions,
      inputs: parsedInputs,
      components: parsedComponents,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'customId': customId,
    if (components.isNotEmpty)
      'components': components.map((c) => c.toJson()).toList(),
    if (components.isEmpty)
      'inputs': inputs.map((i) => i.toJson()).toList(),
    if (actions.isNotEmpty) 'actions': actions,
  };
}
