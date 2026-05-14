import 'dart:async';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/global.dart' as shared_global;
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:bot_creator_shared/engine/bot_engine_callbacks.dart';
import 'package:bot_creator_shared/engine/command_executor.dart';
import 'package:bot_creator_shared/engine/workflow_executor.dart';
import 'package:bot_creator_shared/events/event_contexts.dart';

/// Central dispatcher for Discord gateway events.
class EventDispatcher {
  EventDispatcher({
    required this.store,
    required this.callbacks,
    required this.commandExecutor,
    required WorkflowExecutor workflowExecutor,
  }) : _workflowExecutor = workflowExecutor;

  final BotDataStore store;
  final BotEngineCallbacks callbacks;
  final CommandExecutor commandExecutor;
  final WorkflowExecutor _workflowExecutor;

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
        unawaited(
          commandExecutor.handleInteraction(
            event,
            botId: botId,
            startedAt: startedAt,
          ),
        );
      }),
    );

    // Message Create (Workflows + Legacy Commands)
    subscriptions.add(
      gateway.onMessageCreate.listen((event) {
        unawaited(
          _handleMessageCreate(
            event,
            botId: botId,
            gateway: gateway,
            startedAt: startedAt,
          ),
        );
      }),
    );

    // Common event listeners
    subscriptions.add(gateway.onGuildMemberAdd.listen((event) => _dispatchEvent('guildMemberAdd', event, buildGuildMemberAddEventContext, botId, gateway, startedAt)));
    subscriptions.add(gateway.onGuildMemberRemove.listen((event) => _dispatchEvent('guildMemberRemove', event, buildGuildMemberRemoveEventContext, botId, gateway, startedAt)));
    subscriptions.add(gateway.onMessageUpdate.listen((event) => _dispatchEvent('messageUpdate', event, buildMessageUpdateEventContext, botId, gateway, startedAt)));
    subscriptions.add(gateway.onMessageDelete.listen((event) => _dispatchEvent('messageDelete', event, buildMessageDeleteEventContext, botId, gateway, startedAt)));
    subscriptions.add(gateway.onChannelUpdate.listen((event) => _dispatchEvent('channelUpdate', event, buildChannelUpdateEventContext, botId, gateway, startedAt)));
    subscriptions.add(gateway.onInviteCreate.listen((event) => _dispatchEvent('inviteCreate', event, buildInviteCreateEventContext, botId, gateway, startedAt)));

    return subscriptions;
  }

  void _dispatchEvent<T>(
    String eventName,
    T event,
    EventExecutionContext Function(T) buildContext,
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

  Future<void> _handleEvent<T>(
    String eventName,
    T event,
    EventExecutionContext Function(T) buildContext, {
    required String botId,
    required NyxxGateway gateway,
    required DateTime? startedAt,
  }) async {
    final workflows = await store.getWorkflows(botId);
    final matching = workflows.where((w) {
      final trigger = Map<String, dynamic>.from(w['eventTrigger'] ?? {});
      return trigger['event']?.toString().toLowerCase() == eventName.toLowerCase();
    }).toList();

    if (matching.isEmpty) return;

    final context = buildContext(event);
    final runtimeVariables = <String, String>{
      ...context.variables,
      'workflow.type': 'event',
    };
    _injectBaseVariables(runtimeVariables, botId: botId, startedAt: startedAt);
    runtimeVariables.addAll(shared_global.extractBotRuntimeDetails(gateway));

    for (final workflow in matching) {
      await _executeEventWorkflow(
        workflow,
        context: context,
        botId: botId,
        gateway: gateway,
        runtimeVariables: Map<String, String>.from(runtimeVariables),
      );
    }
  }

  Future<void> _handleMessageCreate(
    MessageCreateEvent event, {
    required String botId,
    required NyxxGateway gateway,
    required DateTime? startedAt,
  }) async {
    if (event.message.author is User && (event.message.author as User).isBot) return;

    final runtimeVariables = <String, String>{};
    _injectBaseVariables(runtimeVariables, botId: botId, startedAt: startedAt);
    runtimeVariables.addAll(shared_global.extractBotRuntimeDetails(gateway));

    // Handle Legacy Commands
    final appData = await store.getApp(botId);
    final prefix = (appData['prefix'] ?? '!').toString().trim();
    final content = event.message.content.trim();

    if (content.startsWith(prefix)) {
      final commandBody = content.substring(prefix.length).trim();
      if (commandBody.isNotEmpty) {
        await _tryHandleLegacyCommand(
          commandBody,
          event: event,
          botId: botId,
          gateway: gateway,
          runtimeVariables: runtimeVariables,
        );
      }
    }

    // Handle Event Workflows
    await _handleEvent(
      'messageCreate',
      event,
      buildMessageCreateEventContext,
      botId: botId,
      gateway: gateway,
      startedAt: startedAt,
    );
  }

  Future<void> _tryHandleLegacyCommand(
    String commandBody, {
    required MessageCreateEvent event,
    required String botId,
    required NyxxGateway gateway,
    required Map<String, String> runtimeVariables,
  }) async {
    final allCommands = await store.listAppCommands(botId);
    final parts = commandBody.split(RegExp(r'\s+'));
    final commandName = parts[0].toLowerCase();

    final command = allCommands.firstWhere(
      (c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final type = (c['type'] ?? '').toString().toLowerCase();
        return name == commandName && type == 'legacy';
      },
      orElse: () => <String, dynamic>{},
    );

    if (command.isEmpty) return;

    callbacks.onLog?.call('Legacy command triggered: $commandName', botId: botId);
    unawaited(store.recordCommandExecution(botId, commandName));

    // Prepare arguments ($1, $2, etc.)
    final args = parts.skip(1).toList();
    for (var i = 0; i < args.length; i++) {
      runtimeVariables['${i + 1}'] = args[i];
    }
    runtimeVariables['0'] = commandName;

    final context = buildMessageCreateEventContext(event);
    runtimeVariables.addAll(context.variables);

    final normalized = store.normalizeCommandData(Map<String, dynamic>.from(command));

    await _executeEventWorkflow(
      normalized,
      context: context,
      botId: botId,
      gateway: gateway,
      runtimeVariables: runtimeVariables,
    );
  }

  Future<void> _executeEventWorkflow(
    Map<String, dynamic> workflow, {
    required EventExecutionContext context,
    required String botId,
    required NyxxGateway gateway,
    required Map<String, String> runtimeVariables,
  }) async {
    // Inject guild, channel and member variables for event workflows.
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

    final actionsJson = List<Map<String, dynamic>>.from(
      (workflow['actions'] as List?)?.whereType<Map>().map(
            (e) => Map<String, dynamic>.from(e),
          ) ??
          const [],
    );
    final actions = actionsJson.map((e) => Action.fromJson(e)).toList();

    if (actions.isNotEmpty) {
      final actionResults = await _workflowExecutor.executeActions(
        actions: actions,
        context: null,
        gateway: gateway,
        botId: botId,
        runtimeVariables: runtimeVariables,
      );
      for (final entry in actionResults.entries) {
        runtimeVariables['action.${entry.key}'] = entry.value;
      }
    }

    final response = Map<String, dynamic>.from(
      (workflow['response'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    if (response.isNotEmpty) {
      // For events, we don't have an interaction to respond to, so we use the channel.
      // sendWorkflowResponse might need to be adapted or used with a mock interaction if possible.
      // Actually, handleActions already handles 'Send Message' actions.
      // But if there is a 'Response' tab in the workflow, we should send it too.
      // In the app, it's handled by sending a message to context.channelId.
    }
  }

  Future<void> _hydrateEventContext(NyxxGateway gateway, EventExecutionContext context, Map<String, String> variables) async {
    // Similar to logic in bot.event_workflows.dart lines 691-735
    final guildId = context.guildId;
    final channelId = context.channelId;
    final userId = context.userId;

    if (guildId != null) {
      try {
        final guild = await gateway.guilds.get(guildId);
        variables.addAll(await shared_global.extractGuildRuntimeDetails(guild, client: gateway, guildId: guildId));
        if (userId != null) {
          final member = await guild.members.fetch(userId);
          variables.addAll(shared_global.extractMemberRuntimeDetails(member: member, guild: guild, guildId: guildId.toString()));
        }
      } catch (_) {}
    }

    if (channelId != null) {
      try {
        final channel = await gateway.channels.get(channelId);
        variables.addAll(shared_global.extractChannelRuntimeDetails(channel));
      } catch (_) {}
    }
  }

  void _injectBaseVariables(Map<String, String> variables, {required String botId, required DateTime? startedAt}) {
    if (startedAt != null) {
      final uptimeMs = DateTime.now().difference(startedAt).inMilliseconds;
      variables['bot.uptime'] = uptimeMs.toString();
    }
  }
}
