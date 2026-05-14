import 'dart:convert';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';

void main() {
  final compiler = BdfdCompiler();
  final source = r'''$nomention
$cooldown[2m;⏳ The sea is rough! Wait %time% before your next hunt.]

$var[today;$date]

$if[$getUserVar[hunt_day]!=$var[today]]
  $setUserVar[hunt_day;$var[today]]
  $setUserVar[hunt_count;0]
$endif

$if[$getUserVar[hunt_count]>=25]
🚫 **Daily Limit Reached!**
You have used all **25 hunts** for today.
$footer[Hunts: 25/25 | Come back tomorrow]
$else

$setUserVar[hunt_count;$sum[$getUserVar[hunt_count];1]]
$var[roll;$random[1;101]]

$if[$var[roll]<=4]
  $if[$getServerVar[aa_count]>=200]
    $title[MYTHICAL RECRUIT]
    $description[The AA slots are full! You recruited **Kaido** instead.]
    $color[#FF00FF]
  $else
    $setServerVar[aa_count;$sum[$getServerVar[aa_count];1]]
    $var[aa_name;$randomText[Gol D. Roger;Whitebeard;Roronoa Zoro]]
    $title[🏆 AA TIER UNLOCKED!]
    $description[You recruited **$var[aa_name]**!\nSlot **#$getServerVar[aa_count]** of 200.]
    $color[#FFD700]
  $endif

$elseif[$var[roll]<=14]
  $var[mythic_name;$randomText[Shanks;Blackbeard;Akainu;Big Mom;Kaido]]
  $title[🔥 MYTHICAL RECRUIT]
  $description[A massive power joins your ranks: **$var[mythic_name]**!]
  $color[#FF00FF]

$elseif[$var[roll]<=30]
  $var[sh_crew;$randomText[Luffy;Nami;Usopp;Sanji;Chopper;Robin;Franky;Brook;Jinbe]]
  $title[🏴☠️ LEGENDARY: STRAW HAT MEMBER]
  $description[A member of the Straw Hat Crew has joined you: **$var[sh_crew]**!]
  $color[#FFA500]

$elseif[$var[roll]<=50]
  $var[rare_name;$randomText[Law;Kid;Boa Hancock;Sabo]]
  $title[RARE RECRUIT]
  $description[You found a powerful ally: **$var[rare_name]**!]
  $color[#0000FF]

$elseif[$var[roll]<=70]
  $title[COMMON RECRUIT]
  $description[You recruited a basic deckhand to the ship.]
  $color[#808080]

$else
  $title[UNCOMMON RECRUIT]
  $description[An uncommon pirate has decided to join your journey.]
  $color[#00FF00]
$endif

$footer[Hunts used today: $getUserVar[hunt_count]/25]
$endif''';

  print('Compiling script...');
  final result = compiler.compile(source);

  if (result.hasErrors) {
    print('Compilation FAILED with errors:');
    for (final diag in result.diagnostics) {
      print(
        '[${diag.severity.name.toUpperCase()}] ${diag.stage.name}: ${diag.message} at line ${diag.line}, col ${diag.column}',
      );
    }
  } else {
    print('Compilation SUCCESSFUL!');
    print('Actions generated: ${result.actions.length}');
    for (var i = 0; i < result.actions.length; i++) {
      final action = result.actions[i];
      print('\nAction #$i: ${action.type.name}');
      final payloadJson = jsonEncode(action.payload);
      if (i == 3) {
        final encoder = JsonEncoder.withIndent('  ');
        print('Payload:\n${encoder.convert(action.payload)}');
      } else {
        print(
          'Payload: ${payloadJson.length > 500 ? '${payloadJson.substring(0, 500)}...' : payloadJson}',
        );
      }
    }

    if (result.diagnostics.isNotEmpty) {
      print('\nWarnings:');
      for (final diag in result.diagnostics) {
        print('[${diag.severity.name.toUpperCase()}] ${diag.message}');
      }
    }
  }
}
