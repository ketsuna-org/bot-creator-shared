import 'dart:async';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/actions/interaction_response.dart';
import 'package:bot_creator_shared/actions/handle_component_interaction.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/command_autocomplete.dart';
import 'package:bot_creator_shared/utils/command_workflow_routing.dart';
import 'package:bot_creator_shared/utils/global.dart' as shared_global;
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:bot_creator_shared/utils/workflow_call.dart';
import 'package:bot_creator_shared/engine/bot_engine_callbacks.dart';
import 'package:bot_creator_shared/engine/workflow_executor.dart';

/// Unified executor for Discord commands (Slash, Autocomplete, Component).
class CommandExecutor {
  CommandExecutor({
    required this.store,
    required this.callbacks,
    required WorkflowExecutor workflowExecutor,
    this.debugReplayCapturing = true,
  }) : _workflowExecutor = workflowExecutor;

  final BotDataStore store;
  final BotEngineCallbacks callbacks;
  final WorkflowExecutor _workflowExecutor;
  bool debugReplayCapturing;

  /// Handles an [InteractionCreateEvent] and routes it to the appropriate handler.
  Future<void> handleInteraction(
    InteractionCreateEvent event, {
    required NyxxGateway gateway,
    required String botId,
    required DateTime? startedAt,
  }) async {
    final interaction = event.interaction;

    if (interaction is ApplicationCommandAutocompleteInteraction) {
      callbacks.onDebugLog?.call('Autocomplete interaction for ${interaction.data.name}', botId: botId);
      await _handleAutocomplete(
        interaction,
        botId: botId,
        gateway: gateway,
        startedAt: startedAt,
      );
    } else if (interaction is ApplicationCommandInteraction) {
      await _handleSlashCommand(
        interaction,
        botId: botId,
        gateway: gateway,
        startedAt: startedAt,
      );
    } else if (interaction is MessageComponentInteraction) {
      callbacks.onDebugLog?.call('Component interaction: ${interaction.data.customId}', botId: botId);
      await handleComponentInteraction(
        gateway,
        interaction,
        store,
        botId,
      );
    } else if (interaction is ModalSubmitInteraction) {
      callbacks.onDebugLog?.call('Modal submit: ${interaction.data.customId}', botId: botId);
      await handleModalSubmitInteraction(
        gateway,
        interaction,
        store,
        botId,
      );
    }
  }

