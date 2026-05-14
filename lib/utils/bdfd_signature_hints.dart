import 'package:bot_creator_shared/utils/bdfd_lexer.dart';

/// Describes the active function context at a given caret position.
class BdfdSignatureContext {
  const BdfdSignatureContext({
    required this.functionName,
    required this.parameters,
    required this.activeIndex,
  });

  /// The raw function name including the leading `$`, e.g. `$addField`.
  final String functionName;

  /// Ordered list of parameter labels for this function.
  final List<String> parameters;

  /// Zero-based index of the parameter the caret is currently in.
  final int activeIndex;
}

/// Returns the signature context for [caretOffset] inside [source],
/// or `null` if the caret is not inside a known function's argument list.
BdfdSignatureContext? bdfdSignatureContextAt(
  String source,
  int caretOffset,
  BdfdLexerResult lexerResult,
) {
  if (caretOffset <= 0 || caretOffset > source.length) {
    return null;
  }

  // Walk the tokens to find the innermost bracket frame whose argument list
  // contains the caret.  We track a stack of open brackets.
  final stack = <_SigFrame>[];

  for (final token in lexerResult.tokens) {
    if (token.type == BdfdTokenType.eof) break;

    if (token.type == BdfdTokenType.openBracket) {
      // The function token is the one immediately before this bracket.
      String? funcName;
      final idx = lexerResult.tokens.indexOf(token);
      if (idx > 0) {
        final prev = lexerResult.tokens[idx - 1];
        if (prev.type == BdfdTokenType.function) {
          funcName = prev.lexeme;
        }
      }
      stack.add(
        _SigFrame(funcName: funcName, bracketStart: token.end, argIndex: 0),
      );
      continue;
    }

    if (token.type == BdfdTokenType.closeBracket) {
      if (stack.isNotEmpty) {
        // If the caret is exactly at the close bracket, it's still "inside".
        if (token.start >= caretOffset) {
          break;
        }
        stack.removeLast();
      }
      continue;
    }

    if (token.type == BdfdTokenType.semicolon && stack.isNotEmpty) {
      if (token.start < caretOffset) {
        stack.last.argIndex += 1;
      }
      continue;
    }
  }

  if (stack.isEmpty) return null;

  // The top of the stack is the innermost function whose brackets contain
  // the caret.  Verify the caret is actually past the open bracket.
  final frame = stack.last;
  if (caretOffset < frame.bracketStart) return null;

  final funcName = frame.funcName;
  if (funcName == null) return null;

  final key = funcName.substring(1).toLowerCase(); // strip '$'
  final params = bdfdSignatureHints[key];
  if (params == null) return null;

  return BdfdSignatureContext(
    functionName: funcName,
    parameters: params,
    activeIndex:
        params.isEmpty ? 0 : frame.argIndex.clamp(0, params.length - 1),
  );
}

class _SigFrame {
  _SigFrame({
    required this.funcName,
    required this.bracketStart,
    required this.argIndex,
  });
  final String? funcName;
  final int bracketStart;
  int argIndex;
}

