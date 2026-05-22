import 'dart:async';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/global.dart' as shared_global;
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:bot_creator_shared/engine/bot_engine_callbacks.dart';
import 'package:bot_creator_shared/engine/command_executor.dart';
import 'package:bot_creator_shared/engine/workflow_executor.dart';
import 'package:bot_creator_shared/actions/interaction_response.dart';
import 'package:bot_creator_shared/actions/send_message.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/events/event_contexts.dart';

/// Central dispatcher for Discord gateway events.
class EventDispatcher {
  EventDispatcher({
    required this.store,
    required this.callbacks,
    required this.commandExecutor,
    required WorkflowExecutor workflowExecutor,
    this.sessionVariableInjector,
  }) : _workflowExecutor = workflowExecutor;

  final BotDataStore store;
  final BotEngineCallbacks callbacks;
  final CommandExecutor commandExecutor;
  final WorkflowExecutor _workflowExecutor;

  /// Optional callback to inject session-specific bot variables
  /// (e.g. bot.ownerId, bot.commands, bot.uptime) into runtime variables.
  final void Function(Map<String, String>)? sessionVariableInjector;

  /// Registers all event listeners for a bot session.
  List<StreamSubscription<dynamic>> registerListeners(
    NyxxGateway gateway, {
    required String botId,
    required DateTime? startedAt,
  }) {
    final subscriptions = <StreamSubscription<dynamic>>[];

    // Interaction handling (Slash, Autocomplete, Components)
    subscriptions.add(
      gateway.onInteractionCreate.listen((event) {
        callbacks.onDebugLog?.call(
          'Interaction received: ${event.interaction.type}',
          botId: botId,
        );
        unawaited(
          _safeRun(
            () => commandExecutor.handleInteraction(
              event,
              gateway: gateway,
              botId: botId,
              startedAt: startedAt,
            ),
            botId: botId,
            context: 'Interaction handling',
          ),
        );
      }),
    );

    // Message Create (Workflows + Legacy Commands)
    subscriptions.add(
      gateway.onMessageCreate.listen((event) {
        callbacks.onDebugLog?.call(
          'Message received from ${event.message.author.username}',
          botId: botId,
        );
        unawaited(
          _safeRun(
            () => _handleMessageCreate(
              event,
              botId: botId,
              gateway: gateway,
              startedAt: startedAt,
            ),
            botId: botId,
            context: 'Message processing',
          ),
        );
      }),
    );

    // Helper to register simple events
    void reg(String eventName, Stream<dynamic> stream, Function buildContext) {
      subscriptions.add(
        stream.listen((event) {
          callbacks.onDebugLog?.call(
            'Event received: $eventName',
            botId: botId,
          );
          _dispatchEvent(
            eventName,
            event,
            buildContext,
            botId,
            gateway,
            startedAt,
          );
        }),
      );
    }

    // Guilds
    reg('guildCreate', gateway.onGuildCreate, buildGuildCreateEventContext);
    reg('guildUpdate', gateway.onGuildUpdate, buildGuildUpdateEventContext);
    reg('guildDelete', gateway.onGuildDelete, buildGuildDeleteEventContext);
    reg(
      'guildAuditLogCreate',
      gateway.onGuildAuditLogCreate,
      buildGuildAuditLogCreateEventContext,
    );

    // Channels
    reg(
      'channelCreate',
      gateway.onChannelCreate,
      buildChannelCreateEventContext,
    );
    reg(
      'channelUpdate',
      gateway.onChannelUpdate,
      buildChannelUpdateEventContext,
    );
    reg(
      'channelDelete',
      gateway.onChannelDelete,
      buildChannelDeleteEventContext,
    );
    reg(
      'channelPinsUpdate',
      gateway.onChannelPinsUpdate,
      buildChannelPinsUpdateEventContext,
    );

    // Threads
    reg('threadCreate', gateway.onThreadCreate, buildThreadCreateEventContext);
    reg('threadUpdate', gateway.onThreadUpdate, buildThreadUpdateEventContext);
    reg('threadDelete', gateway.onThreadDelete, buildThreadDeleteEventContext);
    reg(
      'threadMemberUpdate',
      gateway.onThreadMemberUpdate,
      buildThreadMemberUpdateEventContext,
    );
    reg(
      'threadMembersUpdate',
      gateway.onThreadMembersUpdate,
      buildThreadMembersUpdateEventContext,
    );

    // Members
    reg(
      'guildMemberAdd',
      gateway.onGuildMemberAdd,
      buildGuildMemberAddEventContext,
    );
    reg(
      'guildMemberUpdate',
      gateway.onGuildMemberUpdate,
      buildGuildMemberUpdateEventContext,
    );
    reg(
      'guildMemberRemove',
      gateway.onGuildMemberRemove,
      buildGuildMemberRemoveEventContext,
    );

    // Roles
    reg(
      'guildRoleCreate',
      gateway.onGuildRoleCreate,
      buildGuildRoleCreateEventContext,
    );
    reg(
      'guildRoleUpdate',
      gateway.onGuildRoleUpdate,
      buildGuildRoleUpdateEventContext,
    );
    reg(
      'guildRoleDelete',
      gateway.onGuildRoleDelete,
      buildGuildRoleDeleteEventContext,
    );

    // Messages (Update and Delete, Create is special)
    reg(
      'messageUpdate',
      gateway.onMessageUpdate,
      buildMessageUpdateEventContext,
    );
    reg(
      'messageDelete',
      gateway.onMessageDelete,
      buildMessageDeleteEventContext,
    );
    // reg('messageBulkDelete', gateway.onMessageBulkDelete, buildMessageBulkDeleteEventContext); // If needed

    // Reactions
    reg(
      'messageReactionAdd',
      gateway.onMessageReactionAdd,
      buildMessageReactionAddEventContext,
    );
    reg(
      'messageReactionRemove',
      gateway.onMessageReactionRemove,
      buildMessageReactionRemoveEventContext,
    );
    reg(
      'messageReactionRemoveAll',
      gateway.onMessageReactionRemoveAll,
      buildMessageReactionRemoveAllEventContext,
    );
    reg(
      'messageReactionRemoveEmoji',
      gateway.onMessageReactionRemoveEmoji,
      buildMessageReactionRemoveEmojiEventContext,
    );

    // Polls
    reg(
      'messagePollVoteAdd',
      gateway.onMessagePollVoteAdd,
      buildMessagePollVoteAddEventContext,
    );
    reg(
      'messagePollVoteRemove',
      gateway.onMessagePollVoteRemove,
      buildMessagePollVoteRemoveEventContext,
    );

    // Invites
    reg('inviteCreate', gateway.onInviteCreate, buildInviteCreateEventContext);
    reg('inviteDelete', gateway.onInviteDelete, buildInviteDeleteEventContext);

    // Presence & User
    reg(
      'presenceUpdate',
      gateway.onPresenceUpdate,
      buildPresenceUpdateEventContext,
    );
    reg('userUpdate', gateway.onUserUpdate, buildUserUpdateEventContext);

    // Voice
    reg(
      'voiceStateUpdate',
      gateway.onVoiceStateUpdate,
      buildVoiceStateUpdateEventContext,
    );
    reg(
      'voiceServerUpdate',
      gateway.onVoiceServerUpdate,
      buildVoiceServerUpdateEventContext,
    );
    reg(
      'voiceChannelEffectSend',
      gateway.onVoiceChannelEffectSend,
      buildVoiceChannelEffectSendEventContext,
    );

    // Typing
    reg('typingStart', gateway.onTypingStart, buildTypingStartEventContext);

    return subscriptions;
  }

