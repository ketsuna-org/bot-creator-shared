import 'package:bot_creator_shared/bot/bot_template.dart';

/// All built-in templates available in the template gallery.
final List<BotTemplate> builtInTemplates = [
  welcomeTemplate,
  moderationTemplate,
  utilityTemplate,
  funTemplate,
];

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Base workflow block used by all commands (avoids verbose repetition).
const Map<String, dynamic> _defaultWorkflow = {
  'autoDeferIfActions': true,
  'visibility': 'public',
  'onError': 'edit_error',
  'conditional': _disabledConditional,
};

const Map<String, dynamic> _ephemeralWorkflow = {
  'autoDeferIfActions': true,
  'visibility': 'ephemeral',
  'onError': 'edit_error',
  'conditional': _disabledConditional,
};

const Map<String, dynamic> _disabledConditional = {
  'enabled': false,
  'variable': '',
  'whenTrueType': 'normal',
  'whenFalseType': 'normal',
  'whenTrueText': '',
  'whenFalseText': '',
  'whenTrueEmbeds': <Map<String, dynamic>>[],
  'whenFalseEmbeds': <Map<String, dynamic>>[],
  'whenTrueNormalComponents': <String, dynamic>{},
  'whenFalseNormalComponents': <String, dynamic>{},
  'whenTrueComponents': <String, dynamic>{},
  'whenFalseComponents': <String, dynamic>{},
  'whenTrueModal': <String, dynamic>{},
  'whenFalseModal': <String, dynamic>{},
};

/// Build a text response payload.
Map<String, dynamic> _textResponse(
  String text, {
  Map<String, dynamic> workflow = _defaultWorkflow,
}) => {
  'mode': 'text',
  'text': text,
  'type': 'normal',
  'embed': const <String, dynamic>{'title': '', 'description': '', 'url': ''},
  'embeds': const <Map<String, dynamic>>[],
  'components': const <String, dynamic>{},
  'modal': const <String, dynamic>{},
  'workflow': workflow,
};

/// Build an embed response payload.
Map<String, dynamic> _embedResponse(
  Map<String, dynamic> embed, {
  Map<String, dynamic> workflow = _defaultWorkflow,
}) => {
  'mode': 'embed',
  'text': '',
  'type': 'normal',
  'embed': embed,
  'embeds': [embed],
  'components': const <String, dynamic>{},
  'modal': const <String, dynamic>{},
  'workflow': workflow,
};

/// Build a full command data map.
Map<String, dynamic> _commandData({
  String commandType = 'chatInput',
  String editorMode = 'advanced',
  Map<String, dynamic> simpleConfig = const {},
  String defaultMemberPermissions = '',
  List<Map<String, dynamic>> options = const [],
  required Map<String, dynamic> response,
  List<Map<String, dynamic>> actions = const [],
}) => {
  'version': 1,
  'commandType': commandType,
  'editorMode': editorMode,
  'simpleConfig': simpleConfig,
  'defaultMemberPermissions': defaultMemberPermissions,
  if (options.isNotEmpty) 'options': options,
  'response': response,
  'actions': actions,
};

// ─────────────────────────────────────────────────────────────────────────────
// Welcome Bot
// ─────────────────────────────────────────────────────────────────────────────