/// Maps lowercase function names (without `$`) to their ordered parameter
/// labels.  Only functions that accept arguments are listed.
const Map<String, List<String>> bdfdSignatureHints = <String, List<String>>{
  // ── Messages & content ───────────────────────────────────────────────
  'addbutton': [
    'New row',
    'Button ID/URL',
    'Label',
    'Style',
    'Disabled (opt)',
    'Emoji (opt)',
    'Message ID (opt)',
  ],
  'addcmdreactions': ['emoji1', 'emoji2 (opt)', '...'],
  'addfield': ['title', 'value', 'inline (opt)'],
  'addmessagereactions': ['messageID', 'emoji1', 'emoji2 (opt)', '...'],
  'addreactions': ['emoji1', 'emoji2 (opt)', '...'],
  'addselectmenuoption': [
    'Menu option ID',
    'Label',
    'Value',
    'Description',
    'Default (opt)',
    'Emoji (opt)',
    'Message ID (opt)',
  ],
  'addtextinput': [
    'Text Input ID',
    'Style',
    'Label',
    'Minimum length (opt)',
    'Maximum length (opt)',
    'Required (opt)',
    'Value (opt)',
    'Placeholder (opt)',
  ],
  'addtimestamp': ['timestamp (opt)'],
  'allowmention': ['userOrRole'],
  'allowrolementions': ['roleID1', 'roleID2 (opt)', '...'],
  'allowusermentions': ['userID1', 'userID2 (opt)', '...'],
  'args': ['index'],
  'argscheck': ['condition', 'errorMessage'],
  'author': ['text', 'iconURL (opt)', 'hyperlink (opt)'],
  'authoricon': ['url'],
  'authorurl': ['url'],
  'awaitfunc': ['name', 'userID (opt)', 'channelID (opt)'],

  // ── Moderation ───────────────────────────────────────────────────────
  'ban': ['userID', 'reason (opt)'],
  'banid': ['userID', 'reason (opt)'],
  'kick': ['userID', 'reason (opt)'],
  'kickmention': ['reason (opt)'],
  'mute': ['userID', 'duration', 'reason (opt)'],
  'timeout': ['userID', 'duration', 'reason (opt)'],
  'unmute': ['userID'],
  'untimeout': ['userID'],
  'unban': ['userID'],
  'unbanid': ['userID'],

  // ── Math ─────────────────────────────────────────────────────────────
  'calculate': ['expression'],
  'ceil': ['number'],
  'divide': ['num1', 'num2'],
  'floor': ['number'],
  'max': ['num1', 'num2'],
  'min': ['num1', 'num2'],
  'modulo': ['num1', 'num2'],
  'multi': ['num1', 'num2'],
  'random': ['min', 'max'],
  'randomstring': ['length'],
  'round': ['number'],
  'sort': ['values', 'order (opt)'],
  'sqrt': ['number'],
  'sub': ['num1', 'num2'],
  'sum': ['num1', 'num2'],

  // ── Variables ────────────────────────────────────────────────────────
  'getchannelvar': ['name', 'channelID (opt)'],
  'getguildmembervar': ['name', 'userID (opt)', 'guildID (opt)'],
  'getguildvar': ['name', 'guildID (opt)'],
  'getleaderboardposition': ['varName', 'userID (opt)', 'type (opt)'],
  'getleaderboardvalue': ['varName', 'position', 'type (opt)'],
  'getmembervar': ['name', 'userID (opt)'],
  'getmessagevar': ['name', 'messageID (opt)'],
  'getservervar': ['name', 'serverID (opt)'],
  'getuservar': ['name', 'userID (opt)'],
  'getvar': ['name'],
  'setchannelvar': ['name', 'value', 'channelID (opt)'],
  'setguildmembervar': ['name', 'value', 'userID (opt)', 'guildID (opt)'],
  'setguildvar': ['name', 'value', 'guildID (opt)'],
  'setmembervar': ['name', 'value', 'userID (opt)'],
  'setmessagevar': ['name', 'value', 'messageID (opt)'],
  'setservervar': ['name', 'value', 'serverID (opt)'],
  'setuservar': ['name', 'value', 'userID (opt)'],
  'setvar': ['name', 'value'],
  'resetuservar': ['name', 'userID (opt)'],
  'resetchannelvar': ['name', 'channelID (opt)'],
  'resetguildmembervar': ['name', 'userID (opt)', 'guildID (opt)'],
  'resetguildvar': ['name', 'guildID (opt)'],
  'resetmembervar': ['name', 'userID (opt)'],
  'resetservervar': ['name', 'serverID (opt)'],
  'var': ['name', 'value'],
  'varexists': ['name'],

  // ── Embed building ──────────────────────────────────────────────────
  'color': ['hexColor'],
  'description': ['text'],
  'embeddedurl': ['url'],
  'footer': ['text', 'iconURL (opt)'],
  'footericon': ['url'],
  'image': ['url'],
  'thumbnail': ['url'],
  'title': ['text', 'hyperlink (opt)'],

  // ── Channels ─────────────────────────────────────────────────────────
  'channelsendmessage': ['channelID', 'message', 'returnMessageID (opt)'],
  'clear': ['count'],
  'createchannel': ['name', 'type', 'categoryID (opt)'],
  'deletechannels': ['channelID1', 'channelID2 (opt)', '...'],
  'deletechannelsbyname': ['name'],
  'modifychannel': [
    'channelID',
    'name (opt)',
    'topic (opt)',
    'nsfw (opt)',
    'slowmode (opt)',
    'position (opt)',
  ],
  'modifychannelperms': ['channelID', 'allow', 'deny', 'roleOrUserID'],
  'editchannelperms': ['channelID', 'permissions', 'roleOrUserID'],
  'slowmode': ['seconds'],
  'startthread': [
    'name',
    'channelID (opt)',
    'messageID (opt)',
    'archiveDuration (opt)',
    'private (opt)',
  ],
  'threadaddmember': ['threadID', 'userID'],
  'threadremovemember': ['threadID', 'userID'],

  // ── Roles ────────────────────────────────────────────────────────────
  'colorrole': ['roleID', 'hexColor'],
  'createrole': [
    'name',
    'color (opt)',
    'hoisted (opt)',
    'mentionable (opt)',
    'position (opt)',
  ],
  'deleterole': ['roleID'],
  'giverole': ['userID', 'roleID'],
  'giveroles': ['userID', 'roleID1', 'roleID2 (opt)', '...'],
  'hasrole': ['roleID'],
  'modifyrole': [
    'roleID',
    'name (opt)',
    'color (opt)',
    'hoisted (opt)',
    'mentionable (opt)',
    'position (opt)',
  ],
  'modifyroleperms': ['roleID', 'permissions'],
  'rolegrant': ['userID', 'roleID', 'grant (opt)'],
  'setuserroles': ['roleID1', 'roleID2 (opt)', '...'],
  'takerole': ['userID', 'roleID'],
  'takeroles': ['userID', 'roleID1', 'roleID2 (opt)', '...'],

  // ── Messages ─────────────────────────────────────────────────────────
  'deletein': ['seconds'],
  'deletemessage': ['messageID'],
  'dm': ['userID', 'message'],
  'editembedin': ['channelID', 'messageID', 'content'],
  'editin': ['channelID', 'messageID', 'content'],
  'editmessage': ['messageID', 'content'],
  'getmessage': ['channelID', 'messageID'],
  'mentioned': ['index', 'returnSelf (opt)'],
  'mentionedchannels': ['index'],
  'message': ['index (opt)'],
  'pinmessage': ['messageID (opt)'],
  'publishmessage': ['messageID (opt)'],
  'unpinmessage': ['messageID'],
  'reply': ['Channel ID (opt)', 'Message ID (opt)'],
  'replyin': ['seconds'],
  'repeatmessage': ['times', 'message'],
  'sendmessage': ['channelID', 'message', 'returnMessageID (opt)'],
  'sendembedmessage': ['channelID', 'content'],
  'tts': ['enabled'],

  // ── String / text manipulation ──────────────────────────────────────
  'charcount': ['text'],
  'contains': ['text', 'substring'],
  'checkcontains': ['text', 'value1', 'value2 (opt)', '...'],
  'croptext': ['text', 'maxLength', 'suffix (opt)'],
  'input': ['index'],
  'joinsplittext': ['separator'],
  'linescount': ['text'],
  'numberseparator': ['number', 'separator (opt)'],
  'randomtext': ['option1', 'option2', '...'],
  'removecontains': ['text', 'substring'],
  'removelinks': ['text'],
  'replacetext': ['text', 'search', 'replacement'],
  'splittext': ['index'],
  'editsplittext': ['index', 'value'],
  'removesplittextelement': ['index'],
  'textsplit': ['text', 'separator'],
  'tolowercase': ['text'],
  'totitlecase': ['text'],
  'touppercase': ['text'],
  'trimspace': ['text'],
  'unescape': ['text'],

  // ── JSON ─────────────────────────────────────────────────────────────
  'json': ['value (opt)'],
  'jsonarray': ['key', 'separator (opt)'],
  'jsonarrayappend': ['key', 'value'],
  'jsonarraycount': ['key'],
  'jsonarrayindex': ['key', 'index'],
  'jsonarraypop': ['key'],
  'jsonarrayreverse': ['key'],
  'jsonarrayshift': ['key'],
  'jsonarraysort': ['key', 'order (opt)'],
  'jsonarrayunshift': ['key', 'value'],
  'jsonclear': [],
  'jsonexists': ['key'],
  'jsonjoinarray': ['key', 'separator'],
  'jsonparse': ['json'],
  'jsonpretty': ['indent (opt)'],
  'jsonset': ['key', 'value'],
  'jsonsetstring': ['key', 'value'],
  'jsonstringify': [],
  'jsonunset': ['key'],

  // ── HTTP ─────────────────────────────────────────────────────────────
  'httpaddheader': ['name', 'value'],
  'httpdelete': ['url'],
  'httpget': ['url'],
  'httppatch': ['url', 'body (opt)'],
  'httppost': ['url', 'body (opt)'],
  'httpput': ['url', 'body (opt)'],
  'httpresult': ['key (opt)'],

  // ── Control flow ────────────────────────────────────────────────────
  'if': ['condition'],
  'elseif': ['condition'],
  'onlyif': ['value1', 'operator', 'value2', 'errorMessage (opt)'],
  'checkcondition': ['condition', 'trueValue', 'falseValue'],
  'checkuserperms': ['permission', 'errorMessage (opt)'],
  'checkusersperms': ['userID', 'permission', 'errorMessage (opt)'],
  'cooldown': ['duration', 'errorMessage (opt)'],
  'globalcooldown': ['duration', 'errorMessage (opt)'],
  'servercooldown': ['duration', 'errorMessage (opt)'],
  'equals': ['value1', 'value2'],
  'eval': ['code'],
  'for': ['iterations OR init;condition;update'],
  'loop': ['iterations OR init;condition;update'],
  'suppresserrors': ['message (opt)'],
  'embedsuppresserrors': ['message (opt)'],
  'callworkflow': ['name', 'args (opt)'],
  'workflowresponse': ['value (opt)'],

  // ── Select menus ────────────────────────────────────────────────────
  'newselectmenu': [
    'Menu ID',
    'Min',
    'Max',
    'Placeholder (opt)',
    'Message ID (opt)',
  ],
  'editselectmenu': [
    'Menu ID',
    'Min',
    'Max',
    'Placeholder (opt)',
    'Message ID (opt)',
  ],
  'editselectmenuoption': [
    'Menu option ID',
    'Label',
    'Value',
    'Description',
    'Default (opt)',
    'Emoji (opt)',
    'Message ID (opt)',
  ],
  'editbutton': [
    'Button ID/URL',
    'Label',
    'Style',
    'Disabled (opt)',
    'Emoji (opt)',
    'Message ID (opt)',
  ],
  'removecomponent': ['id'],

  // ── Modals ──────────────────────────────────────────────────────────
  'newmodal': ['id', 'title'],

  // ── Tickets ─────────────────────────────────────────────────────────
  'newticket': ['subject (opt)', 'channelName (opt)'],
  'closeticket': [],

  // ── Leaderboards ────────────────────────────────────────────────────
  'globaluserleaderboard': [
    'varName',
    'type (opt)',
    'page (opt)',
    'separator (opt)',
  ],
  'serverleaderboard': [
    'varName',
    'type (opt)',
    'page (opt)',
    'separator (opt)',
  ],
  'userleaderboard': ['varName', 'type (opt)', 'page (opt)', 'separator (opt)'],

  // ── Other ───────────────────────────────────────────────────────────
  'addactionrow': ['ID', 'Container ID (opt)'],
  'addbuttoncv2': [
    'Button ID/URL',
    'Label',
    'Style',
    'Disabled',
    'Emoji',
    'Action Row ID / Section ID',
  ],
  'addcontainer': ['ID', 'Color (opt)', 'Spoiler (opt)'],
  'addmediagallery': ['ID', 'Container ID (opt)'],
  'addmediagalleryitem': ['Media URL', 'Description', 'Spoiler', 'Gallery ID'],
  'addmentionableselect': [
    'Select Menu ID',
    'Placeholder',
    'Min Values',
    'Max Values',
    'Disabled',
    'Action Row ID',
  ],
  'addroleselect': [
    'Select Menu ID',
    'Placeholder',
    'Min Values',
    'Max Values',
    'Disabled',
    'Action Row ID',
  ],
  'addsection': ['ID', 'Container ID (opt)'],
  'addseparator': ['Divider (opt)', 'Spacing (opt)', 'Container ID (opt)'],
  'addtextdisplay': ['Content', 'Container/Section ID (opt)'],
  'addthumbnail': ['Image URL', 'Image description', 'Spoiler', 'Section ID'],
  'adduserselect': [
    'Select Menu ID',
    'Placeholder',
    'Min Values',
    'Max Values',
    'Disabled',
    'Action Row ID',
  ],
  'addchannelselect': [
    'Select Menu ID',
    'Placeholder',
    'Min Values',
    'Max Values',
    'Disabled',
    'Action Row ID',
    'Channel Types (opt)',
  ],
  'addemoji': ['name', 'imageURL'],
  'addstringselect': [
    'Select Menu ID',
    'Placeholder',
    'Min Values',
    'Max Values',
    'Disabled',
    'Action Row ID',
  ],
  'addstringselectoption': [
    'Label',
    'Value',
    'Description',
    'Emoji',
    'Default',
    'Select Menu ID',
  ],
  'bottyping': ['duration (opt)'],
  'bytecount': ['text'],
  'changecooldowntime': ['type', 'commandName', 'duration'],
  'changeusername': ['newName'],
  'changeusernamewithid': ['userID', 'newName'],
  'customemoji': ['nameOrID'],
  'defer': ['ephemeral (opt)'],
  'deletecommand': [],
  'ephemeral': [],
  'findchannel': ['name'],
  'finduser': ['nameOrID'],
  'findrole': ['nameOrID'],
  'getattachments': ['index (opt)'],
  'getbanreason': ['userID'],
  'getchannelselectchannelid': ['Index'],
  'getchannelselectchannelids': ['Separator', 'Limit (opt)'],
  'getcooldown': ['type', 'commandName'],
  'getembeddata': ['messageID', 'field'],
  'getmentionableselectuserid': ['Index'],
  'getmentionableselectuserids': ['Separator', 'Limit (opt)'],
  'getreactions': ['channelID', 'messageID', 'emoji'],
  'getrolecolor': ['roleID'],
  'getroleselectroleid': ['Index'],
  'getroleselectroleids': ['Separator', 'Limit (opt)'],
  'getstringselectvalue': ['Index'],
  'getstringselectvalues': ['Separator', 'Limit (opt)'],
  'gettextsplitindex': ['value'],
  'getuserselectuserid': ['Index'],
  'getuserselectuserids': ['Separator', 'Limit (opt)'],
  'ignorechannels': ['channelID1', 'channelID2 (opt)', '...'],
  'isboolean': ['value'],
  'isinteger': ['value'],
  'isnumber': ['value'],
  'isvalidhex': ['value'],
  'isbanned': ['userID'],
  'ismentioned': ['userID'],
  'log': ['Log message', 'Log level (opt)'],
  'onlyadmin': ['errorMessage (opt)'],
  'onlybotchannelperms': ['permission', 'errorMessage (opt)'],
  'onlybotperms': ['permission', 'errorMessage (opt)'],
  'onlyforcategories': ['categoryID1', 'categoryID2 (opt)', '...'],
  'onlyforchannels': ['channelID1', 'channelID2 (opt)', '...'],
  'onlyforids': ['userID1', 'userID2 (opt)', '...'],
  'onlyforroleids': ['roleID1', 'roleID2 (opt)', '...'],
  'onlyforroles': ['roleName1', 'roleName2 (opt)', '...'],
  'onlyforservers': ['serverID1', 'serverID2 (opt)', '...'],
  'onlyforusers': ['userID1', 'userID2 (opt)', '...'],
  'onlyifmessagecontains': ['substring', 'errorMessage (opt)'],
  'onlynsfw': ['errorMessage (opt)'],
  'onlyperms': ['permission', 'errorMessage (opt)'],
  'removeallcomponents': [],
  'removebuttons': [],
  'removeemoji': ['nameOrID'],
  'usechannel': ['channelID'],
  'userreacted': ['channelID', 'messageID', 'emoji'],
  'userswithrole': ['roleID'],
  'webhookcreate': ['channelID', 'name', 'avatar (opt)'],
  'webhookdelete': ['webhookID'],
  'webhooksend': ['webhookID', 'content'],
  'webhookavatarurl': ['webhookID'],
  'webhookcolor': ['hexColor'],
  'webhookcontent': ['text'],
  'webhookdescription': ['text'],
  'webhookfooter': ['text', 'iconURL (opt)'],
  'webhooktitle': ['text'],
  'webhookusername': ['name'],
  'blacklistids': ['userID1', 'userID2 (opt)', '...'],
  'blacklistroleids': ['roleID1', 'roleID2 (opt)', '...'],
  'blacklistroles': ['roleName1', 'roleName2 (opt)', '...'],
  'blacklistrolesids': ['roleID1', 'roleID2 (opt)', '...'],
  'blacklistservers': ['serverID1', 'serverID2 (opt)', '...'],
  'blacklistusers': ['userID1', 'userID2 (opt)', '...'],
  'clearreactions': ['messageID (opt)', 'emoji (opt)'],
  'roleinfo': ['roleID'],
  'roleid': ['roleName'],
  'rolename': ['roleID'],
  'roleperms': ['roleID'],
  'roleposition': ['roleID'],
  'roleexists': ['roleID'],
  'channelexists': ['channelID'],
  'channelidfromname': ['name'],
  'emojicount': ['guildID (opt)'],
  'emojiexists': ['nameOrID'],
  'emojiname': ['emojiID'],
  'emotecount': ['guildID (opt)'],
  'getinviteinfo': ['inviteCode', 'field'],
  'getserverinvite': ['guildID (opt)'],
  'guildexists': ['guildID'],
  'hostingexpiretime': ['format (opt)'],
  'isbooster': ['userID (opt)'],
  'isbot': ['userID (opt)'],
  'isemojianimated': ['nameOrID'],
  'ishoisted': ['roleID'],
  'ismentionable': ['roleID'],
  'isnsfw': ['channelID (opt)'],
  'ismessageedited': ['channelID', 'messageID'],
  'istimedout': ['userID (opt)'],
  'memberid': ['index (opt)'],
  'membernick': ['userID (opt)'],
  'stickercount': ['guildID (opt)'],
  'userexists': ['userID'],
  'userinfo': ['userID (opt)', 'field'],
  'serverinfo': ['guildID (opt)', 'field'],
  'creationdate': ['snowflakeID', 'format (opt)'],
  'date': ['format (opt)', 'timezone (opt)'],
  'usersinchannel': ['channelID (opt)', 'separator (opt)'],
  'voiceuserlimit': ['channelID'],
  'userjoined': ['userID (opt)', 'format (opt)'],
  'userjoineddiscord': ['userID (opt)', 'format (opt)'],
  'suppresserrorlogging': [],
};