  void _dispatchEvent(
    String eventName,
    dynamic event,
    Function buildContext,
    String botId,
    NyxxGateway gateway,
    DateTime? startedAt,
  ) {
    unawaited(
      _handleEvent(
        eventName,
        event,
        buildContext,
        botId: botId,
        gateway: gateway,
        startedAt: startedAt,
      ),
    );
  }

  Future<void> _handleEvent(
    String eventName,
    dynamic event,
    Function buildContext, {
    required String botId,
    required NyxxGateway gateway,
    required DateTime? startedAt,
  }) async {
    callbacks.onDebugLog?.call(
      '_handleEvent started for event: $eventName',
      botId: botId,
    );

    // Prevent bots from triggering event workflows for message events to avoid infinite loops.
    if (event is MessageCreateEvent) {
      final author = event.message.author;
      final isBot =
          author is User
              ? (author.isBot
                  ? true
                  : author is WebhookAuthor
                  ? true
                  : false)
              : true;
      if (isBot || event.message.application != null) {
        return;
      }
    }
    if (event is MessageUpdateEvent) {
      final msg = event.message;
      final author = msg.author;
      final isBot =
          author is User
              ? (author.isBot
                  ? true
                  : author is WebhookAuthor
                  ? true
                  : false)
              : true;
      if (isBot || msg.application != null) {
        return;
      }
    }

    final workflows = await store.getWorkflows(botId);
    callbacks.onDebugLog?.call(
      'Found ${workflows.length} workflows for bot: $botId',
      botId: botId,
    );

    final matching =
        workflows.where((w) {
          final trigger = Map<String, dynamic>.from(w['eventTrigger'] ?? {});
          return trigger['event']?.toString().toLowerCase() ==
              eventName.toLowerCase();
        }).toList();

    callbacks.onDebugLog?.call(
      'Found ${matching.length} matching workflows for event: $eventName',
      botId: botId,
    );

    if (matching.isEmpty) {
      callbacks.onDebugLog?.call(
        'No matching workflows found for event: $eventName',
        botId: botId,
      );
      return;
    }

    final dynamic contextResult = (buildContext as dynamic)(event);
    final EventExecutionContext context =
        contextResult is Future<EventExecutionContext>
            ? await contextResult
            : contextResult;

    callbacks.onDebugLog?.call(
      'Built context for event: $eventName',
      botId: botId,
    );

    final runtimeVariables = <String, String>{
      ...context.variables,
      'workflow.type': 'event',
    };
    _injectBaseVariables(runtimeVariables, botId: botId, startedAt: startedAt);
    runtimeVariables.addAll(shared_global.extractBotRuntimeDetails(gateway));
    sessionVariableInjector?.call(runtimeVariables);

    // Hydrate variables once for all matching workflows
    await _hydrateEventContext(gateway, context, runtimeVariables);
    await hydrateRuntimeVariables(
      store: store,
      botId: botId,
      runtimeVariables: runtimeVariables,
      guildContextId: context.guildId?.toString(),
      channelContextId: context.channelId?.toString(),
      userContextId: context.userId?.toString(),
      messageContextId: context.messageId?.toString(),
    );

    for (final workflow in matching) {
      callbacks.onDebugLog?.call(
        'Executing workflow: ${workflow['name']}',
        botId: botId,
      );

      final normalized = store.normalizeCommandData(
        Map<String, dynamic>.from(workflow),
      );
      final executionValue = Map<String, dynamic>.from(
        (normalized['data'] as Map?)?.cast<String, dynamic>() ??
            normalized, // Workflows might have data at top level or in 'data'
      );

      final executionMode =
          (executionValue['executionMode'] ?? 'workflow')
              .toString()
              .trim()
              .toLowerCase();

      final scriptSource =
          (executionValue['bdfdScriptContent'] ??
                  executionValue['scriptContent'] ??
                  executionValue['bdfdScript'] ??
                  '')
              .toString();

      final shouldCompileFromBdfdSource =
          executionMode == 'bdfd_script' || scriptSource.trim().isNotEmpty;

      if (shouldCompileFromBdfdSource) {
        await _executeBdfdScriptInEvent(
          scriptSource,
          context: context,
          gateway: gateway,
          botId: botId,
          runtimeVariables: Map<String, String>.from(runtimeVariables),
        );
      } else {
        await _executeEventWorkflow(
          normalized,
          context: context,
          botId: botId,
          gateway: gateway,
          runtimeVariables: Map<String, String>.from(runtimeVariables),
        );
      }
    }
  }