final welcomeTemplate = BotTemplate(
  id: 'welcome',
  nameKey: 'template_welcome_name',
  descriptionKey: 'template_welcome_description',
  iconCodePoint: 0xe7f2, // Icons.waving_hand
  category: 'community',
  intents: const {'guildMembers': true, 'messageContent': true},
  commands: [
    BotTemplateCommand(
      name: 'hello',
      description: 'Say hello to the bot',
      data: _commandData(
        response: _embedResponse({
          'title': '👋 Hello ((userName))!',
          'description':
              'Welcome to **((guildName))**! We are glad to have you here.',
          'color': 5793266,
        }),
      ),
    ),
    BotTemplateCommand(
      name: 'serverinfo',
      description: 'Display information about this server',
      data: _commandData(
        response: _embedResponse({
          'title': '📊 ((guildName))',
          'description': '**Members:** ((guildCount))\n**ID:** ((guildId))',
          'color': 3447003,
        }),
      ),
    ),
  ],
  workflows: const [
    {
      'name': 'welcome_message',
      'workflowType': 'event',
      'entryPoint': 'main',
      'arguments': <Map<String, dynamic>>[],
      'eventTrigger': {'category': 'members', 'event': 'guildMemberAdd'},
      'actions': [
        {
          'type': 'sendMessage',
          'enabled': true,
          'payload': {
            'messageMode': 'normal',
            'channelId': '((guild.systemChannelId|channelId))',
            'content':
                '🎉 Welcome <@((member.id))>! You are now part of the server.',
          },
        },
      ],
    },
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Moderation Bot
// ─────────────────────────────────────────────────────────────────────────────

final moderationTemplate = BotTemplate(
  id: 'moderation',
  nameKey: 'template_moderation_name',
  descriptionKey: 'template_moderation_description',
  iconCodePoint: 0xe8e8, // Icons.shield
  category: 'moderation',
  intents: const {'guildMembers': true, 'messageContent': true},
  commands: [
    BotTemplateCommand(
      name: 'ban',
      description: 'Ban a member from the server',
      data: _commandData(
        editorMode: 'simple',
        simpleConfig: const {
          'banUser': true,
          'actionReason': '((opts.reason))',
        },
        // BAN_MEMBERS (0x4)
        defaultMemberPermissions: '4',
        options: const [
          {
            'type': 'user',
            'name': 'target',
            'description': 'User to ban',
            'required': true,
          },
          {
            'type': 'string',
            'name': 'reason',
            'description': 'Reason for banning',
            'required': false,
          },
        ],
        response: _textResponse(
          '🔨 ((opts.target)) has been banned.',
          workflow: _ephemeralWorkflow,
        ),
      ),
    ),
    BotTemplateCommand(
      name: 'kick',
      description: 'Kick a member from the server',
      data: _commandData(
        editorMode: 'simple',
        simpleConfig: const {
          'kickUser': true,
          'actionReason': '((opts.reason))',
        },
        // KICK_MEMBERS (0x2)
        defaultMemberPermissions: '2',
        options: const [
          {
            'type': 'user',
            'name': 'target',
            'description': 'User to kick',
            'required': true,
          },
          {
            'type': 'string',
            'name': 'reason',
            'description': 'Reason for kick',
            'required': false,
          },
        ],
        response: _textResponse(
          '👢 ((opts.target)) has been kicked.',
          workflow: _ephemeralWorkflow,
        ),
      ),
    ),
    BotTemplateCommand(
      name: 'mute',
      description: 'Timeout a member',
      data: _commandData(
        editorMode: 'simple',
        simpleConfig: const {
          'muteUser': true,
          'muteDuration': '600',
          'actionReason': '((opts.reason))',
        },
        // MODERATE_MEMBERS (0x10000000000)
        defaultMemberPermissions: '1099511627776',
        options: const [
          {
            'type': 'user',
            'name': 'target',
            'description': 'User to mute',
            'required': true,
          },
          {
            'type': 'string',
            'name': 'reason',
            'description': 'Reason for mute',
            'required': false,
          },
        ],
        response: _textResponse(
          '🔇 ((opts.target)) has been muted.',
          workflow: _ephemeralWorkflow,
        ),
      ),
    ),
    BotTemplateCommand(
      name: 'clear',
      description: 'Delete multiple messages at once',
      data: _commandData(
        editorMode: 'simple',
        simpleConfig: const {
          'deleteMessages': true,
          'deleteMessagesDefaultCount': '((opts.amount))',
        },
        // MANAGE_MESSAGES (0x2000)
        defaultMemberPermissions: '8192',
        options: const [
          {
            'type': 'integer',
            'name': 'amount',
            'description': 'Number of messages to delete (1-100)',
            'required': true,
            'min_value': 1,
            'max_value': 100,
          },
        ],
        response: _textResponse(
          '🗑️ Deleted ((opts.amount)) message(s).',
          workflow: _ephemeralWorkflow,
        ),
      ),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Utility Bot
// ─────────────────────────────────────────────────────────────────────────────

final utilityTemplate = BotTemplate(
  id: 'utility',
  nameKey: 'template_utility_name',
  descriptionKey: 'template_utility_description',
  iconCodePoint: 0xe86c, // Icons.build
  category: 'utility',
  intents: const {'messageContent': true},
  commands: [
    BotTemplateCommand(
      name: 'ping',
      description: 'Check if the bot is online',
      data: _commandData(response: _textResponse('🏓 Pong!')),
    ),
    BotTemplateCommand(
      name: 'avatar',
      description: "Display a user's avatar",
      data: _commandData(
        options: const [
          {
            'type': 'user',
            'name': 'user',
            'description': 'User to show the avatar of',
            'required': false,
          },
        ],
        response: _embedResponse({
          'title': "🖼️ ((opts.user|userName))'s avatar",
          'image': '((avatar(opts.user.avatar|userAvatar)))',
          'color': 3447003,
        }),
      ),
    ),
    BotTemplateCommand(
      name: 'say',
      description: 'Make the bot send a message',
      data: _commandData(
        // ADMINISTRATOR (0x8)
        defaultMemberPermissions: '8',
        options: const [
          {
            'type': 'string',
            'name': 'message',
            'description': 'The message to send',
            'required': true,
          },
          {
            'type': 'channel',
            'name': 'channel',
            'description': 'Channel to send the message in',
            'required': false,
          },
        ],
        response: _textResponse(
          '✅ Message sent!',
          workflow: _ephemeralWorkflow,
        ),
        actions: const [
          {
            'type': 'sendMessage',
            'enabled': true,
            'payload': {
              'messageMode': 'normal',
              // Fixed: opts.channel resolves to the channel ID directly.
              // The fallback channelId uses the current interaction channel.
              'channelId': '((opts.channel|channelId))',
              'content': '((opts.message))',
            },
          },
        ],
      ),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Fun Bot
// ─────────────────────────────────────────────────────────────────────────────

final funTemplate = BotTemplate(
  id: 'fun',
  nameKey: 'template_fun_name',
  descriptionKey: 'template_fun_description',
  iconCodePoint: 0xe7f3, // Icons.emoji_emotions
  category: 'fun',
  intents: const {'messageContent': true},
  commands: [
    BotTemplateCommand(
      name: 'coinflip',
      description: 'Flip a coin — heads or tails',
      data: _commandData(
        response: {
          'mode': 'text',
          'text': '',
          'type': 'normal',
          'embed': const <String, dynamic>{
            'title': '',
            'description': '',
            'url': '',
          },
          'embeds': const <Map<String, dynamic>>[],
          'components': const <String, dynamic>{},
          'modal': const <String, dynamic>{},
          'workflow': const {
            'autoDeferIfActions': true,
            'visibility': 'public',
            'onError': 'edit_error',
            'conditional': {
              'enabled': true,
              'variable': '((coin()))',
              'whenTrueType': 'normal',
              'whenFalseType': 'normal',
              'whenTrueText': '🪙 **Heads!**',
              'whenFalseText': '🪙 **Tails!**',
              'whenTrueEmbeds': <Map<String, dynamic>>[],
              'whenFalseEmbeds': <Map<String, dynamic>>[],
              'whenTrueNormalComponents': <String, dynamic>{},
              'whenFalseNormalComponents': <String, dynamic>{},
              'whenTrueComponents': <String, dynamic>{},
              'whenFalseComponents': <String, dynamic>{},
              'whenTrueModal': <String, dynamic>{},
              'whenFalseModal': <String, dynamic>{},
            },
          },
        },
      ),
    ),
    BotTemplateCommand(
      name: 'poll',
      description: 'Create a quick poll',
      data: _commandData(
        editorMode: 'simple',
        simpleConfig: const {
          'createPoll': true,
          'pollDurationHours': '24',
          'pollAllowMultiselect': false,
        },
        options: const [
          {
            'type': 'string',
            'name': 'question',
            'description': 'The poll question',
            'required': true,
          },
        ],
        response: _textResponse('📊 Poll created!'),
      ),
    ),
    BotTemplateCommand(
      name: '8ball',
      description: 'Ask the magic 8-ball a question',
      data: _commandData(
        options: const [
          {
            'type': 'string',
            'name': 'question',
            'description': 'Your question',
            'required': true,
          },
        ],
        response: _embedResponse({
          'title': '🎱 Magic 8-Ball',
          'description':
              '**Q:** ((opts.question))\n**A:** ((randomchoice("Yes!", "No.", "Maybe...", "Ask again later.", "Definitely!", "I doubt it.", "Without a doubt.", "Better not tell you now.")))',
          'color': 1752220,
        }),
      ),
    ),
  ],
);
