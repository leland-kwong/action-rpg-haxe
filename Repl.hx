/*
   A simple repl designed to be run on the server for quick experiments
 */

class Repl {
  static function main() {
    TestUtils.assert('quest prototype', (passed) -> {
      final actions = [
        Quest.createAction(
            'NPC_INTERACT', 'intro_level', { type: 'merchant' }),
        Quest.createAction(
            'ENEMY_KILL', 'intro_level', { enemyType: 'bat' }),
        Quest.createAction(
            'ENEMY_KILL', 'intro_level', { enemyType: 'bat' }),
      ];
      final initialQuestState = new Map();
      final newQuestState = Lambda.fold(
          actions,
          (a, qs) -> {
            return Quest.updateQuestState(
                a,
                qs,
                Quest.conditionsByName);
          }, initialQuestState);

      final stringifiedResult = 
        haxe.Json.stringify(newQuestState, null, '  ');
      trace('\n${stringifiedResult}');

      passed(
          newQuestState.get('aggressiveBats').completed &&
          newQuestState.get('talkToMerchant').completed);
    });

    trace(
        Quest.format([
          'quest_1' => {
            completed: true
          },
          'quest_2' => {
            completed: false
          }
        ]));
  }
}