  Future<void> _handleMessageCreate(
    MessageCreateEvent event, {
    required String botId,
    required NyxxGateway gateway,
    required DateTime? startedAt,
  }) async {
    callbacks.onDebugLog?.call('_handleMessageCreate started', botId: botId);

    final author = event.message.author;
    final isBot =
        author is User
            ? (author.isBot
                ? true
                : author is WebhookAuthor
                ? true
                : false)
            : true;
    if (isBot ||
        event.message.application != null ||
        event.message.author.id == gateway.application.id) {
      callbacks.onDebugLog?.call(
        'Message is from bot or application, returning early',
        botId: botId,
      );
      return;
    }

    callbacks.onDebugLog?.call('Processing user message', botId: botId);

    final runtimeVariables = <String, String>{};
    _injectBaseVariables(runtimeVariables, botId: botId, startedAt: startedAt);
    runtimeVariables.addAll(shared_global.extractBotRuntimeDetails(gateway));
    sessionVariableInjector?.call(runtimeVariables);

    // Handle Legacy Commands
    final appData = await store.getApp(botId);
    final prefix = (appData['prefix'] ?? '!').toString().trim();
    final content = event.message.content.trim();

    if (content.startsWith(prefix)) {
      callbacks.onDebugLog?.call(
        'Content starts with prefix, processing command',
        botId: botId,
      );
      final commandBody = content.substring(prefix.length).trim();
      callbacks.onDebugLog?.call('Command body: "$commandBody"', botId: botId);

      if (commandBody.isNotEmpty) {
        callbacks.onDebugLog?.call(
          'Command body is not empty, calling _tryHandleLegacyCommand',
          botId: botId,
        );
        await _tryHandleLegacyCommand(
          commandBody,
          event: event,
          botId: botId,
          gateway: gateway,
          runtimeVariables: runtimeVariables,
        );
        callbacks.onDebugLog?.call(
          'Finished _tryHandleLegacyCommand',
          botId: botId,
        );
      } else {
        callbacks.onDebugLog?.call('Command body is empty', botId: botId);
      }
    } else {
      callbacks.onDebugLog?.call(
        'Content does not start with prefix',
        botId: botId,
      );
    }
    // Handle Event Workflows
    callbacks.onDebugLog?.call('Processing event workflows', botId: botId);
    await _handleEvent(
      'messageCreate',
      event,
      buildMessageCreateEventContext,
      botId: botId,
      gateway: gateway,
      startedAt: startedAt,
    );
    callbacks.onDebugLog?.call('Finished event workflows', botId: botId);

    callbacks.onDebugLog?.call('_handleMessageCreate completed', botId: botId);
  }