  Future<void> _handleSlashCommand(
    ApplicationCommandInteraction interaction, {
    required String botId,
    required NyxxGateway gateway,
    required DateTime? startedAt,
  }) async {
    callbacks.onDebugLog?.call(
      'Command received: ${interaction.data.name}',
      botId: botId,
    );

    final commandData = interaction.data;

    // Parallelize independent operations
    final results = await Future.wait([
      store.listAppCommands(botId),
      shared_global.generateKeyValues(interaction),
    ]);

    final allCommands = results[0] as List<Map<String, dynamic>>;
    final listOfArgs = results[1] as Map<String, String>;

    final action = allCommands.firstWhere(
      (c) => c['id'] == commandData.id.toString(),
      orElse: () => <String, dynamic>{},
    );

    if (action.isEmpty) {
      callbacks.onLog?.call('Command not found: ${commandData.name}', botId: botId);
      final builder = MessageBuilder(content: 'Command not found.');
      await interaction.respond(builder);
      return;
    }

    unawaited(store.recordCommandExecution(botId, interaction.data.name));

    final runtimeVariables = <String, String>{...listOfArgs};
    runtimeVariables['bot.id'] = botId;

    // Inject bot variables
    runtimeVariables.addAll(shared_global.extractBotRuntimeDetails(gateway));
    _injectBaseVariables(
      runtimeVariables,
      botId: botId,
      startedAt: startedAt,
    );

    runtimeVariables['interaction.isSlash'] = 'true';

    final contextIds = _resolveContextIds(interaction, runtimeVariables);

    await hydrateRuntimeVariables(
      store: store,
      botId: botId,
      runtimeVariables: runtimeVariables,
      guildContextId: contextIds.guildId,
      channelContextId: contextIds.channelId,
      userContextId: contextIds.userId,
      messageContextId: contextIds.messageId,
    );

    final normalized = store.normalizeCommandData(Map<String, dynamic>.from(action));
    final value = Map<String, dynamic>.from(
      (normalized["data"] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    final subcommandRoute = resolveSubcommandRoute(commandData.options);
    runtimeVariables['interaction.command.route'] = subcommandRoute ?? '';

    final routePayload = (subcommandRoute == null)
        ? null
        : resolveSubcommandWorkflowPayload(value, subcommandRoute);
    final executionValue = routePayload ?? value;

    final executionMode =
        (executionValue['executionMode'] ?? value['executionMode'] ?? 'workflow')
            .toString()
            .trim()
            .toLowerCase();

    final scriptSource = (executionValue['bdfdScriptContent'] ??
            executionValue['scriptContent'] ??
            executionValue['bdfdScript'] ??
            '')
        .toString();

    final shouldCompileFromBdfdSource =
        executionMode == 'bdfd_script' || scriptSource.trim().isNotEmpty;

    if (shouldCompileFromBdfdSource) {
      await _executeBdfdScript(
        scriptSource,
        interaction: interaction,
        gateway: gateway,
        botId: botId,
        runtimeVariables: runtimeVariables,
      );
    } else {
      await _workflowExecutor.executeVisualWorkflow(
        executionValue,
        interaction: interaction,
        gateway: gateway,
        botId: botId,
        runtimeVariables: runtimeVariables,
      );
    }
  }

  Future<void> _executeBdfdScript(
    String scriptSource, {
    required ApplicationCommandInteraction interaction,
    required NyxxGateway gateway,
    required String botId,
    required Map<String, String> runtimeVariables,
  }) async {
    final compileResult = BdfdCompiler().compile(scriptSource);

    if (compileResult.hasErrors) {
      final text = _formatBdfdRuntimeDiagnostics(compileResult.diagnostics);
      await _sendErrorResponse(interaction, text, botId, runtimeVariables);
      return;
    }

    if (compileResult.actions.isEmpty) {
      await _sendErrorResponse(interaction, 'BDFD script compiled but no actions were generated.', botId, runtimeVariables);
      return;
    }

    final actions = compileResult.actions;
    
    await _workflowExecutor.executeActions(
      actions: actions,
      context: interaction,
      gateway: gateway,
      botId: botId,
      runtimeVariables: runtimeVariables,
    );

    // BDFD script might have its own response logic but usually it's handled via actions.
    // If we need a final response, we can add it here.
  }

  Future<void> _handleAutocomplete(
    ApplicationCommandAutocompleteInteraction interaction, {
    required String botId,
    required NyxxGateway gateway,
    required DateTime? startedAt,
  }) async {
    final allCommands = await store.listAppCommands(botId);
    final action = allCommands.firstWhere(
      (c) => c['id'] == interaction.data.id.toString(),
      orElse: () => <String, dynamic>{},
    );

    if (action.isEmpty) {
      await interaction.respond(const []);
      return;
    }

    final normalized = store.normalizeCommandData(Map<String, dynamic>.from(action));
    final normalizedData = Map<String, dynamic>.from(
      (normalized['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    final autocompleteConfig = resolveAutocompleteConfigForInteraction(
      storedOptions: normalizedData['options'],
      interactionOptions: interaction.data.options,
    );

    if (autocompleteConfig == null || autocompleteConfig['enabled'] != true) {
      await interaction.respond(const []);
      return;
    }

    // Static mode
    if ((autocompleteConfig['mode'] ?? 'workflow').toString() == 'static') {
      final focusedOption = shared_global.findFocusedOption(interaction.data.options);
      final query = (focusedOption?.value?.toString() ?? '').toLowerCase().trim();
      final rawChoices = autocompleteConfig['staticChoices'];
      final choices = <CommandOptionChoiceBuilder<dynamic>>[];
      if (rawChoices is List) {
        for (final raw in rawChoices) {
          if (raw is! Map) continue;
          final name = (raw['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          if (query.isNotEmpty && !name.toLowerCase().contains(query)) continue;
          final value = raw['value'];
          choices.add(CommandOptionChoiceBuilder<dynamic>(
            name: name,
            value: value is num ? value : (value?.toString() ?? name),
          ));
          if (choices.length >= 25) break;
        }
      }
      await interaction.respond(choices);
      return;
    }

    // Workflow mode
    final workflowName = (autocompleteConfig['workflow'] ?? '').toString().trim();
    if (workflowName.isEmpty) {
      await interaction.respond(const []);
      return;
    }

    final workflow = await store.getWorkflowByName(botId, workflowName);
    if (workflow == null) {
      await interaction.respond(const []);
      return;
    }

    final focusedOption = shared_global.findFocusedOption(interaction.data.options);
    final runtimeVariables = <String, String>{
      ...await shared_global.generateKeyValues(interaction),
      'bot.id': botId,
      'interaction.isSlash': 'true',
      'interaction.command.name': interaction.data.name,
      'interaction.command.id': interaction.data.id.toString(),
      'autocomplete.query': focusedOption?.value?.toString() ?? '',
      'autocomplete.optionName': focusedOption?.name ?? '',
      'autocomplete.optionType': focusedOption == null ? 'string' : commandOptionTypeToText(focusedOption.type),
    };

    _injectBaseVariables(runtimeVariables, botId: botId, startedAt: startedAt);
    final contextIds = _resolveContextIds(interaction, runtimeVariables);

    await hydrateRuntimeVariables(
      store: store,
      botId: botId,
      runtimeVariables: runtimeVariables,
      guildContextId: contextIds.guildId,
      channelContextId: contextIds.channelId,
      userContextId: contextIds.userId,
      messageContextId: contextIds.messageId,
    );

    final providedArguments = resolveWorkflowCallArguments(
      autocompleteConfig['arguments'],
      (value) => resolveTemplatePlaceholders(value, Map<String, String>.from(runtimeVariables)),
    );

    applyWorkflowInvocationContext(
      variables: runtimeVariables,
      workflowName: workflowName,
      entryPoint: normalizeWorkflowEntryPoint(autocompleteConfig['entryPoint'] ?? workflow['entryPoint']),
      definitions: parseWorkflowArgumentDefinitions(workflow['arguments']),
      providedArguments: providedArguments,
    );

    final actions = List<Action>.from(
      ((workflow['actions'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((json) => Action.fromJson(Map<String, dynamic>.from(json))),
    );

    if (actions.isNotEmpty) {
      await _workflowExecutor.executeActions(
        actions: actions,
        context: interaction,
        gateway: gateway,
        botId: botId,
        runtimeVariables: runtimeVariables,
      );
    }
  }

  void _injectBaseVariables(Map<String, String> variables, {required String botId, required DateTime? startedAt}) {
    if (startedAt != null) {
      final uptimeMs = DateTime.now().difference(startedAt).inMilliseconds;
      variables['bot.uptime'] = uptimeMs.toString();
      variables['bot.uptimeMs'] = uptimeMs.toString();
    }
  }

  _InteractionContextIds _resolveContextIds(Interaction interaction, Map<String, String> variables) {
    String? normalize(String? v) {
      final trimmed = (v ?? '').trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'unknown user' || trimmed.toLowerCase() == 'dm') return null;
      return trimmed;
    }

    final dynamic raw = interaction;
    return _InteractionContextIds(
      guildId: normalize(variables['guildId']) ?? normalize(variables['guild.id']) ?? normalize(raw.guildId?.toString()),
      channelId: normalize(variables['channelId']) ?? normalize(variables['channel.id']) ?? normalize(raw.channelId?.toString()),
      userId: normalize(variables['userId']) ?? normalize(variables['user.id']) ?? normalize(raw.user?.id?.toString()) ?? normalize(raw.member?.user?.id?.toString()),
      messageId: normalize(variables['messageId']) ?? normalize(variables['message.id']) ?? normalize(raw.message?.id?.toString()) ?? normalize(raw.id?.toString()),
    );
  }

  String _formatBdfdRuntimeDiagnostics(List<BdfdCompileDiagnostic> diagnostics) {
    if (diagnostics.isEmpty) return 'Unknown compilation error.';
    return diagnostics.map((d) {
      final severity = d.severity.name.toUpperCase();
      final message = d.message;
      return '[$severity] $message';
    }).join('\n');
  }

  Future<void> _sendErrorResponse(ApplicationCommandInteraction interaction, String text, String botId, Map<String, String> variables) async {
    await sendWorkflowResponse(
      interaction: interaction,
      response: {
        'type': 'normal',
        'text': text,
        'workflow': {'visibility': 'ephemeral'},
      },
      runtimeVariables: variables,
      botId: botId,
      isEphemeral: true,
      onLog: (msg, {required botId}) async => callbacks.onLog?.call(msg, botId: botId),
    );
  }
}

class _InteractionContextIds {
  const _InteractionContextIds({this.guildId, this.channelId, this.userId, this.messageId});
  final String? guildId;
  final String? channelId;
  final String? userId;
  final String? messageId;
}