  Future<void> _tryHandleLegacyCommand(
    String commandBody, {
    required MessageCreateEvent event,
    required String botId,
    required NyxxGateway gateway,
    required Map<String, String> runtimeVariables,
  }) async {
    callbacks.onDebugLog?.call(
      '_tryHandleLegacyCommand started with commandBody: $commandBody',
      botId: botId,
    );

    final allCommands = await store.listAppCommands(botId);
    callbacks.onDebugLog?.call(
      'Found ${allCommands.length} commands for bot: $botId',
      botId: botId,
    );

    final parts = commandBody.split(RegExp(r'\s+'));
    final commandName = parts[0].toLowerCase();
    callbacks.onDebugLog?.call(
      'Looking for command with name: $commandName',
      botId: botId,
    );

    final command = allCommands.firstWhere(
      (c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final type = (c['type'] ?? '').toString().toLowerCase();
        final data = c['data'] as Map?;
        final legacyMode = data?['legacyModeEnabled'] == true;
        callbacks.onDebugLog?.call(
          'Checking command: name="$name", type="$type", legacyMode=$legacyMode',
          botId: botId,
        );
        return name == commandName &&
            (type == 'chatinput' || type.isEmpty) &&
            legacyMode;
      },
      orElse: () {
        callbacks.onDebugLog?.call(
          'No matching command found for: $commandName',
          botId: botId,
        );
        return <String, dynamic>{};
      },
    );

    if (command.isEmpty) {
      if (commandName == 'help') {
        final appData = await store.getApp(botId);
        final builtInHelpEnabled = appData['builtInLegacyHelpEnabled'] != false;
        if (builtInHelpEnabled) {
          callbacks.onDebugLog?.call(
            'Built-in legacy help triggered',
            botId: botId,
          );
          
          final legacyCommands = allCommands.where((c) {
            final type = (c['type'] ?? '').toString().toLowerCase();
            final data = c['data'] as Map?;
            final legacyMode = data?['legacyModeEnabled'] == true;
            return (type == 'chatinput' || type.isEmpty) && legacyMode;
          }).toList();

          final prefix = (appData['prefix'] ?? '!').toString().trim();
          final query = parts.length > 1 ? parts[1].toLowerCase().trim() : '';

          if (query.isNotEmpty) {
            final target = legacyCommands.firstWhere(
              (c) => (c['name'] ?? '').toString().toLowerCase() == query,
              orElse: () => <String, dynamic>{},
            );
            if (target.isNotEmpty) {
              final name = (target['name'] ?? '').toString();
              final data = target['data'] as Map?;
              final desc = (target['description'] ??
                      data?['commandDescription'] ??
                      data?['description'] ??
                      'No description provided.')
                  .toString()
                  .trim();
              
              final buffer = StringBuffer();
              buffer.writeln('**Command:** `$prefix$name`');
              buffer.writeln('**Description:** $desc');
              
              final options = (target['options'] as List?) ?? (data?['options'] as List?);
              if (options != null && options.isNotEmpty) {
                buffer.writeln('\n**Parameters:**');
                for (final opt in options) {
                  if (opt is Map) {
                    final optName = (opt['name'] ?? '').toString();
                    final optDesc = (opt['description'] ?? '').toString().trim();
                    final required = opt['required'] == true ? ' (Required)' : '';
                    if (optDesc.isNotEmpty) {
                      buffer.writeln('• `$optName`$required - *$optDesc*');
                    } else {
                      buffer.writeln('• `$optName`$required');
                    }
                  }
                }
              }

              unawaited(store.recordCommandExecution(botId, 'help'));
              await sendMessageToChannel(
                gateway,
                event.message.channelId,
                content: buffer.toString(),
                botId: botId,
                guildId: event.guildId?.toString(),
              );
              return;
            } else {
              unawaited(store.recordCommandExecution(botId, 'help'));
              await sendMessageToChannel(
                gateway,
                event.message.channelId,
                content: '❌ Command `$query` not found.',
                botId: botId,
                guildId: event.guildId?.toString(),
              );
              return;
            }
          }

          final buffer = StringBuffer();
          if (legacyCommands.isEmpty) {
            buffer.writeln('**Available Legacy Commands:**');
            buffer.writeln('No legacy commands are registered.');
          } else {
            buffer.writeln('**Available Legacy Commands:**');
            for (final cmd in legacyCommands) {
              final name = (cmd['name'] ?? '').toString();
              final data = cmd['data'] as Map?;
              final desc = (cmd['description'] ??
                      data?['commandDescription'] ??
                      data?['description'] ??
                      '')
                  .toString()
                  .trim();
              if (desc.isNotEmpty) {
                buffer.writeln('• `$prefix$name` - *$desc*');
              } else {
                buffer.writeln('• `$prefix$name`');
              }
            }
          }

          unawaited(store.recordCommandExecution(botId, 'help'));
          await sendMessageToChannel(
            gateway,
            event.message.channelId,
            content: buffer.toString(),
            botId: botId,
            guildId: event.guildId?.toString(),
          );
          return;
        }
      }

      callbacks.onDebugLog?.call(
        'Command is empty, returning early',
        botId: botId,
      );
      return;
    }

    callbacks.onDebugLog?.call(
      'Found matching command: ${command['name']}',
      botId: botId,
    );

    callbacks.onDebugLog?.call(
      'Legacy command triggered: $commandName',
      botId: botId,
    );
    unawaited(store.recordCommandExecution(botId, commandName));

    // Prepare arguments ($1, $2, etc.)
    final args = parts.skip(1).toList();
    final argsString = args.join(' ');
    callbacks.onDebugLog?.call('Command arguments: $args', botId: botId);

    for (var i = 0; i < args.length; i++) {
      runtimeVariables['${i + 1}'] = args[i];
      callbacks.onDebugLog?.call(
        'Set runtime variable \'\${i + 1}\' to: ${args[i]}',
        botId: botId,
      );
    }
    runtimeVariables['0'] = commandName;
    callbacks.onDebugLog?.call(
      'Set runtime variable \'0\' to: $commandName',
      botId: botId,
    );

    final context = buildMessageCreateEventContext(event);
    runtimeVariables.addAll(context.variables);

    // Override message content for legacy commands so $message returns only the arguments
    runtimeVariables['message.content'] = argsString;
    runtimeVariables['message.cleanContent'] = argsString;
    callbacks.onDebugLog?.call(
      'Overrode message.content with arguments: "$argsString"',
      botId: botId,
    );

    // Inject guild, channel and member variables for legacy command execution
    await _hydrateEventContext(gateway, context, runtimeVariables);

    await hydrateRuntimeVariables(
      store: store,
      botId: botId,
      runtimeVariables: runtimeVariables,
      guildContextId: context.guildId?.toString(),
      channelContextId: context.channelId?.toString(),
      userContextId: context.userId?.toString(),
      messageContextId: context.messageId?.toString(),
    );

    final normalized = store.normalizeCommandData(
      Map<String, dynamic>.from(command),
    );
    final executionValue = Map<String, dynamic>.from(
      (normalized['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    final executionMode =
        (executionValue['executionMode'] ?? 'workflow')
            .toString()
            .trim()
            .toLowerCase();

    final scriptSource =
        (executionValue['bdfdScriptContent'] ??
                executionValue['scriptContent'] ??
                executionValue['bdfdScript'] ??
                '')
            .toString();

    final shouldCompileFromBdfdSource =
        executionMode == 'bdfd_script' || scriptSource.trim().isNotEmpty;

    callbacks.onDebugLog?.call(
      'Execution mode: $executionMode, shouldCompile: $shouldCompileFromBdfdSource',
      botId: botId,
    );

    if (shouldCompileFromBdfdSource) {
      await _executeBdfdScriptInEvent(
        scriptSource,
        context: context,
        gateway: gateway,
        botId: botId,
        runtimeVariables: runtimeVariables,
      );
    } else {
      await _executeEventWorkflow(
        normalized,
        context: context,
        botId: botId,
        gateway: gateway,
        runtimeVariables: runtimeVariables,
      );
    }
    callbacks.onDebugLog?.call(
      'Finished execution for command: $commandName',
      botId: botId,
    );
  }

  Future<void> _executeBdfdScriptInEvent(
    String scriptSource, {
    required EventExecutionContext context,
    required NyxxGateway gateway,
    required String botId,
    required Map<String, String> runtimeVariables,
  }) async {
    callbacks.onDebugLog?.call(
      '_executeBdfdScriptInEvent started',
      botId: botId,
    );

    final compileResult = BdfdCompiler().compile(scriptSource);

    if (compileResult.hasErrors) {
      callbacks.onLog?.call(
        'ERROR: BDFD Compilation failed: ${compileResult.diagnostics.map((d) => d.message).join(', ')}',
        botId: botId,
      );
      return;
    }

    final actions = compileResult.actions;
    callbacks.onDebugLog?.call(
      'BDFD compiled into ${actions.length} actions',
      botId: botId,
    );

    if (actions.isNotEmpty) {
      final cmdName = runtimeVariables['0'];
      final label = cmdName != null ? '!$cmdName' : 'BDFD Script';
      await _workflowExecutor.executeActions(
        actions: actions,
        context: null,
        gateway: gateway,
        botId: botId,
        runtimeVariables: runtimeVariables,
        fallbackChannelId: context.channelId,
        fallbackGuildId: context.guildId,
        replayLabel: label,
      );
    }
  }

  Future<void> _executeEventWorkflow(
    Map<String, dynamic> workflow, {
    required EventExecutionContext context,
    required String botId,
    required NyxxGateway gateway,
    required Map<String, String> runtimeVariables,
  }) async {
    callbacks.onDebugLog?.call(
      '_executeEventWorkflow started for workflow: ${workflow['name']}',
      botId: botId,
    );

    final executionValue = Map<String, dynamic>.from(
      (workflow['data'] as Map?)?.cast<String, dynamic>() ?? workflow,
    );

    final actionsJson = List<Map<String, dynamic>>.from(
      (executionValue['actions'] as List?)?.whereType<Map>().map(
            (e) => Map<String, dynamic>.from(e),
          ) ??
          const [],
    );
    callbacks.onDebugLog?.call(
      'Found ${actionsJson.length} actions in workflow',
      botId: botId,
    );

    final actions = actionsJson.map((e) => Action.fromJson(e)).toList();
    callbacks.onDebugLog?.call(
      'Parsed ${actions.length} actions',
      botId: botId,
    );

    if (actions.isNotEmpty) {
      callbacks.onDebugLog?.call(
        'Executing ${actions.length} actions',
        botId: botId,
      );
      final actionResults = await _workflowExecutor.executeActions(
        actions: actions,
        context: null,
        gateway: gateway,
        botId: botId,
        runtimeVariables: runtimeVariables,
        fallbackChannelId: context.channelId,
        fallbackGuildId: context.guildId,
        replayLabel: (workflow['name'] ?? '').toString(),
      );
      callbacks.onDebugLog?.call(
        'Executed actions, got ${actionResults.length} results',
        botId: botId,
      );
      for (final entry in actionResults.entries) {
        runtimeVariables['action.${entry.key}'] = entry.value;
        callbacks.onDebugLog?.call(
          'Set runtime variable \'action.${entry.key}\' to: ${entry.value}',
          botId: botId,
        );
      }
    }

    final response = Map<String, dynamic>.from(
      (executionValue['response'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    callbacks.onDebugLog?.call('Response data: $response', botId: botId);

    if (response.isNotEmpty) {
      callbacks.onDebugLog?.call('Workflow has response data', botId: botId);
      await sendWorkflowResponse(
        gateway: gateway,
        fallbackChannelId: context.channelId,
        response: response,
        runtimeVariables: runtimeVariables,
        botId: botId,
        onLog:
            (msg, {required botId}) async =>
                callbacks.onLog?.call(msg, botId: botId),
        onDebugLog:
            (msg, {required botId}) async =>
                callbacks.onDebugLog?.call(msg, botId: botId),
      );
    }
    callbacks.onDebugLog?.call('_executeEventWorkflow completed', botId: botId);
  }

  Future<void> _hydrateEventContext(
    NyxxGateway gateway,
    EventExecutionContext context,
    Map<String, String> variables,
  ) async {
    callbacks.onDebugLog?.call(
      '_hydrateEventContext started',
      botId: gateway.application.id.toString(),
    );
    // Similar to logic in bot.event_workflows.dart lines 691-735
    final guildId = context.guildId;
    final channelId = context.channelId;
    final userId = context.userId;

    if (guildId != null) {
      try {
        final guild = await gateway.guilds.get(guildId);
        variables.addAll(
          await shared_global.extractGuildRuntimeDetails(
            guild,
            client: gateway,
            guildId: guildId,
          ),
        );
        if (userId != null) {
          final member = await guild.members.fetch(userId);
          variables.addAll(
            shared_global.extractMemberRuntimeDetails(
              member: member,
              guild: guild,
              guildId: guildId.toString(),
            ),
          );
        }
      } catch (e) {
        callbacks.onDebugLog?.call(
          'Error hydrating guild context: $e',
          botId: gateway.application.id.toString(),
        );
      }
    }

    if (channelId != null) {
      try {
        final channel = await gateway.channels.get(channelId);
        variables.addAll(shared_global.extractChannelRuntimeDetails(channel));
      } catch (e) {
        callbacks.onDebugLog?.call(
          'Error hydrating channel context: $e',
          botId: gateway.application.id.toString(),
        );
      }
    }
    callbacks.onDebugLog?.call(
      '_hydrateEventContext completed',
      botId: gateway.application.id.toString(),
    );
  }

  void _injectBaseVariables(
    Map<String, String> variables, {
    required String botId,
    required DateTime? startedAt,
  }) {
    if (startedAt != null) {
      final uptimeMs = DateTime.now().difference(startedAt).inMilliseconds;
      variables['bot.uptime'] = uptimeMs.toString();
    }
  }

  Future<void> _safeRun(
    FutureOr<void> Function() action, {
    required String botId,
    required String context,
  }) async {
    try {
      await action();
    } catch (error, stackTrace) {
      callbacks.onLog?.call('ERROR in $context: $error', botId: botId);
      callbacks.onDebugLog?.call('Stack trace: $stackTrace', botId: botId);
    }
  }
}
